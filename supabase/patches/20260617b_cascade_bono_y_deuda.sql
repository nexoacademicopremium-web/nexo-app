-- ============================================================
-- PATCH: Cascada de bonos + columna horas_deuda
-- Ejecutar en Supabase → SQL Editor
-- ============================================================

-- 1. Nueva columna horas_deuda en alumnos
ALTER TABLE public.alumnos
  ADD COLUMN IF NOT EXISTS horas_deuda NUMERIC(6,2) NOT NULL DEFAULT 0;

-- 2. Función _activar_siguiente_bono — aplica horas_deuda al activar el siguiente bono
CREATE OR REPLACE FUNCTION public._activar_siguiente_bono(p_alumno_id UUID)
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
  SET estado = 'agotado',
      horas_restantes  = 0,
      horas_consumidas = horas_contratadas
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
        horas_restantes  = v_net
    WHERE id = v_next.id;

    UPDATE public.alumnos
    SET horas_bono_total     = v_next.horas_contratadas,
        horas_bono_restantes = v_net,
        horas_deuda          = GREATEST(0, v_deuda - v_next.horas_contratadas)
    WHERE id = p_alumno_id;

    IF v_net = 0 THEN
      PERFORM public._activar_siguiente_bono(p_alumno_id);
    END IF;
  ELSE
    UPDATE public.alumnos
    SET horas_bono_total = 0, horas_bono_restantes = 0
    WHERE id = p_alumno_id;
  END IF;
END;
$$;

-- 3. Nueva función _consumir_horas_sesion — gestiona cascada entre bonos
CREATE OR REPLACE FUNCTION public._consumir_horas_sesion(
  p_alumno_id  UUID,
  p_duracion_h NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_activo     public.bonos%ROWTYPE;
  v_siguiente  public.bonos%ROWTYPE;
  v_exceso     NUMERIC;
  v_deuda      NUMERIC;
  v_total_cons NUMERIC;
  v_net_rest   NUMERIC;
BEGIN
  SELECT * INTO v_activo
  FROM public.bonos
  WHERE alumno_id = p_alumno_id AND estado = 'activo'
  LIMIT 1;

  IF NOT FOUND THEN
    UPDATE public.alumnos
    SET horas_deuda = COALESCE(horas_deuda, 0) + p_duracion_h
    WHERE id = p_alumno_id;
    RETURN;
  END IF;

  IF p_duracion_h <= v_activo.horas_restantes THEN
    UPDATE public.bonos
    SET horas_consumidas = horas_consumidas + p_duracion_h,
        horas_restantes  = horas_restantes  - p_duracion_h
    WHERE id = v_activo.id;

    UPDATE public.alumnos
    SET horas_bono_restantes = GREATEST(0, horas_bono_restantes - p_duracion_h)
    WHERE id = p_alumno_id;

    IF v_activo.horas_restantes - p_duracion_h = 0 THEN
      PERFORM public._activar_siguiente_bono(p_alumno_id);
    END IF;

  ELSE
    v_exceso := p_duracion_h - v_activo.horas_restantes;

    UPDATE public.bonos
    SET estado = 'agotado', horas_consumidas = horas_contratadas, horas_restantes = 0
    WHERE id = v_activo.id;

    SELECT * INTO v_siguiente
    FROM public.bonos
    WHERE alumno_id = p_alumno_id AND estado = 'pagado_en_espera'
    ORDER BY fecha_pago ASC NULLS LAST, created_at ASC
    LIMIT 1;

    IF FOUND THEN
      SELECT COALESCE(horas_deuda, 0) INTO v_deuda FROM public.alumnos WHERE id = p_alumno_id;
      v_total_cons := v_deuda + v_exceso;
      v_net_rest   := GREATEST(0, v_siguiente.horas_contratadas - v_total_cons);

      UPDATE public.bonos
      SET estado           = CASE WHEN v_net_rest = 0 THEN 'agotado' ELSE 'activo' END,
          horas_consumidas = LEAST(v_siguiente.horas_contratadas, v_total_cons),
          horas_restantes  = v_net_rest
      WHERE id = v_siguiente.id;

      UPDATE public.alumnos
      SET horas_bono_total     = v_siguiente.horas_contratadas,
          horas_bono_restantes = v_net_rest,
          horas_deuda          = GREATEST(0, v_total_cons - v_siguiente.horas_contratadas)
      WHERE id = p_alumno_id;

      IF v_net_rest = 0 THEN
        PERFORM public._activar_siguiente_bono(p_alumno_id);
      END IF;
    ELSE
      UPDATE public.alumnos
      SET horas_bono_total     = 0,
          horas_bono_restantes = 0,
          horas_deuda          = COALESCE(horas_deuda, 0) + v_exceso
      WHERE id = p_alumno_id;
    END IF;
  END IF;
END;
$$;

-- 4. Actualizar process_session_confirmation para usar _consumir_horas_sesion
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
  v_session public.sesiones%ROWTYPE;
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

    PERFORM public._consumir_horas_sesion(v_session.alumno_id, v_session.duracion_minutos / 60.0);

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

-- 5. Actualizar confirmar_sesion_alumno para usar _consumir_horas_sesion
CREATE OR REPLACE FUNCTION public.confirmar_sesion_alumno(
  p_session_id UUID,
  p_action     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session public.sesiones%ROWTYPE;
  v_alumno  public.alumnos%ROWTYPE;
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

    PERFORM public._consumir_horas_sesion(v_session.alumno_id, v_session.duracion_minutos / 60.0);

    RETURN jsonb_build_object('success', true, 'action', 'confirmada');

  ELSIF p_action = 'rechazar' THEN
    UPDATE public.sesiones SET estado = 'rechazada' WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'action', 'rechazada');

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Acción no válida');
  END IF;
END;
$$;

-- 6. Actualizar auto_confirm_old_sessions para usar _consumir_horas_sesion
CREATE OR REPLACE FUNCTION public.auto_confirm_old_sessions()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row   RECORD;
  v_count INTEGER := 0;
BEGIN
  FOR v_row IN
    SELECT id, alumno_id, duracion_minutos
    FROM public.sesiones
    WHERE estado = 'pendiente_confirmacion'
      AND registrada_at < NOW() - INTERVAL '48 hours'  -- unificado: la app anuncia 48 h
  LOOP
    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = v_row.id;

    PERFORM public._consumir_horas_sesion(v_row.alumno_id, v_row.duracion_minutos / 60.0);

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;
