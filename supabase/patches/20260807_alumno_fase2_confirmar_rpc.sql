-- Alumno Fase 2.1: confirmar.html accesible para usuarios anónimos
-- Problem: confirmar.html hace query directa a sesiones que RLS bloquea para anon.
-- Fix: RPC SECURITY DEFINER con token como mecanismo de auth; no expone datos extras.

-- ============================================================
-- 1. get_sesion_por_token
-- Returns session display data if id+token match.
-- Safe for anon — token acts as the auth credential.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_sesion_por_token(
  p_session_id UUID,
  p_token      UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sesion RECORD;
  v_prof   RECORD;
BEGIN
  SELECT
    s.id, s.estado, s.asignatura, s.fecha,
    s.hora_inicio, s.duracion_minutos, s.contenido_trabajado
  INTO v_sesion
  FROM sesiones s
  WHERE s.id                 = p_session_id
    AND s.confirmation_token = p_token;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT u.nombre, u.apellidos
  INTO v_prof
  FROM sesiones s
  JOIN profesores pr ON pr.id = s.profesor_id
  JOIN usuarios   u  ON u.id  = pr.usuario_id
  WHERE s.id = p_session_id;

  RETURN jsonb_build_object(
    'id',                 v_sesion.id,
    'estado',             v_sesion.estado,
    'asignatura',         v_sesion.asignatura,
    'fecha',              v_sesion.fecha,
    'hora_inicio',        v_sesion.hora_inicio,
    'duracion_minutos',   v_sesion.duracion_minutos,
    'contenido_trabajado', v_sesion.contenido_trabajado,
    'profesor', jsonb_build_object(
      'usuario', jsonb_build_object(
        'nombre',    COALESCE(v_prof.nombre, ''),
        'apellidos', COALESCE(v_prof.apellidos, '')
      )
    )
  );
END;
$$;

REVOKE ALL  ON FUNCTION public.get_sesion_por_token(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_sesion_por_token(UUID, UUID) TO anon;
GRANT EXECUTE ON FUNCTION public.get_sesion_por_token(UUID, UUID) TO authenticated;

-- ============================================================
-- 2. Ensure process_session_confirmation is accessible to anon
-- (The RPC validates via token — no auth token needed)
-- ============================================================
GRANT EXECUTE ON FUNCTION public.process_session_confirmation(UUID, UUID, TEXT) TO anon;
