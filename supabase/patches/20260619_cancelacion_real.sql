-- ============================================================
-- PATCH: Cancelación con devolución real de bono
-- Ejecutar en Supabase → SQL Editor
-- ============================================================

-- 1. Añadir columnas de tracking en sesiones
ALTER TABLE public.sesiones
  ADD COLUMN IF NOT EXISTS bono_id        UUID REFERENCES public.bonos(id),
  ADD COLUMN IF NOT EXISTS horas_deducidas NUMERIC(6,2);

-- 2. Función auxiliar de reversión
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
      -- Bono original sigue activo: reversión directa
      UPDATE public.bonos
      SET horas_consumidas = GREATEST(0, horas_consumidas - v_deducidas),
          horas_restantes  = horas_restantes + v_deducidas
      WHERE id = v_session.bono_id;

      UPDATE public.alumnos
      SET horas_bono_restantes = horas_bono_restantes + v_deducidas
      WHERE id = v_session.alumno_id;

      -- Si hubo overflow a deuda, revertirlo también
      IF v_overflow > 0 THEN
        UPDATE public.alumnos
        SET horas_deuda = GREATEST(0, COALESCE(horas_deuda, 0) - v_overflow)
        WHERE id = v_session.alumno_id;
      END IF;

    ELSIF FOUND AND v_bono_orig.estado = 'agotado' THEN
      -- Cascada ocurrió: el bono original se agotó y se activó el siguiente

      SELECT * INTO v_bono_activo
      FROM public.bonos
      WHERE alumno_id = v_session.alumno_id AND estado = 'activo'
      LIMIT 1;

      IF FOUND AND v_overflow > 0 AND v_bono_activo.horas_consumidas <= v_overflow THEN
        -- El bono en cascada solo fue usado por esta sesión: reversión limpia
        UPDATE public.bonos
        SET estado = 'activo',
            horas_consumidas = GREATEST(0, v_bono_orig.horas_consumidas - v_deducidas),
            horas_restantes  = v_deducidas
        WHERE id = v_session.bono_id;

        UPDATE public.bonos
        SET estado = 'pagado_en_espera', horas_consumidas = 0, horas_restantes = 0
        WHERE id = v_bono_activo.id;

        UPDATE public.alumnos
        SET horas_bono_total     = v_bono_orig.horas_contratadas,
            horas_bono_restantes = v_deducidas
        WHERE id = v_session.alumno_id;

      ELSIF FOUND THEN
        -- El bono en cascada tiene sesiones adicionales: sólo devolver lo que se puede
        UPDATE public.bonos
        SET horas_consumidas = GREATEST(0, horas_consumidas - v_duracion_h),
            horas_restantes  = horas_restantes + v_duracion_h
        WHERE id = v_bono_activo.id;

        UPDATE public.alumnos
        SET horas_bono_restantes = horas_bono_restantes + v_duracion_h
        WHERE id = v_session.alumno_id;

      ELSE
        -- Sin bono activo: el overflow fue a horas_deuda; restaurar bono original y restar deuda
        UPDATE public.bonos
        SET estado = 'activo',
            horas_consumidas = GREATEST(0, v_bono_orig.horas_consumidas - v_deducidas),
            horas_restantes  = v_deducidas
        WHERE id = v_session.bono_id;

        UPDATE public.alumnos
        SET horas_bono_total     = v_bono_orig.horas_contratadas,
            horas_bono_restantes = v_deducidas,
            horas_deuda          = GREATEST(0, COALESCE(horas_deuda, 0) - v_overflow)
        WHERE id = v_session.alumno_id;
      END IF;

    ELSE
      -- bono_id pero no encontrado o en otro estado: fallback a bono activo
      SELECT * INTO v_bono_activo FROM public.bonos WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
      IF FOUND THEN
        UPDATE public.bonos
        SET horas_consumidas = GREATEST(0, horas_consumidas - v_duracion_h),
            horas_restantes  = horas_restantes + v_duracion_h
        WHERE id = v_bono_activo.id;
      END IF;
      UPDATE public.alumnos
      SET horas_bono_restantes = COALESCE(horas_bono_restantes, 0) + v_duracion_h
      WHERE id = v_session.alumno_id;
    END IF;

  ELSE
    -- Sin bono_id registrado (sesiones antiguas): fallback simple al bono activo
    SELECT * INTO v_bono_activo FROM public.bonos WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
    IF FOUND THEN
      UPDATE public.bonos
      SET horas_consumidas = GREATEST(0, horas_consumidas - v_duracion_h),
          horas_restantes  = horas_restantes + v_duracion_h
      WHERE id = v_bono_activo.id;
    END IF;
    UPDATE public.alumnos
    SET horas_bono_restantes = COALESCE(horas_bono_restantes, 0) + v_duracion_h
    WHERE id = v_session.alumno_id;
  END IF;
END;
$$;

-- 3. Actualizar cancelar_sesion_admin para usar la función de reversión real
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

-- 4. Actualizar process_session_confirmation para registrar bono_id y horas_deducidas
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
  v_session  public.sesiones%ROWTYPE;
  v_bono_pre public.bonos%ROWTYPE;
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

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;

    IF FOUND THEN
      UPDATE public.sesiones
      SET bono_id = v_bono_pre.id,
          horas_deducidas = LEAST(v_session.duracion_minutos / 60.0, v_bono_pre.horas_restantes)
      WHERE id = p_session_id;
    END IF;

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

-- 5. Actualizar confirmar_sesion_alumno para registrar bono_id y horas_deducidas
CREATE OR REPLACE FUNCTION public.confirmar_sesion_alumno(
  p_session_id UUID,
  p_action     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session  public.sesiones%ROWTYPE;
  v_alumno   public.alumnos%ROWTYPE;
  v_bono_pre public.bonos%ROWTYPE;
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
    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = p_session_id;

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;

    IF FOUND THEN
      UPDATE public.sesiones
      SET bono_id = v_bono_pre.id,
          horas_deducidas = LEAST(v_session.duracion_minutos / 60.0, v_bono_pre.horas_restantes)
      WHERE id = p_session_id;
    END IF;

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

-- 6. Actualizar auto_confirm_old_sessions para registrar bono_id y horas_deducidas
CREATE OR REPLACE FUNCTION public.auto_confirm_old_sessions()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row      RECORD;
  v_bono_pre public.bonos%ROWTYPE;
  v_count    INTEGER := 0;
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

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_row.alumno_id AND estado = 'activo' LIMIT 1;

    IF FOUND THEN
      UPDATE public.sesiones
      SET bono_id = v_bono_pre.id,
          horas_deducidas = LEAST(v_row.duracion_minutos / 60.0, v_bono_pre.horas_restantes)
      WHERE id = v_row.id;
    END IF;

    PERFORM public._consumir_horas_sesion(v_row.alumno_id, v_row.duracion_minutos / 60.0);
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;
