-- ============================================================
-- FASE 2 — Integridad de base de datos
-- Ejecutar en Supabase → SQL Editor
-- Es idempotente: CREATE INDEX IF NOT EXISTS, OR REPLACE
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 2.1  ÍNDICES EN CLAVES FORÁNEAS
-- PostgreSQL no crea índices automáticos en FK (solo en PK/UNIQUE).
-- Sin estos índices cada JOIN o filtro hace un seq-scan completo.
-- ────────────────────────────────────────────────────────────

-- alumnos
CREATE INDEX IF NOT EXISTS idx_alumnos_usuario_id   ON public.alumnos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_alumnos_profesor_id  ON public.alumnos(profesor_id);

-- profesores
CREATE INDEX IF NOT EXISTS idx_profesores_usuario_id ON public.profesores(usuario_id);

-- sesiones (las más consultadas de todo el sistema)
CREATE INDEX IF NOT EXISTS idx_sesiones_alumno_id   ON public.sesiones(alumno_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_profesor_id ON public.sesiones(profesor_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_bono_id     ON public.sesiones(bono_id);
CREATE INDEX IF NOT EXISTS idx_sesiones_fecha       ON public.sesiones(fecha);
CREATE INDEX IF NOT EXISTS idx_sesiones_estado      ON public.sesiones(estado);

-- bonos
CREATE INDEX IF NOT EXISTS idx_bonos_alumno_id ON public.bonos(alumno_id);
CREATE INDEX IF NOT EXISTS idx_bonos_estado    ON public.bonos(estado);

-- alumno_profesor
CREATE INDEX IF NOT EXISTS idx_alumno_profesor_profesor_id   ON public.alumno_profesor(profesor_id);
CREATE INDEX IF NOT EXISTS idx_alumno_profesor_asignatura_id ON public.alumno_profesor(asignatura_id);

-- informes
CREATE INDEX IF NOT EXISTS idx_informes_alumno_id ON public.informes(alumno_id);

-- material
CREATE INDEX IF NOT EXISTS idx_material_asignatura_id ON public.material(asignatura_id);
CREATE INDEX IF NOT EXISTS idx_material_bloque_id     ON public.material(bloque_id);
CREATE INDEX IF NOT EXISTS idx_material_tema_id       ON public.material(tema_id);

-- preguntas_test / resultados_test
CREATE INDEX IF NOT EXISTS idx_preguntas_test_test_id    ON public.preguntas_test(test_id);
CREATE INDEX IF NOT EXISTS idx_resultados_test_alumno_id ON public.resultados_test(alumno_id);

-- calendario
CREATE INDEX IF NOT EXISTS idx_cal_alumno_alumno_id    ON public.calendario_alumno(alumno_id);
CREATE INDEX IF NOT EXISTS idx_cal_alumno_fecha        ON public.calendario_alumno(fecha);
CREATE INDEX IF NOT EXISTS idx_cal_profesor_profesor_id ON public.calendario_profesor(profesor_id);
CREATE INDEX IF NOT EXISTS idx_cal_profesor_fecha      ON public.calendario_profesor(fecha);

-- bloques / temas
CREATE INDEX IF NOT EXISTS idx_bloques_asignatura_id ON public.bloques(asignatura_id);
CREATE INDEX IF NOT EXISTS idx_temas_bloque_id       ON public.temas(bloque_id);

-- avisos
CREATE INDEX IF NOT EXISTS idx_avisos_destinatario_id ON public.avisos(destinatario_id);


-- ────────────────────────────────────────────────────────────
-- 2.2  FOR UPDATE — bloqueo de filas para evitar race condition
--
-- Problema: si dos sesiones del mismo alumno se confirman al
-- mismo tiempo (familia hace doble clic, por ejemplo), ambas
-- transacciones leen el mismo bono con horas_restantes = 2h,
-- ambas descuentan 1h, y el bono queda en 1h en lugar de 0h.
-- Se pierden horas del alumno sin registrar.
--
-- Solución: SELECT ... FOR UPDATE bloquea la fila. La segunda
-- transacción espera a que la primera termine antes de leer.
-- ────────────────────────────────────────────────────────────

-- _activar_siguiente_bono con FOR UPDATE
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

  -- FOR UPDATE: bloquea el siguiente bono en espera
  SELECT * INTO v_next
  FROM public.bonos
  WHERE alumno_id = p_alumno_id AND estado = 'en_espera'
  ORDER BY fecha_pago ASC NULLS LAST, created_at ASC
  LIMIT 1
  FOR UPDATE;

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


-- _consumir_horas_sesion con FOR UPDATE en cada iteración del LOOP
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
    -- FOR UPDATE: bloquea el bono activo mientras esta transacción trabaja
    SELECT * INTO v_activo
    FROM public.bonos
    WHERE alumno_id = p_alumno_id AND estado = 'activo'
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
      -- Sin bono activo: intentar activar el primero en espera
      SELECT * INTO v_activo
      FROM public.bonos
      WHERE alumno_id = p_alumno_id AND estado = 'en_espera'
      ORDER BY fecha_pago ASC NULLS LAST, created_at ASC
      LIMIT 1
      FOR UPDATE;

      IF NOT FOUND THEN
        -- Sin bonos disponibles: acumular deuda
        UPDATE public.alumnos
        SET horas_deuda          = COALESCE(horas_deuda, 0) + v_remaining,
            horas_bono_total     = 0,
            horas_bono_restantes = 0
        WHERE id = p_alumno_id;
        RETURN;
      END IF;

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
        CONTINUE;
      END IF;

      SELECT * INTO v_activo FROM public.bonos WHERE id = v_activo.id;
    END IF;

    IF v_remaining <= v_activo.horas_restantes THEN
      UPDATE public.bonos
      SET horas_consumidas = horas_consumidas + v_remaining,
          horas_restantes  = horas_restantes  - v_remaining
      WHERE id = v_activo.id;

      UPDATE public.alumnos
      SET horas_bono_restantes = GREATEST(0, horas_bono_restantes - v_remaining)
      WHERE id = p_alumno_id;

      IF v_activo.horas_restantes - v_remaining = 0 THEN
        PERFORM public._activar_siguiente_bono(p_alumno_id, p_fecha_ts);
      END IF;
      RETURN;

    ELSE
      UPDATE public.bonos
      SET estado           = 'agotado',
          horas_consumidas = horas_contratadas,
          horas_restantes  = 0,
          agotado_at       = COALESCE(agotado_at, p_fecha_ts)
      WHERE id = v_activo.id;

      v_remaining := v_remaining - v_activo.horas_restantes;
    END IF;
  END LOOP;
END;
$$;


-- process_session_confirmation con FOR UPDATE en sesión
-- Evita que dos clicks simultáneos confirmen la misma sesión dos veces
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
  -- FOR UPDATE: si dos clicks llegan a la vez, el segundo espera aquí
  SELECT * INTO v_session
  FROM public.sesiones
  WHERE id = p_session_id AND confirmation_token = p_token
  FOR UPDATE;

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

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
    IF NOT FOUND THEN
      SELECT * INTO v_bono_pre FROM public.bonos
      WHERE alumno_id = v_session.alumno_id AND estado = 'en_espera'
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


-- confirmar_sesion_alumno con FOR UPDATE en sesión
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
  -- FOR UPDATE: bloquea la sesión mientras se procesa
  SELECT * INTO v_session FROM public.sesiones WHERE id = p_session_id FOR UPDATE;
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

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
    IF NOT FOUND THEN
      SELECT * INTO v_bono_pre FROM public.bonos
      WHERE alumno_id = v_session.alumno_id AND estado = 'en_espera'
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


-- ────────────────────────────────────────────────────────────
-- 2.3  TRIGGER updated_at
-- Actualiza automáticamente updated_at en cada UPDATE,
-- evitando que quede desactualizado si algo no lo pone desde JS.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Informes (tiene updated_at confirmado)
DROP TRIGGER IF EXISTS trg_informes_updated_at ON public.informes;
CREATE TRIGGER trg_informes_updated_at
  BEFORE UPDATE ON public.informes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Alumnos (si tiene updated_at)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'alumnos' AND column_name = 'updated_at'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_alumnos_updated_at ON public.alumnos';
    EXECUTE 'CREATE TRIGGER trg_alumnos_updated_at
      BEFORE UPDATE ON public.alumnos
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()';
  END IF;
END $$;

-- Profesores (si tiene updated_at)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profesores' AND column_name = 'updated_at'
  ) THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_profesores_updated_at ON public.profesores';
    EXECUTE 'CREATE TRIGGER trg_profesores_updated_at
      BEFORE UPDATE ON public.profesores
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()';
  END IF;
END $$;
