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
-- (vía profesor_id directo o junction alumno_profesor)
-- NOTA: NO incluir sesiones aquí — crearía bucle con sesiones_profesor_own → profesores RLS
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
  horas_deuda          NUMERIC(6,2) NOT NULL DEFAULT 0,
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

-- Permite a un profesor ver los alumnos asignados vía junction table alumno_profesor
CREATE POLICY "alumnos_profesor_read" ON public.alumnos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.alumno_profesor ap
      WHERE ap.alumno_id = alumnos.id
        AND ap.profesor_id = public.get_profesor_id()
    )
  );

-- Permite a un alumno ver la ficha de su profesor
-- (vía profesor_id directo o junction alumno_profesor)
-- NOTA: NO incluir sesiones — crearía bucle infinito: profesores_alumno_read
-- lee sesiones, y sesiones_profesor_own lee profesores → recursión infinita → 500
DROP POLICY IF EXISTS "profesores_alumno_read" ON public.profesores;
CREATE POLICY "profesores_alumno_read" ON public.profesores
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.alumnos a
      WHERE a.usuario_id = auth.uid()
        AND (
          a.profesor_id = public.profesores.id
          OR EXISTS (SELECT 1 FROM public.alumno_profesor ap WHERE ap.alumno_id = a.id AND ap.profesor_id = public.profesores.id)
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
  confirmation_token        UUID DEFAULT uuid_generate_v4(),
  -- bono_id y horas_deducidas se añaden vía ALTER TABLE después de crear bonos
  horas_deducidas           NUMERIC(6,2)
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
CREATE OR REPLACE FUNCTION public._activar_siguiente_bono(
  p_alumno_id UUID,
  p_fecha_ts  TIMESTAMPTZ DEFAULT NOW()
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_next  public.bonos%ROWTYPE;
  v_deuda NUMERIC;
  v_net   NUMERIC;
BEGIN
  UPDATE public.bonos
  SET estado           = 'agotado',
      horas_restantes  = 0,
      horas_consumidas = horas_contratadas,
      agotado_at       = COALESCE(agotado_at, p_fecha_ts)
  WHERE alumno_id = p_alumno_id AND estado = 'activo';

  SELECT * INTO v_next
  FROM public.bonos
  WHERE alumno_id = p_alumno_id AND estado = 'pagado_en_espera'
  ORDER BY fecha_pago ASC NULLS LAST, created_at ASC
  LIMIT 1;

  IF FOUND THEN
    SELECT COALESCE(horas_deuda, 0) INTO v_deuda
    FROM public.alumnos WHERE id = p_alumno_id;

    v_net := GREATEST(0, v_next.horas_contratadas - v_deuda);

    UPDATE public.bonos
    SET estado           = CASE WHEN v_net = 0 THEN 'agotado' ELSE 'activo' END,
        horas_consumidas = LEAST(v_next.horas_contratadas, v_deuda),
        horas_restantes  = v_net,
        agotado_at       = CASE WHEN v_net = 0 THEN COALESCE(agotado_at, p_fecha_ts) ELSE agotado_at END
    WHERE id = v_next.id;

    UPDATE public.alumnos
    SET horas_bono_total     = v_next.horas_contratadas,
        horas_bono_restantes = v_net,
        horas_deuda          = GREATEST(0, v_deuda - v_next.horas_contratadas)
    WHERE id = p_alumno_id;

    IF v_net = 0 THEN
      PERFORM public._activar_siguiente_bono(p_alumno_id, p_fecha_ts);
    END IF;
  ELSE
    UPDATE public.alumnos
    SET horas_bono_total = 0, horas_bono_restantes = 0
    WHERE id = p_alumno_id;
  END IF;
END;
$$;

-- ============================================================
-- Helper: consumir horas de una sesión con cascada de bonos.
-- Descuenta bono a bono en orden. Si no hay bono activo pero
-- existe uno pagado_en_espera, lo activa (aplicando deuda) y
-- consume de él. Si se agotan todos los bonos, acumula deuda.
-- ============================================================
CREATE OR REPLACE FUNCTION public._consumir_horas_sesion(
  p_alumno_id  UUID,
  p_duracion_h NUMERIC,
  p_fecha_ts   TIMESTAMPTZ DEFAULT NOW()
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_activo    public.bonos%ROWTYPE;
  v_deuda     NUMERIC;
  v_net       NUMERIC;
  v_remaining NUMERIC;
BEGIN
  v_remaining := p_duracion_h;

  LOOP
    -- Buscar bono activo
    SELECT * INTO v_activo
    FROM public.bonos
    WHERE alumno_id = p_alumno_id AND estado = 'activo'
    LIMIT 1;

    -- Si no hay activo, intentar activar el siguiente en espera
    IF NOT FOUND THEN
      SELECT * INTO v_activo
      FROM public.bonos
      WHERE alumno_id = p_alumno_id AND estado = 'pagado_en_espera'
      ORDER BY fecha_pago ASC NULLS LAST, created_at ASC
      LIMIT 1;

      IF NOT FOUND THEN
        -- Sin bonos: acumular toda la deuda pendiente y salir
        UPDATE public.alumnos
        SET horas_deuda          = COALESCE(horas_deuda, 0) + v_remaining,
            horas_bono_total     = 0,
            horas_bono_restantes = 0
        WHERE id = p_alumno_id;
        RETURN;
      END IF;

      -- Activar el bono en espera aplicando la deuda acumulada
      SELECT COALESCE(horas_deuda, 0) INTO v_deuda
      FROM public.alumnos WHERE id = p_alumno_id;
      v_net := GREATEST(0, v_activo.horas_contratadas - v_deuda);

      UPDATE public.bonos
      SET estado           = CASE WHEN v_net = 0 THEN 'agotado' ELSE 'activo' END,
          horas_consumidas = LEAST(v_activo.horas_contratadas, v_deuda),
          horas_restantes  = v_net,
          agotado_at       = CASE WHEN v_net = 0 THEN COALESCE(agotado_at, p_fecha_ts) ELSE NULL END
      WHERE id = v_activo.id;

      UPDATE public.alumnos
      SET horas_deuda          = GREATEST(0, v_deuda - v_activo.horas_contratadas),
          horas_bono_total     = v_activo.horas_contratadas,
          horas_bono_restantes = v_net
      WHERE id = p_alumno_id;

      IF v_net = 0 THEN
        CONTINUE; -- Bono inmediatamente agotado: buscar el siguiente
      END IF;

      -- Refrescar v_activo con el estado real tras la activación
      SELECT * INTO v_activo FROM public.bonos WHERE id = v_activo.id;
    END IF;

    -- Consumir horas del bono activo
    IF v_remaining <= v_activo.horas_restantes THEN
      UPDATE public.bonos
      SET horas_consumidas = horas_consumidas + v_remaining,
          horas_restantes  = horas_restantes  - v_remaining
      WHERE id = v_activo.id;

      UPDATE public.alumnos
      SET horas_bono_restantes = GREATEST(0, horas_bono_restantes - v_remaining)
      WHERE id = p_alumno_id;

      -- Si el bono quedó exactamente a 0, activar el siguiente (con deuda=0 aquí)
      IF v_activo.horas_restantes - v_remaining = 0 THEN
        PERFORM public._activar_siguiente_bono(p_alumno_id, p_fecha_ts);
      END IF;
      RETURN;

    ELSE
      -- La sesión supera el bono actual: agotar y continuar en cascada
      UPDATE public.bonos
      SET estado           = 'agotado',
          horas_consumidas = horas_contratadas,
          horas_restantes  = 0,
          agotado_at       = COALESCE(agotado_at, p_fecha_ts)
      WHERE id = v_activo.id;

      v_remaining := v_remaining - v_activo.horas_restantes;
      -- El bucle continúa buscando el siguiente bono
    END IF;
  END LOOP;
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
  v_session    public.sesiones%ROWTYPE;
  v_bono_pre   public.bonos%ROWTYPE;
  v_duracion_h NUMERIC;
  v_deuda      NUMERIC;
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
    v_duracion_h := v_session.duracion_minutos / 60.0;

    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = p_session_id;

    -- Identificar el bono que recibirá el descuento (activo primero, luego pagado_en_espera)
    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
    IF NOT FOUND THEN
      SELECT * INTO v_bono_pre FROM public.bonos
      WHERE alumno_id = v_session.alumno_id AND estado = 'pagado_en_espera'
      ORDER BY fecha_pago ASC NULLS LAST, created_at ASC LIMIT 1;
    END IF;

    IF FOUND THEN
      IF v_bono_pre.estado = 'activo' THEN
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, v_bono_pre.horas_restantes)
        WHERE id = p_session_id;
      ELSE
        SELECT COALESCE(horas_deuda, 0) INTO v_deuda FROM public.alumnos WHERE id = v_session.alumno_id;
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, GREATEST(0, v_bono_pre.horas_contratadas - v_deuda))
        WHERE id = p_session_id;
      END IF;
    END IF;

    PERFORM public._consumir_horas_sesion(v_session.alumno_id, v_duracion_h, NOW());

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
  v_session    public.sesiones%ROWTYPE;
  v_alumno     public.alumnos%ROWTYPE;
  v_bono_pre   public.bonos%ROWTYPE;
  v_duracion_h NUMERIC;
  v_deuda      NUMERIC;
BEGIN
  SELECT * INTO v_session FROM public.sesiones WHERE id = p_session_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Sesión no encontrada'); END IF;

  SELECT * INTO v_alumno FROM public.alumnos
  WHERE id = v_session.alumno_id AND usuario_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Sin permisos'); END IF;

  IF v_session.estado != 'pendiente_confirmacion' THEN
    RETURN jsonb_build_object('success', false, 'error', 'La sesión ya fue procesada');
  END IF;

  IF p_action = 'confirmar' THEN
    v_duracion_h := v_session.duracion_minutos / 60.0;

    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = p_session_id;

    -- Identificar el bono que recibirá el descuento (activo primero, luego pagado_en_espera)
    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
    IF NOT FOUND THEN
      SELECT * INTO v_bono_pre FROM public.bonos
      WHERE alumno_id = v_session.alumno_id AND estado = 'pagado_en_espera'
      ORDER BY fecha_pago ASC NULLS LAST, created_at ASC LIMIT 1;
    END IF;

    IF FOUND THEN
      IF v_bono_pre.estado = 'activo' THEN
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, v_bono_pre.horas_restantes)
        WHERE id = p_session_id;
      ELSE
        SELECT COALESCE(horas_deuda, 0) INTO v_deuda FROM public.alumnos WHERE id = v_session.alumno_id;
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, GREATEST(0, v_bono_pre.horas_contratadas - v_deuda))
        WHERE id = p_session_id;
      END IF;
    END IF;

    PERFORM public._consumir_horas_sesion(v_session.alumno_id, v_duracion_h, NOW());

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
-- Helper: revertir horas al cancelar una sesión confirmada
-- ============================================================
CREATE OR REPLACE FUNCTION public._revertir_horas_sesion(p_session_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session     public.sesiones%ROWTYPE;
  v_bono_orig   public.bonos%ROWTYPE;
  v_bono_activo public.bonos%ROWTYPE;
  v_duracion_h  NUMERIC;
  v_deducidas   NUMERIC;
  v_overflow    NUMERIC;
BEGIN
  SELECT * INTO v_session FROM public.sesiones WHERE id = p_session_id;
  IF NOT FOUND THEN RETURN; END IF;

  v_duracion_h := v_session.duracion_minutos / 60.0;

  IF v_session.bono_id IS NOT NULL THEN
    v_deducidas := COALESCE(v_session.horas_deducidas, v_duracion_h);
    v_overflow  := v_duracion_h - v_deducidas;
    SELECT * INTO v_bono_orig FROM public.bonos WHERE id = v_session.bono_id;

    IF FOUND AND v_bono_orig.estado = 'activo' THEN
      UPDATE public.bonos
      SET horas_consumidas = GREATEST(0, horas_consumidas - v_deducidas),
          horas_restantes  = horas_restantes + v_deducidas
      WHERE id = v_session.bono_id;
      UPDATE public.alumnos SET horas_bono_restantes = horas_bono_restantes + v_deducidas WHERE id = v_session.alumno_id;
      IF v_overflow > 0 THEN
        UPDATE public.alumnos SET horas_deuda = GREATEST(0, COALESCE(horas_deuda,0) - v_overflow) WHERE id = v_session.alumno_id;
      END IF;

    ELSIF FOUND AND v_bono_orig.estado = 'agotado' THEN
      SELECT * INTO v_bono_activo FROM public.bonos WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
      IF FOUND AND v_overflow > 0 AND v_bono_activo.horas_consumidas <= v_overflow THEN
        UPDATE public.bonos SET estado='activo', horas_consumidas=GREATEST(0,v_bono_orig.horas_consumidas-v_deducidas), horas_restantes=v_deducidas, agotado_at=NULL WHERE id = v_session.bono_id;
        UPDATE public.bonos SET estado='pagado_en_espera', horas_consumidas=0, horas_restantes=0, agotado_at=NULL WHERE id = v_bono_activo.id;
        UPDATE public.alumnos SET horas_bono_total=v_bono_orig.horas_contratadas, horas_bono_restantes=v_deducidas WHERE id = v_session.alumno_id;
      ELSIF FOUND THEN
        UPDATE public.bonos SET horas_consumidas=GREATEST(0,horas_consumidas-v_duracion_h), horas_restantes=horas_restantes+v_duracion_h WHERE id = v_bono_activo.id;
        UPDATE public.alumnos SET horas_bono_restantes=horas_bono_restantes+v_duracion_h WHERE id = v_session.alumno_id;
      ELSE
        UPDATE public.bonos SET estado='activo', horas_consumidas=GREATEST(0,v_bono_orig.horas_consumidas-v_deducidas), horas_restantes=v_deducidas, agotado_at=NULL WHERE id = v_session.bono_id;
        UPDATE public.alumnos SET horas_bono_total=v_bono_orig.horas_contratadas, horas_bono_restantes=v_deducidas, horas_deuda=GREATEST(0,COALESCE(horas_deuda,0)-v_overflow) WHERE id = v_session.alumno_id;
      END IF;
    ELSE
      SELECT * INTO v_bono_activo FROM public.bonos WHERE alumno_id=v_session.alumno_id AND estado='activo' LIMIT 1;
      IF FOUND THEN UPDATE public.bonos SET horas_consumidas=GREATEST(0,horas_consumidas-v_duracion_h), horas_restantes=horas_restantes+v_duracion_h WHERE id=v_bono_activo.id; END IF;
      UPDATE public.alumnos SET horas_bono_restantes=COALESCE(horas_bono_restantes,0)+v_duracion_h WHERE id=v_session.alumno_id;
    END IF;
  ELSE
    SELECT * INTO v_bono_activo FROM public.bonos WHERE alumno_id=v_session.alumno_id AND estado='activo' LIMIT 1;
    IF FOUND THEN UPDATE public.bonos SET horas_consumidas=GREATEST(0,horas_consumidas-v_duracion_h), horas_restantes=horas_restantes+v_duracion_h WHERE id=v_bono_activo.id; END IF;
    UPDATE public.alumnos SET horas_bono_restantes=COALESCE(horas_bono_restantes,0)+v_duracion_h WHERE id=v_session.alumno_id;
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
    PERFORM public._revertir_horas_sesion(p_session_id);
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
  v_row        RECORD;
  v_bono_pre   public.bonos%ROWTYPE;
  v_duracion_h NUMERIC;
  v_deuda      NUMERIC;
  v_count      INTEGER := 0;
BEGIN
  FOR v_row IN
    SELECT id, alumno_id, duracion_minutos
    FROM public.sesiones
    WHERE estado = 'pendiente_confirmacion'
      AND registrada_at < NOW() - INTERVAL '72 hours'
  LOOP
    v_duracion_h := v_row.duracion_minutos / 60.0;

    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = v_row.id;

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_row.alumno_id AND estado = 'activo' LIMIT 1;
    IF NOT FOUND THEN
      SELECT * INTO v_bono_pre FROM public.bonos
      WHERE alumno_id = v_row.alumno_id AND estado = 'pagado_en_espera'
      ORDER BY fecha_pago ASC NULLS LAST, created_at ASC LIMIT 1;
    END IF;

    IF FOUND THEN
      IF v_bono_pre.estado = 'activo' THEN
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, v_bono_pre.horas_restantes)
        WHERE id = v_row.id;
      ELSE
        SELECT COALESCE(horas_deuda, 0) INTO v_deuda FROM public.alumnos WHERE id = v_row.alumno_id;
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, GREATEST(0, v_bono_pre.horas_contratadas - v_deuda))
        WHERE id = v_row.id;
      END IF;
    END IF;

    PERFORM public._consumir_horas_sesion(v_row.alumno_id, v_duracion_h, NOW());
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- Permitir que cualquier usuario autenticado lo llame (es seguro: solo procesa sesiones > 72h)
GRANT EXECUTE ON FUNCTION public.auto_confirm_old_sessions() TO authenticated;

