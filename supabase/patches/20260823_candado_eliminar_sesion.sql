-- ============================================================
-- Y.1b — Candado en eliminar_sesion_cancelada
-- 2026-08-23
--
-- Esta función quedó fuera del parche anterior a propósito: no toca
-- bonos ni horas, así que no hay dinero que proteger.
--
-- Pero sí tiene una carrera propia. Entre comprobar que la sesión está
-- cancelada y borrarla, otra transacción puede cambiarle el estado —el
-- admin reactivándola, por ejemplo— y se acabaría borrando una sesión
-- que ya no estaba cancelada.
--
-- El candado va sobre la fila de la sesión, no sobre los bonos.
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
  -- Se bloquea la sesión antes de mirarla: así su estado no puede
  -- cambiar entre la comprobación y el borrado.
  SELECT * INTO v_session FROM public.sesiones
  WHERE id = p_session_id
  FOR UPDATE;

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

GRANT EXECUTE ON FUNCTION public.eliminar_sesion_cancelada(UUID) TO authenticated;

-- Comprobación: ahora las diez llevan candado.
-- SELECT proname, pg_get_functiondef(oid) LIKE '%FOR UPDATE%' AS candado
-- FROM pg_proc WHERE pronamespace='public'::regnamespace
--   AND proname IN ('_consumir_horas_sesion','_activar_siguiente_bono',
--     '_revertir_horas_sesion','confirmar_sesion_alumno',
--     'process_session_confirmation','auto_confirm_old_sessions',
--     'cancelar_sesion_admin','recalcular_bonos_alumno','eliminar_bono',
--     'eliminar_sesion_cancelada')
-- ORDER BY proname;
