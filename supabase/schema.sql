-- ============================================================
-- NEXO ACADÉMICO — Supabase Schema
-- Run this in: Supabase Dashboard > SQL Editor
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- FUNCIONES HELPER — todas SECURITY DEFINER
-- Bypasean RLS al consultar su propia tabla, cortando cualquier
-- ciclo de recursión entre policies de distintas tablas.
-- ============================================================

-- Comprueba si el usuario actual es admin (consulta usuarios sin RLS)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = auth.uid() AND rol = 'admin'
  );
$$;

-- Devuelve el UUID de la fila en profesores del usuario actual (sin RLS)
CREATE OR REPLACE FUNCTION public.get_profesor_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT id FROM public.profesores WHERE usuario_id = auth.uid() LIMIT 1;
$$;

-- Devuelve el UUID de la fila en alumnos del usuario actual (sin RLS)
CREATE OR REPLACE FUNCTION public.get_alumno_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT id FROM public.alumnos WHERE usuario_id = auth.uid() LIMIT 1;
$$;

-- Devuelve el nivel del alumno actual (sin RLS)
CREATE OR REPLACE FUNCTION public.get_alumno_nivel()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT nivel FROM public.alumnos WHERE usuario_id = auth.uid() LIMIT 1;
$$;

-- ============================================================
-- USUARIOS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.usuarios (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL,
  rol        TEXT NOT NULL CHECK (rol IN ('alumno', 'profesor', 'admin')),
  nombre     TEXT NOT NULL,
  apellidos  TEXT NOT NULL DEFAULT '',
  activo     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "usuarios_self_read" ON public.usuarios
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "usuarios_admin_all" ON public.usuarios
  FOR ALL USING (
    public.is_admin()
  );

-- Permite a un alumno leer la fila de usuarios de su profesor
-- (vía profesor_id directo, junction alumno_profesor, o sesiones registradas)
DROP POLICY IF EXISTS "usuarios_prof_for_alumno" ON public.usuarios;
CREATE POLICY "usuarios_prof_for_alumno" ON public.usuarios
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profesores p
      WHERE p.usuario_id = public.usuarios.id
        AND EXISTS (
          SELECT 1 FROM public.alumnos a
          WHERE a.usuario_id = auth.uid()
            AND (
              a.profesor_id = p.id
              OR EXISTS (SELECT 1 FROM public.alumno_profesor ap WHERE ap.alumno_id = a.id AND ap.profesor_id = p.id)
              OR EXISTS (SELECT 1 FROM public.sesiones s WHERE s.alumno_id = a.id AND s.profesor_id = p.id)
            )
        )
    )
  );

-- Permite a un profesor leer las filas de usuarios de sus alumnos
-- (necesario para que el panel del profesor muestre nombre/apellidos de cada alumno
-- vía nested join alumnos → usuarios; cubre tanto FK profesor_id como alumno_profesor)
CREATE POLICY "usuarios_alumnos_for_prof" ON public.usuarios
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.alumnos al
      WHERE al.usuario_id = public.usuarios.id
        AND (
          al.profesor_id = public.get_profesor_id()
          OR EXISTS (
            SELECT 1 FROM public.alumno_profesor ap
            WHERE ap.alumno_id = al.id
              AND ap.profesor_id = public.get_profesor_id()
          )
        )
    )
  );