-- ============================================================
-- RPC: Recalcular bonos de un alumno (solo admin/service role)
-- ============================================================
CREATE OR REPLACE FUNCTION public.recalcular_bonos_alumno(p_alumno_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sesion     RECORD;
  v_bono_row   RECORD;
  v_bono_pre   public.bonos%ROWTYPE;
  v_primera    BOOLEAN := TRUE;
  v_duracion_h NUMERIC;
  v_deuda      NUMERIC;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo administradores pueden recalcular bonos';
  END IF;

  -- 1. Resetear bonos elegibles en orden cronológico
  FOR v_bono_row IN
    SELECT id, horas_contratadas
    FROM public.bonos
    WHERE alumno_id = p_alumno_id
      AND estado NOT IN ('cancelado')
    ORDER BY COALESCE(fecha_pago, created_at) ASC, id ASC
  LOOP
    UPDATE public.bonos
    SET horas_consumidas = 0,
        horas_restantes  = CASE WHEN v_primera THEN v_bono_row.horas_contratadas ELSE 0 END,
        estado           = CASE WHEN v_primera THEN 'activo' ELSE 'pagado_en_espera' END,
        agotado_at       = NULL
    WHERE id = v_bono_row.id;
    v_primera := FALSE;
  END LOOP;

  -- 2. Resetear contadores del alumno
  UPDATE public.alumnos
  SET horas_deuda = 0, horas_bono_total = 0, horas_bono_restantes = 0
  WHERE id = p_alumno_id;

  -- 3. Reproducir sesiones confirmadas en orden actualizando bono_id/horas_deducidas
  FOR v_sesion IN
    SELECT id, duracion_minutos,
           COALESCE(confirmada_at, registrada_at, NOW()) AS fecha_ts
    FROM public.sesiones
    WHERE alumno_id = p_alumno_id AND estado = 'confirmada'
    ORDER BY COALESCE(confirmada_at, registrada_at) ASC, id ASC
  LOOP
    v_duracion_h := v_sesion.duracion_minutos / 60.0;

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = p_alumno_id AND estado = 'activo' LIMIT 1;
    IF NOT FOUND THEN
      SELECT * INTO v_bono_pre FROM public.bonos
      WHERE alumno_id = p_alumno_id AND estado = 'pagado_en_espera'
      ORDER BY fecha_pago ASC NULLS LAST, created_at ASC LIMIT 1;
    END IF;

    IF FOUND THEN
      IF v_bono_pre.estado = 'activo' THEN
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, v_bono_pre.horas_restantes)
        WHERE id = v_sesion.id;
      ELSE
        SELECT COALESCE(horas_deuda, 0) INTO v_deuda FROM public.alumnos WHERE id = p_alumno_id;
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, GREATEST(0, v_bono_pre.horas_contratadas - v_deuda))
        WHERE id = v_sesion.id;
      END IF;
    ELSE
      UPDATE public.sesiones SET bono_id = NULL, horas_deducidas = NULL WHERE id = v_sesion.id;
    END IF;

    PERFORM public._consumir_horas_sesion(p_alumno_id, v_duracion_h, v_sesion.fecha_ts);
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recalcular_bonos_alumno(UUID) TO authenticated;

