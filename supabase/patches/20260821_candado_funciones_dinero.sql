-- ============================================================
-- Y.1 — Candado en las funciones del dinero que no lo tenían
-- 2026-08-21
--
-- El parche 20260807_fase2_integridad_bd.sql puso FOR UPDATE en cuatro
-- funciones. Estas nunca lo recibieron, así que dos operaciones sobre
-- el mismo alumno a la vez podían pisarse y perder horas.
--
-- La más importante es _revertir_horas_sesion: devuelve horas al
-- cancelar una clase confirmada. Es el mismo fallo que ya se corrigió,
-- pero al revés — en vez de no descontar, no devolver.
--
-- No se incluye eliminar_sesion_cancelada: solo borra una sesión ya
-- cancelada y no toca bonos ni horas, así que no hay nada que proteger.
--
-- Las definiciones son las vigentes (supabase/patches/20260621_bono_v2.sql),
-- con el candado añadido. La lógica no cambia.
-- ============================================================

-- ── recalcular_bonos_alumno ──────────────────────────────
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

  -- Candado: serializa cualquier otra operación sobre las horas de este
  -- alumno mientras dure la transacción.
  PERFORM 1 FROM public.alumnos WHERE id = p_alumno_id FOR UPDATE;
  PERFORM 1 FROM public.bonos   WHERE alumno_id = p_alumno_id FOR UPDATE;

  -- 1. Resetear todos los bonos en orden FIFO
  FOR v_bono_row IN
    SELECT id, horas_contratadas
    FROM public.bonos
    WHERE alumno_id = p_alumno_id
    ORDER BY COALESCE(fecha_pago, created_at) ASC, id ASC
  LOOP
    UPDATE public.bonos
    SET horas_consumidas = 0,
        horas_restantes  = CASE WHEN v_primera THEN v_bono_row.horas_contratadas ELSE 0 END,
        estado           = CASE WHEN v_primera THEN 'activo' ELSE 'en_espera' END,
        agotado_at       = NULL
    WHERE id = v_bono_row.id;
    v_primera := FALSE;
  END LOOP;

  -- 2. Resetear contadores del alumno
  UPDATE public.alumnos
  SET horas_deuda          = 0,
      horas_bono_total     = 0,
      horas_bono_restantes = 0
  WHERE id = p_alumno_id;

  -- 3. Reproducir sesiones confirmadas en orden cronológico
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
      WHERE alumno_id = p_alumno_id AND estado = 'en_espera'
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

-- ── _revertir_horas_sesion ──────────────────────────────
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

  -- Candado: serializa cualquier otra operación sobre las horas de este
  -- alumno mientras dure la transacción.
  PERFORM 1 FROM public.alumnos WHERE id = v_session.alumno_id FOR UPDATE;
  PERFORM 1 FROM public.bonos   WHERE alumno_id = v_session.alumno_id FOR UPDATE;

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
        SET estado           = 'en_espera',
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

-- ── auto_confirm_old_sessions ──────────────────────────────
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
      AND registrada_at < NOW() - INTERVAL '48 hours'
  LOOP
    v_duracion_h := v_row.duracion_minutos / 60.0;

    -- Candado por alumno dentro del bucle: cada iteración toca a uno
    -- distinto y se confirma en lote.
    PERFORM 1 FROM public.alumnos WHERE id = v_row.alumno_id FOR UPDATE;
    PERFORM 1 FROM public.bonos   WHERE alumno_id = v_row.alumno_id FOR UPDATE;

    UPDATE public.sesiones
    SET estado = 'confirmada', confirmada_at = NOW()
    WHERE id = v_row.id;

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = v_row.alumno_id AND estado = 'activo' LIMIT 1;
    IF NOT FOUND THEN
      SELECT * INTO v_bono_pre FROM public.bonos
      WHERE alumno_id = v_row.alumno_id AND estado = 'en_espera'
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