-- ============================================================
-- ALUMNOS (sin profesor_id todavía — se añade más abajo)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.alumnos (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id           UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  nivel                TEXT CHECK (nivel IN ('1ESO','2ESO','3ESO','4ESO','1BACH','2BACH')),
  asignaturas          TEXT[] DEFAULT '{}',
  horario_habitual     TEXT,
  modalidad            TEXT CHECK (modalidad IN ('presencial','online')) DEFAULT 'presencial',
  direccion            TEXT,
  telefono_familia     TEXT,
  horas_bono_total     NUMERIC(6,2) DEFAULT 0,
  horas_bono_restantes NUMERIC(6,2) DEFAULT 0,
  fecha_inicio         DATE,
  activo               BOOLEAN DEFAULT TRUE,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.alumnos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "alumnos_self_read" ON public.alumnos
  FOR SELECT USING (usuario_id = auth.uid());

CREATE POLICY "alumnos_admin_all" ON public.alumnos
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- PROFESORES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profesores (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id     UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  especialidades TEXT[] DEFAULT '{}',
  zona           TEXT,
  telefono       TEXT,
  estudios       TEXT,
  nivel_max      TEXT CHECK (nivel_max IN ('1ESO','2ESO','3ESO','4ESO','1BACH','2BACH')),
  fecha_inicio   DATE,
  activo         BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profesores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profesores_self_read" ON public.profesores
  FOR SELECT USING (usuario_id = auth.uid());

CREATE POLICY "profesores_admin_all" ON public.profesores
  FOR ALL USING (
    public.is_admin()
  );

-- Añadir FK de alumnos → profesores (ahora que profesores ya existe)
ALTER TABLE public.alumnos
  ADD COLUMN IF NOT EXISTS profesor_id UUID REFERENCES public.profesores(id);

-- Estas dos policies referencian profesor_id, por eso van DESPUÉS del ALTER TABLE.
-- IMPORTANTE: NO se usan subqueries cruzadas entre alumnos ↔ profesores porque
-- crearían recursión infinita. Se usan funciones SECURITY DEFINER en su lugar.

-- Permite a un profesor ver los alumnos que tiene asignados (vía profesor_id)
CREATE POLICY "alumnos_profesor_read" ON public.alumnos
  FOR SELECT USING (
    profesor_id = public.get_profesor_id()
  );

-- Permite a un alumno ver la ficha de su profesor
-- (vía profesor_id directo, junction alumno_profesor, o sesiones registradas)
DROP POLICY IF EXISTS "profesores_alumno_read" ON public.profesores;
CREATE POLICY "profesores_alumno_read" ON public.profesores
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.usuario_id = auth.uid()
        AND (
          a.profesor_id = public.profesores.id
          OR EXISTS (SELECT 1 FROM public.alumno_profesor ap WHERE ap.alumno_id = a.id AND ap.profesor_id = public.profesores.id)
          OR EXISTS (SELECT 1 FROM public.sesiones s WHERE s.alumno_id = a.id AND s.profesor_id = public.profesores.id)
        )
    )
  );

-- ============================================================
-- SESIONES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.sesiones (
  id                        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profesor_id               UUID NOT NULL REFERENCES public.profesores(id),
  alumno_id                 UUID NOT NULL REFERENCES public.alumnos(id),
  asignatura                TEXT NOT NULL,
  fecha                     DATE NOT NULL,
  hora_inicio               TIME,
  duracion_minutos          INTEGER NOT NULL DEFAULT 60,
  -- Narrativa
  contenido_trabajado       TEXT,
  estado_alumno_inicio      TEXT CHECK (estado_alumno_inicio IS NULL OR estado_alumno_inicio IN (
                              'Activo y receptivo','Normal, sin más','Cansado o apagado',
                              'Nervioso o bloqueado','Disperso, con la cabeza en otro lado')),
  momento_bloqueo           TEXT,
  resolvio_solo             TEXT,
  necesito_ayuda            TEXT,
  falta_base                TEXT,
  -- Progreso
  comparacion_anterior      TEXT,
  nota_estimada             NUMERIC(3,1)
                              CHECK (nota_estimada IS NULL OR (nota_estimada >= 0 AND nota_estimada <= 10)),
  arranque_proxima          TEXT,
  tarea_casa                TEXT,
  -- Valoraciones 1–10
  valoracion_comprension    SMALLINT CHECK (valoracion_comprension BETWEEN 1 AND 10),
  valoracion_aplicacion     SMALLINT CHECK (valoracion_aplicacion BETWEEN 1 AND 10),
  valoracion_concentracion  SMALLINT CHECK (valoracion_concentracion BETWEEN 1 AND 10),
  valoracion_motivacion     SMALLINT CHECK (valoracion_motivacion BETWEEN 1 AND 10),  -- campo 20: actitud/motivación
  valoracion_autonomia      SMALLINT CHECK (valoracion_autonomia BETWEEN 1 AND 10),
  -- Notas internas
  observaciones             TEXT,
  observaciones_nexo        TEXT,
  -- Estado
  estado                    TEXT NOT NULL DEFAULT 'pendiente_confirmacion'
                              CHECK (estado IN ('pendiente_confirmacion','confirmada','rechazada','cancelada')),
  excede_bono               BOOLEAN DEFAULT FALSE,
  registrada_at             TIMESTAMPTZ DEFAULT NOW(),
  confirmada_at             TIMESTAMPTZ,
  cancelada_por             TEXT CHECK (cancelada_por IN ('admin','sistema')),
  confirmation_token        UUID DEFAULT uuid_generate_v4()
);

