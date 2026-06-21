-- ============================================================
-- PATCH bono_v2 — Lógica de bonos coherente + recalcular
-- Ejecutar COMPLETO en Supabase → SQL Editor
-- Es idempotente: ADD COLUMN IF NOT EXISTS, CREATE OR REPLACE
-- ============================================================

-- 1. Columnas nuevas
ALTER TABLE public.alumnos
  ADD COLUMN IF NOT EXISTS horas_deuda NUMERIC(6,2) NOT NULL DEFAULT 0;

ALTER TABLE public.bonos
  ADD COLUMN IF NOT EXISTS agotado_at TIMESTAMPTZ;

ALTER TABLE public.sesiones
  ADD COLUMN IF NOT EXISTS bono_id        UUID REFERENCES public.bonos(id),
  ADD COLUMN IF NOT EXISTS horas_deducidas NUMERIC(6,2);

-- 2. _activar_siguiente_bono — aplica deuda al activar; soporta p_fecha_ts
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

-- 3. _consumir_horas_sesion — cascada bono a bono (bucle); activa pagado_en_espera si no hay activo
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

      -- Si el bono quedó exactamente a 0, activar el siguiente
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

-- 4. _revertir_horas_sesion — devuelve horas al bono correcto al cancelar
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
      UPDATE public.alumnos
      SET horas_bono_restantes = horas_bono_restantes + v_deducidas
      WHERE id = v_session.alumno_id;
      IF v_overflow > 0 THEN
        UPDATE public.alumnos
        SET horas_deuda = GREATEST(0, COALESCE(horas_deuda, 0) - v_overflow)
        WHERE id = v_session.alumno_id;
      END IF;

    ELSIF FOUND AND v_bono_orig.estado = 'agotado' THEN
      SELECT * INTO v_bono_activo FROM public.bonos
      WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;

      IF FOUND AND v_overflow > 0 AND v_bono_activo.horas_consumidas <= v_overflow THEN
        UPDATE public.bonos
        SET estado           = 'activo',
            horas_consumidas = GREATEST(0, v_bono_orig.horas_consumidas - v_deducidas),
            horas_restantes  = v_deducidas,
            agotado_at       = NULL
        WHERE id = v_session.bono_id;
        UPDATE public.bonos
        SET estado           = 'pagado_en_espera',
            horas_consumidas = 0,
            horas_restantes  = 0,
            agotado_at       = NULL
        WHERE id = v_bono_activo.id;
        UPDATE public.alumnos
        SET horas_bono_total     = v_bono_orig.horas_contratadas,
            horas_bono_restantes = v_deducidas
        WHERE id = v_session.alumno_id;
      ELSIF FOUND THEN
        UPDATE public.bonos
        SET horas_consumidas = GREATEST(0, horas_consumidas - v_duracion_h),
            horas_restantes  = horas_restantes + v_duracion_h
        WHERE id = v_bono_activo.id;
        UPDATE public.alumnos
        SET horas_bono_restantes = horas_bono_restantes + v_duracion_h
        WHERE id = v_session.alumno_id;
      ELSE
        UPDATE public.bonos
        SET estado           = 'activo',
            horas_consumidas = GREATEST(0, v_bono_orig.horas_consumidas - v_deducidas),
            horas_restantes  = v_deducidas,
            agotado_at       = NULL
        WHERE id = v_session.bono_id;
        UPDATE public.alumnos
        SET horas_bono_total     = v_bono_orig.horas_contratadas,
            horas_bono_restantes = v_deducidas,
            horas_deuda          = GREATEST(0, COALESCE(horas_deuda, 0) - v_overflow)
        WHERE id = v_session.alumno_id;
      END IF;

    ELSE
      SELECT * INTO v_bono_activo FROM public.bonos
      WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
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
    SELECT * INTO v_bono_activo FROM public.bonos
    WHERE alumno_id = v_session.alumno_id AND estado = 'activo' LIMIT 1;
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

-- 5. process_session_confirmation — registra bono_id y horas_deducidas (activo o pagado_en_espera)
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

-- 6. confirmar_sesion_alumno — registra bono_id y horas_deducidas (activo o pagado_en_espera)
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

-- 7. auto_confirm_old_sessions — registra bono_id y horas_deducidas (activo o pagado_en_espera)
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

-- 8. cancelar_sesion_admin — usa _revertir_horas_sesion
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

-- 9. recalcular_bonos_alumno — replica sesiones sobre bonos; actualiza sesiones.bono_id
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
  -- Solo admin o service role
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

  -- 2. Resetear deuda y contadores del alumno
  UPDATE public.alumnos
  SET horas_deuda          = 0,
      horas_bono_total     = 0,
      horas_bono_restantes = 0
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

-- 10. eliminar_sesion_cancelada — alumno elimina su propia sesión cancelada
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
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sesión no encontrada');
  END IF;

  SELECT * INTO v_alumno FROM public.alumnos
  WHERE id = v_session.alumno_id AND usuario_id = auth.uid();
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos');
  END IF;

  IF v_session.estado != 'cancelada' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden eliminar sesiones canceladas');
  END IF;

  DELETE FROM public.sesiones WHERE id = p_session_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- 11. eliminar_bono_cancelado — admin elimina un bono cancelado permanentemente
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

-- Eliminar política de INSERT de alumnos (ya no pueden crear bonos directamente)
DROP POLICY IF EXISTS "bonos_alumno_insert" ON public.bonos;

-- Actualizar CHECK constraint y DEFAULT del estado de bonos
ALTER TABLE public.bonos
  DROP CONSTRAINT IF EXISTS bonos_estado_check;

ALTER TABLE public.bonos
  ADD CONSTRAINT bonos_estado_check
    CHECK (estado IN ('pagado_en_espera','activo','agotado','cancelado'));

ALTER TABLE public.bonos
  ALTER COLUMN estado SET DEFAULT 'pagado_en_espera';

-- Grants
GRANT EXECUTE ON FUNCTION public.recalcular_bonos_alumno(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.eliminar_sesion_cancelada(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.eliminar_bono_cancelado(UUID) TO authenticated;

-- ============================================================
-- RECALCULAR TODOS LOS ALUMNOS (corregir datos históricos)
-- ============================================================
DO $$
DECLARE
  v_alumno RECORD;
BEGIN
  FOR v_alumno IN SELECT id FROM public.alumnos LOOP
    PERFORM public.recalcular_bonos_alumno(v_alumno.id);
  END LOOP;
END;
$$;