-- ── cancelar_sesion_admin ──────────────────────────────
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

  -- Candado: serializa cualquier otra operación sobre las horas de este
  -- alumno mientras dure la transacción.
  PERFORM 1 FROM public.alumnos WHERE id = v_session.alumno_id FOR UPDATE;
  PERFORM 1 FROM public.bonos   WHERE alumno_id = v_session.alumno_id FOR UPDATE;

  UPDATE public.sesiones
  SET estado = 'cancelada', cancelada_por = 'admin'
  WHERE id = p_session_id;

  -- Recalcular siempre si la sesión estaba confirmada (reemplaza _revertir_horas_sesion)
  IF v_session.estado = 'confirmada' THEN
    PERFORM public.recalcular_bonos_alumno(v_session.alumno_id);
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── eliminar_bono ──────────────────────────────
CREATE OR REPLACE FUNCTION public.eliminar_bono(p_bono_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_bono      public.bonos%ROWTYPE;
  v_alumno_id UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos de administrador');
  END IF;

  SELECT * INTO v_bono FROM public.bonos WHERE id = p_bono_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bono no encontrado');
  END IF;

  -- Candado: serializa cualquier otra operación sobre las horas de este
  -- alumno mientras dure la transacción.
  PERFORM 1 FROM public.alumnos WHERE id = v_bono.alumno_id FOR UPDATE;
  PERFORM 1 FROM public.bonos   WHERE alumno_id = v_bono.alumno_id FOR UPDATE;

  IF EXISTS (SELECT 1 FROM public.sesiones WHERE bono_id = p_bono_id) THEN
    RETURN jsonb_build_object('success', false,
      'error', 'Este bono tiene sesiones registradas y no puede eliminarse');
  END IF;

  v_alumno_id := v_bono.alumno_id;
  DELETE FROM public.bonos WHERE id = p_bono_id;
  PERFORM public.recalcular_bonos_alumno(v_alumno_id);

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── Versión huérfana de _activar_siguiente_bono ─────────────
-- En la base de datos conviven dos:
--   _activar_siguiente_bono(uuid)                  sin candado
--   _activar_siguiente_bono(uuid, timestamptz)     con candado
-- La de un solo parámetro es la antigua. Al crear la nueva con otra
-- firma, CREATE OR REPLACE no la sustituyó: dejó las dos vivas. Como
-- PostgreSQL elige según los argumentos, una llamada con un solo
-- parámetro se saltaría el candado.
--
-- Ninguna función vigente la llama así (solo lo hacía la versión de
-- junio de _consumir_horas_sesion, ya reemplazada), así que se retira.
DROP FUNCTION IF EXISTS public._activar_siguiente_bono(UUID);

-- ── Versión huérfana de corregir_tarea ──────────────────────
-- Mismo caso: al añadirle el archivo de corrección se creó una segunda
-- función en vez de sustituir la anterior.
--   corregir_tarea(uuid, numeric, text, jsonb)         3 de agosto
--   corregir_tarea(uuid, numeric, text, jsonb, text)   5 de agosto
--
-- Aquí además todos los parámetros tienen valor por defecto, así que una
-- llamada con cuatro argumentos encaja con las dos y PostgreSQL responde
-- "function is not unique". El panel llama con los cinco, por eso no ha
-- dado la cara todavía.
--
-- La antigua ni siquiera guarda el archivo de corrección: se retira.
DROP FUNCTION IF EXISTS public.corregir_tarea(uuid, numeric, text, jsonb);

-- Permisos: se mantienen los que ya tenían.
GRANT EXECUTE ON FUNCTION public.recalcular_bonos_alumno(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.eliminar_bono(UUID)           TO authenticated;
REVOKE EXECUTE ON FUNCTION public.auto_confirm_old_sessions() FROM authenticated, anon;

-- Comprobación: las diez deben devolver true.
-- SELECT proname, pg_get_functiondef(oid) LIKE '%FOR UPDATE%' AS candado
-- FROM pg_proc WHERE pronamespace='public'::regnamespace
--   AND proname IN ('_consumir_horas_sesion','_activar_siguiente_bono',
--     '_revertir_horas_sesion','confirmar_sesion_alumno',
--     'process_session_confirmation','auto_confirm_old_sessions',
--     'cancelar_sesion_admin','recalcular_bonos_alumno','eliminar_bono');