ALTER TABLE public.sesiones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sesiones_profesor_own" ON public.sesiones
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profesores p
      WHERE p.usuario_id = auth.uid() AND p.id = public.sesiones.profesor_id
    )
  );

CREATE POLICY "sesiones_alumno_read" ON public.sesiones
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.usuario_id = auth.uid() AND a.id = public.sesiones.alumno_id
    )
  );

CREATE POLICY "sesiones_alumno_confirm" ON public.sesiones
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.usuario_id = auth.uid() AND a.id = public.sesiones.alumno_id
    )
  ) WITH CHECK (estado IN ('confirmada', 'rechazada'));

CREATE POLICY "sesiones_admin_all" ON public.sesiones
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- INFORMES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.informes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alumno_id   UUID NOT NULL REFERENCES public.alumnos(id),
  tipo        TEXT NOT NULL CHECK (tipo IN ('mensual','semanal')),
  titulo      TEXT NOT NULL,
  fecha       DATE NOT NULL DEFAULT CURRENT_DATE,
  archivo_url TEXT,
  subido_por  UUID REFERENCES public.usuarios(id),
  visible     BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.informes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "informes_alumno_read" ON public.informes
  FOR SELECT USING (
    visible = TRUE AND EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.usuario_id = auth.uid() AND a.id = public.informes.alumno_id
    )
  );

CREATE POLICY "informes_admin_all" ON public.informes
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- MATERIAL
-- ============================================================
CREATE TABLE IF NOT EXISTS public.material (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titulo      TEXT NOT NULL,
  descripcion TEXT,
  nivel       TEXT CHECK (nivel IN ('1ESO','2ESO','3ESO','4ESO','1BACH','2BACH','todos')),
  asignatura  TEXT,
  bloque_tema TEXT,
  archivo_url TEXT,
  tipo        TEXT CHECK (tipo IN ('pdf','recurso')) DEFAULT 'pdf',
  subido_por  UUID REFERENCES public.usuarios(id),
  visible     BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.material ENABLE ROW LEVEL SECURITY;

-- Solo política de admin por ahora; la de alumnos se añade después de crear material_alumno
CREATE POLICY "material_admin_all" ON public.material
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- MATERIAL_ALUMNO
-- ============================================================
CREATE TABLE IF NOT EXISTS public.material_alumno (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  material_id  UUID NOT NULL REFERENCES public.material(id) ON DELETE CASCADE,
  alumno_id    UUID NOT NULL REFERENCES public.alumnos(id) ON DELETE CASCADE,
  asignado_at  TIMESTAMPTZ DEFAULT NOW(),
  asignado_por UUID REFERENCES public.usuarios(id),
  UNIQUE(material_id, alumno_id)
);

ALTER TABLE public.material_alumno ENABLE ROW LEVEL SECURITY;

-- get_alumno_id() bypasea RLS en alumnos → sin recursión
CREATE POLICY "material_alumno_read_own" ON public.material_alumno
  FOR SELECT USING (alumno_id = public.get_alumno_id());

CREATE POLICY "material_alumno_admin_all" ON public.material_alumno
  FOR ALL USING (
    public.is_admin()
  );

-- Policy de lectura para alumnos: usa helpers SECURITY DEFINER para evitar
-- recursión a través de material_alumno → alumnos → (ciclo anterior)
CREATE POLICY "material_alumno_read" ON public.material
  FOR SELECT USING (
    visible = TRUE AND (
      -- Material asignado explícitamente a este alumno
      EXISTS (
        SELECT 1 FROM public.material_alumno ma
        WHERE ma.material_id = public.material.id
          AND ma.alumno_id = public.get_alumno_id()
      )
      OR (
        -- Material general del nivel del alumno
        public.get_alumno_id() IS NOT NULL
        AND (nivel = 'todos' OR nivel = public.get_alumno_nivel())
      )
    )
  );

-- ============================================================
-- TESTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.tests (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  titulo      TEXT NOT NULL,
  asignatura  TEXT,
  nivel       TEXT,
  bloque_tema TEXT,
  creado_por  UUID REFERENCES public.usuarios(id),
  visible     BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tests_alumno_read" ON public.tests
  FOR SELECT USING (visible = TRUE);

CREATE POLICY "tests_admin_all" ON public.tests
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- PREGUNTAS_TEST
-- ============================================================
CREATE TABLE IF NOT EXISTS public.preguntas_test (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  test_id            UUID NOT NULL REFERENCES public.tests(id) ON DELETE CASCADE,
  enunciado          TEXT NOT NULL,
  opcion_a           TEXT NOT NULL,
  opcion_b           TEXT NOT NULL,
  opcion_c           TEXT NOT NULL,
  opcion_d           TEXT NOT NULL,
  respuesta_correcta TEXT NOT NULL CHECK (respuesta_correcta IN ('a','b','c','d')),
  orden              INTEGER DEFAULT 0
);

ALTER TABLE public.preguntas_test ENABLE ROW LEVEL SECURITY;

CREATE POLICY "preguntas_alumno_read" ON public.preguntas_test
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.tests t WHERE t.id = test_id AND t.visible = TRUE)
  );