-- ============================================================
-- RPC: Eliminar sesión cancelada (alumno elimina la suya)
-- ============================================================
CREATE OR REPLACE FUNCTION public.eliminar_sesion_cancelada(p_session_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session public.sesiones%ROWTYPE;
  v_alumno  public.alumnos%ROWTYPE;
BEGIN
  SELECT * INTO v_session FROM public.sesiones WHERE id = p_session_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Sesión no encontrada'); END IF;

  SELECT * INTO v_alumno FROM public.alumnos
  WHERE id = v_session.alumno_id AND usuario_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Sin permisos'); END IF;

  IF v_session.estado != 'cancelada' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden eliminar sesiones canceladas');
  END IF;

  DELETE FROM public.sesiones WHERE id = p_session_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.eliminar_sesion_cancelada(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.eliminar_bono_cancelado(p_bono_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_bono public.bonos%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos de administrador');
  END IF;

  SELECT * INTO v_bono FROM public.bonos WHERE id = p_bono_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bono no encontrado');
  END IF;

  IF v_bono.estado != 'cancelado' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden eliminar bonos cancelados');
  END IF;

  DELETE FROM public.bonos WHERE id = p_bono_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.eliminar_bono_cancelado(UUID) TO authenticated;

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
  horas_consumidas  NUMERIC(6,2) NOT NULL DEFAULT 0,
  horas_restantes   NUMERIC(6,2) NOT NULL DEFAULT 0,
  modalidad         TEXT NOT NULL CHECK (modalidad IN ('Presencial','Online')),
  precio_base       NUMERIC(8,2),
  descuento         NUMERIC(5,2) DEFAULT 0
                      CHECK (descuento >= 0 AND descuento <= 100),
  precio_final      NUMERIC(8,2),
  fecha_compra      DATE DEFAULT CURRENT_DATE,
  pagado            BOOLEAN DEFAULT FALSE,
  fecha_pago        DATE,
  estado            TEXT NOT NULL DEFAULT 'pagado_en_espera'
                      CHECK (estado IN ('pagado_en_espera','activo','agotado','cancelado')),
  notas             TEXT,
  agotado_at        TIMESTAMPTZ,
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

-- FK aplazada: sesiones.bono_id referencia bonos, que se define después de sesiones
ALTER TABLE public.sesiones ADD COLUMN IF NOT EXISTS bono_id UUID REFERENCES public.bonos(id);

-- ============================================================
-- Recalcular bonos de todos los alumnos para corregir historial
-- ============================================================
DO $$
DECLARE
  v_alumno_id UUID;
BEGIN
  FOR v_alumno_id IN SELECT id FROM public.alumnos LOOP
    PERFORM public.recalcular_bonos_alumno(v_alumno_id);
  END LOOP;
END;
$$;