CREATE POLICY "preguntas_admin_all" ON public.preguntas_test
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- RESULTADOS_TEST
-- ============================================================
CREATE TABLE IF NOT EXISTS public.resultados_test (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  test_id       UUID NOT NULL REFERENCES public.tests(id),
  alumno_id     UUID NOT NULL REFERENCES public.alumnos(id),
  respuestas    JSONB,
  nota          NUMERIC(4,2),
  completado_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(test_id, alumno_id)
);

ALTER TABLE public.resultados_test ENABLE ROW LEVEL SECURITY;

CREATE POLICY "resultados_alumno_own" ON public.resultados_test
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.usuario_id = auth.uid() AND a.id = public.resultados_test.alumno_id
    )
  );

CREATE POLICY "resultados_admin_all" ON public.resultados_test
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- CALENDARIO_ALUMNO
-- ============================================================
CREATE TABLE IF NOT EXISTS public.calendario_alumno (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alumno_id        UUID NOT NULL REFERENCES public.alumnos(id),
  titulo           TEXT NOT NULL,
  asignatura       TEXT,
  fecha            DATE NOT NULL,
  hora_inicio      TIME,
  duracion_minutos INTEGER DEFAULT 60,
  profesor_nombre  TEXT,
  notas            TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.calendario_alumno ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cal_alumno_own" ON public.calendario_alumno
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.usuario_id = auth.uid() AND a.id = public.calendario_alumno.alumno_id
    )
  );

CREATE POLICY "cal_alumno_admin" ON public.calendario_alumno
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- CALENDARIO_PROFESOR
-- ============================================================
CREATE TABLE IF NOT EXISTS public.calendario_profesor (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profesor_id      UUID NOT NULL REFERENCES public.profesores(id),
  alumno_id        UUID REFERENCES public.alumnos(id),
  asignatura       TEXT,
  fecha            DATE NOT NULL,
  hora_inicio      TIME,
  duracion_minutos INTEGER DEFAULT 60,
  notas            TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.calendario_profesor ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cal_profesor_own" ON public.calendario_profesor
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profesores p
      WHERE p.usuario_id = auth.uid() AND p.id = public.calendario_profesor.profesor_id
    )
  );

CREATE POLICY "cal_profesor_admin" ON public.calendario_profesor
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- AVISOS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.avisos (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  destinatario_rol TEXT CHECK (destinatario_rol IN ('alumno','profesor','todos')),
  destinatario_id  UUID REFERENCES public.usuarios(id),
  titulo           TEXT NOT NULL,
  contenido        TEXT NOT NULL,
  creado_por       UUID REFERENCES public.usuarios(id),
  visible          BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.avisos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "avisos_read" ON public.avisos
  FOR SELECT USING (
    visible = TRUE AND (
      destinatario_id = auth.uid()
      OR destinatario_rol = 'todos'
      OR EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.id = auth.uid()
          AND (
            (destinatario_rol = 'alumno'   AND u.rol = 'alumno')
            OR (destinatario_rol = 'profesor' AND u.rol = 'profesor')
          )
      )
    )
  );

CREATE POLICY "avisos_admin_all" ON public.avisos
  FOR ALL USING (
    public.is_admin()
  );

-- ============================================================
-- Helper interno: activa el siguiente bono en_espera cuando
-- el bono activo se agota (horas_bono_restantes llega a 0).
-- Solo llamado por los RPCs de confirmación de sesión.
-- ============================================================
CREATE OR REPLACE FUNCTION public._activar_siguiente_bono(p_alumno_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_next public.bonos%ROWTYPE;
BEGIN
  UPDATE public.bonos
  SET estado = 'agotado'
  WHERE alumno_id = p_alumno_id AND estado = 'activo';

  SELECT * INTO v_next
  FROM public.bonos
  WHERE alumno_id = p_alumno_id AND estado = 'pagado_en_espera'
  ORDER BY fecha_pago ASC NULLS LAST, created_at ASC
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.bonos SET estado = 'activo' WHERE id = v_next.id;
    UPDATE public.alumnos
    SET horas_bono_total     = v_next.horas_contratadas,
        horas_bono_restantes = v_next.horas_contratadas
    WHERE id = p_alumno_id;
  ELSE
    UPDATE public.alumnos
    SET horas_bono_total = 0, horas_bono_restantes = 0
    WHERE id = p_alumno_id;
  END IF;
END;
$$;

-- ============================================================
-- RPC: Confirmar sesión desde enlace de email (sin auth)
-- ============================================================
CREATE OR REPLACE FUNCTION public.process_session_confirmation(
  p_session_id UUID,
  p_token      UUID,
  p_action     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session       public.sesiones%ROWTYPE;
  v_new_restantes NUMERIC;
BEGIN
  SELECT * INTO v_session
  FROM public.sesiones
  WHERE id = p_session_id AND confirmation_token = p_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Token inválido o sesión no encontrada');
  END IF;

  IF v_session.estado != 'pendiente_confirmacion' THEN
    RETURN jsonb_build_object('success', false, 'error', 'La sesión ya fue procesada anteriormente');
  END IF;

  IF p_action = 'confirmar' THEN
    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = p_session_id;

    UPDATE public.alumnos
    SET horas_bono_restantes = GREATEST(0, horas_bono_restantes - (v_session.duracion_minutos / 60.0))
    WHERE id = v_session.alumno_id
    RETURNING horas_bono_restantes INTO v_new_restantes;

    IF v_new_restantes = 0 THEN
      PERFORM public._activar_siguiente_bono(v_session.alumno_id);
    END IF;

    RETURN jsonb_build_object('success', true, 'action', 'confirmada');

  ELSIF p_action = 'rechazar' THEN
    UPDATE public.sesiones
    SET estado = 'rechazada'
    WHERE id = p_session_id;

    RETURN jsonb_build_object('success', true, 'action', 'rechazada');

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Acción no válida');
  END IF;
END;
$$;

-- ============================================================
-- RPC: Confirmar sesión desde panel del alumno (requiere auth)
-- ============================================================
CREATE OR REPLACE FUNCTION public.confirmar_sesion_alumno(
  p_session_id UUID,
  p_action     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session       public.sesiones%ROWTYPE;
  v_alumno        public.alumnos%ROWTYPE;
  v_new_restantes NUMERIC;
BEGIN
  SELECT * INTO v_session FROM public.sesiones WHERE id = p_session_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sesión no encontrada');
  END IF;

  SELECT * INTO v_alumno FROM public.alumnos
  WHERE id = v_session.alumno_id AND usuario_id = auth.uid();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos');
  END IF;

  IF v_session.estado != 'pendiente_confirmacion' THEN
    RETURN jsonb_build_object('success', false, 'error', 'La sesión ya fue procesada');
  END IF;

  IF p_action = 'confirmar' THEN
    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = p_session_id;

    UPDATE public.alumnos
    SET horas_bono_restantes = GREATEST(0, horas_bono_restantes - (v_session.duracion_minutos / 60.0))
    WHERE id = v_session.alumno_id
    RETURNING horas_bono_restantes INTO v_new_restantes;

    IF v_new_restantes = 0 THEN
      PERFORM public._activar_siguiente_bono(v_session.alumno_id);
    END IF;

    RETURN jsonb_build_object('success', true, 'action', 'confirmada');

  ELSIF p_action = 'rechazar' THEN
    UPDATE public.sesiones SET estado = 'rechazada' WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'action', 'rechazada');

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Acción no válida');
  END IF;
END;
$$;

-- ============================================================
-- RPC: Cancelar sesión (solo admin, opción de revertir bono)
-- ============================================================
CREATE OR REPLACE FUNCTION public.cancelar_sesion_admin(
  p_session_id     UUID,
  p_revertir_horas BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session public.sesiones%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol = 'admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos de administrador');
  END IF;

  SELECT * INTO v_session FROM public.sesiones WHERE id = p_session_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sesión no encontrada');
  END IF;

  UPDATE public.sesiones
  SET estado = 'cancelada', cancelada_por = 'admin'
  WHERE id = p_session_id;

  IF p_revertir_horas AND v_session.estado = 'confirmada' THEN
    UPDATE public.alumnos
    SET horas_bono_restantes = horas_bono_restantes + (v_session.duracion_minutos / 60.0)
    WHERE id = v_session.alumno_id;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- RPC: Auto-confirmar sesiones pendientes > 72h (Bloque 4)
-- Callable por authenticated users como fallback cliente.
-- pg_cron la ejecuta cada hora de forma fiable.
-- ============================================================
CREATE OR REPLACE FUNCTION public.auto_confirm_old_sessions()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row           RECORD;
  v_new_restantes NUMERIC;
  v_count         INTEGER := 0;
BEGIN
  FOR v_row IN
    SELECT id, alumno_id, duracion_minutos
    FROM public.sesiones
    WHERE estado = 'pendiente_confirmacion'
      AND registrada_at < NOW() - INTERVAL '72 hours'
  LOOP
    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = v_row.id;

    UPDATE public.alumnos
    SET horas_bono_restantes = GREATEST(0, horas_bono_restantes - (v_row.duracion_minutos / 60.0))
    WHERE id = v_row.alumno_id
    RETURNING horas_bono_restantes INTO v_new_restantes;

    IF v_new_restantes = 0 THEN
      PERFORM public._activar_siguiente_bono(v_row.alumno_id);
    END IF;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- Permitir que cualquier usuario autenticado lo llame (es seguro: solo procesa sesiones > 72h)
GRANT EXECUTE ON FUNCTION public.auto_confirm_old_sessions() TO authenticated;

-- ── pg_cron (ejecutar en Supabase SQL Editor una sola vez) ──────────────
-- Requiere que la extensión pg_cron esté habilitada en Supabase Dashboard.
-- SELECT cron.schedule(
--   'auto-confirm-sessions',
--   '0 * * * *',   -- cada hora
--   'SELECT public.auto_confirm_old_sessions()'
-- );
-- Para ver el job: SELECT * FROM cron.job WHERE jobname = 'auto-confirm-sessions';
-- Para eliminarlo: SELECT cron.unschedule('auto-confirm-sessions');
-- ────────────────────────────────────────────────────────────────────────

-- ============================================================
-- ALUMNO_PROFESOR — Relación many-to-many (un alumno puede tener
-- varios profesores por asignatura, un profesor varios alumnos)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.alumno_profesor (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alumno_id      UUID    NOT NULL REFERENCES public.alumnos(id)   ON DELETE CASCADE,
  profesor_id    UUID    NOT NULL REFERENCES public.profesores(id) ON DELETE CASCADE,
  asignatura     TEXT,            -- legacy vacío; la fuente real es asignatura_id
  asignatura_id  SMALLINT REFERENCES public.asignaturas(id),  -- añadido vía SQL editor
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(alumno_id, profesor_id, asignatura_id)  -- permite un profesor por asignatura
);

ALTER TABLE public.alumno_profesor ENABLE ROW LEVEL SECURITY;

CREATE POLICY "alumno_profesor_admin_all" ON public.alumno_profesor
  FOR ALL USING (public.is_admin());

-- Helpers SECURITY DEFINER → sin subqueries cruzadas → sin recursión
CREATE POLICY "alumno_profesor_alumno_read" ON public.alumno_profesor
  FOR SELECT USING (alumno_id = public.get_alumno_id());

CREATE POLICY "alumno_profesor_profesor_read" ON public.alumno_profesor
  FOR SELECT USING (profesor_id = public.get_profesor_id());

CREATE INDEX IF NOT EXISTS idx_alumno_profesor_alumno   ON public.alumno_profesor(alumno_id);
CREATE INDEX IF NOT EXISTS idx_alumno_profesor_profesor ON public.alumno_profesor(profesor_id);

-- ============================================================
-- Índices de rendimiento
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_alumnos_usuario   ON public.alumnos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_alumnos_profesor  ON public.alumnos(profesor_id);
CREATE INDEX IF NOT EXISTS idx_profesores_usuario ON public.profesores(usuario_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_profesor ON public.sesiones(profesor_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_alumno   ON public.sesiones(alumno_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_fecha    ON public.sesiones(fecha);
CREATE INDEX IF NOT EXISTS idx_sesiones_estado   ON public.sesiones(estado);
CREATE INDEX IF NOT EXISTS idx_informes_alumno   ON public.informes(alumno_id);
CREATE INDEX IF NOT EXISTS idx_mat_alumno        ON public.material_alumno(alumno_id);
CREATE INDEX IF NOT EXISTS idx_resultados_alumno ON public.resultados_test(alumno_id);
CREATE INDEX IF NOT EXISTS idx_cal_alumno        ON public.calendario_alumno(alumno_id, fecha);
CREATE INDEX IF NOT EXISTS idx_cal_profesor      ON public.calendario_profesor(profesor_id, fecha);

-- ============================================================
-- TARIFAS_BONOS — Catálogo de precios por grupo/modalidad/horas
-- ============================================================
CREATE TABLE IF NOT EXISTS public.tarifas_bonos (
  id        SERIAL PRIMARY KEY,
  grupo     TEXT      NOT NULL CHECK (grupo IN ('Primaria','ESO','Bachillerato','Universidad')),
  modalidad TEXT      NOT NULL CHECK (modalidad IN ('Presencial','Online')),
  horas     SMALLINT  NOT NULL CHECK (horas IN (2,4,8,12)),
  precio    NUMERIC(8,2) NOT NULL,
  activo    BOOLEAN   DEFAULT TRUE,
  UNIQUE(grupo, modalidad, horas)
);

ALTER TABLE public.tarifas_bonos ENABLE ROW LEVEL SECURITY;

-- Todos los usuarios autenticados pueden leer el catálogo
CREATE POLICY "tarifas_bonos_read_all" ON public.tarifas_bonos
  FOR SELECT USING (TRUE);

CREATE POLICY "tarifas_bonos_admin_all" ON public.tarifas_bonos
  FOR ALL USING (public.is_admin());

-- Carga inicial de tarifas (Presencial > Online en precio)
INSERT INTO public.tarifas_bonos (grupo, modalidad, horas, precio) VALUES
  -- Primaria (solo Presencial)
  ('Primaria','Presencial', 2,  32),
  ('Primaria','Presencial', 4,  70),
  ('Primaria','Presencial', 8, 135),
  ('Primaria','Presencial',12, 200),
  -- ESO Online (más barato)
  ('ESO','Online', 2,  40),
  ('ESO','Online', 4,  90),
  ('ESO','Online', 8, 175),
  ('ESO','Online',12, 260),
  -- ESO Presencial (más caro)
  ('ESO','Presencial', 2,  44),
  ('ESO','Presencial', 4,  94),
  ('ESO','Presencial', 8, 185),
  ('ESO','Presencial',12, 270),
  -- Bachillerato Online
  ('Bachillerato','Online', 2,  42),
  ('Bachillerato','Online', 4,  92),
  ('Bachillerato','Online', 8, 180),
  ('Bachillerato','Online',12, 265),
  -- Bachillerato Presencial
  ('Bachillerato','Presencial', 2,  46),
  ('Bachillerato','Presencial', 4,  98),
  ('Bachillerato','Presencial', 8, 195),
  ('Bachillerato','Presencial',12, 285),
  -- Universidad Online
  ('Universidad','Online', 2,  44),
  ('Universidad','Online', 4,  96),
  ('Universidad','Online', 8, 190),
  ('Universidad','Online',12, 280),
  -- Universidad Presencial
  ('Universidad','Presencial', 2,  48),
  ('Universidad','Presencial', 4, 105),
  ('Universidad','Presencial', 8, 205),
  ('Universidad','Presencial',12, 300)
ON CONFLICT (grupo, modalidad, horas) DO UPDATE SET precio = EXCLUDED.precio;

-- ============================================================
-- BONOS — Historial de bonos contratados / solicitados por alumno
-- ============================================================
CREATE TABLE IF NOT EXISTS public.bonos (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alumno_id         UUID NOT NULL REFERENCES public.alumnos(id) ON DELETE CASCADE,
  horas_contratadas NUMERIC(6,2) NOT NULL,
  modalidad         TEXT NOT NULL CHECK (modalidad IN ('Presencial','Online')),
  precio_base       NUMERIC(8,2),
  descuento         NUMERIC(5,2) DEFAULT 0
                      CHECK (descuento >= 0 AND descuento <= 100),
  precio_final      NUMERIC(8,2),
  fecha_compra      DATE DEFAULT CURRENT_DATE,
  pagado            BOOLEAN DEFAULT FALSE,
  fecha_pago        DATE,
  estado            TEXT NOT NULL DEFAULT 'reservado'
                      CHECK (estado IN ('reservado','pagado_en_espera','activo','agotado','cancelado')),
  notas             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.bonos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bonos_admin_all" ON public.bonos
  FOR ALL USING (public.is_admin());

-- El alumno ve solo sus propios bonos
CREATE POLICY "bonos_alumno_read" ON public.bonos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.id = public.bonos.alumno_id AND a.usuario_id = auth.uid()
    )
  );

-- El alumno puede crear reservas (solo con estado='reservado')
CREATE POLICY "bonos_alumno_insert" ON public.bonos
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.id = public.bonos.alumno_id AND a.usuario_id = auth.uid()
    )
    AND estado = 'reservado'
  );

-- El profesor puede leer bonos de sus alumnos (para bloqueo/aviso en registro de sesiones)
CREATE POLICY "bonos_profesor_read" ON public.bonos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.id = public.bonos.alumno_id
        AND (
          a.profesor_id = public.get_profesor_id()
          OR EXISTS (SELECT 1 FROM public.alumno_profesor ap WHERE ap.alumno_id = a.id AND ap.profesor_id = public.get_profesor_id())
          OR EXISTS (SELECT 1 FROM public.sesiones s WHERE s.alumno_id = a.id AND s.profesor_id = public.get_profesor_id())
        )
    )
  );

CREATE INDEX IF NOT EXISTS idx_bonos_alumno ON public.bonos(alumno_id);
CREATE INDEX IF NOT EXISTS idx_bonos_estado ON public.bonos(estado);
CREATE INDEX IF NOT EXISTS idx_bonos_fecha  ON public.bonos(fecha_compra);
