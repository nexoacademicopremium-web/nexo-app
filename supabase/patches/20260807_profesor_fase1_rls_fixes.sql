-- Profesor Fase 1: RLS security fixes
-- 1.3: preguntas_test expone respuesta_correcta a alumnos via SELECT *
-- 1.4: sesiones_alumno_confirm permite al alumno modificar cualquier columna

-- ============================================================
-- 1.3: get_preguntas_alumno — preguntas sin respuesta_correcta
-- Drops preguntas_alumno_read so direct table SELECT no longer works for alumno.
-- Alumno app calls this RPC instead; profe/admin keep their own policies intact.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_preguntas_alumno(
  p_test_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alumno_id UUID;
BEGIN
  v_alumno_id := get_alumno_id();
  IF v_alumno_id IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  -- Verify test is visible (and belongs to this alumno if assigned)
  IF NOT EXISTS (
    SELECT 1 FROM tests
    WHERE id = p_test_id
      AND visible = TRUE
      AND (alumno_id IS NULL OR alumno_id = v_alumno_id)
  ) THEN
    RAISE EXCEPTION 'Test no disponible';
  END IF;

  RETURN (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id',        p.id,
        'enunciado', p.enunciado,
        'opcion_a',  p.opcion_a,
        'opcion_b',  p.opcion_b,
        'opcion_c',  p.opcion_c,
        'opcion_d',  p.opcion_d,
        'orden',     p.orden
      ) ORDER BY p.orden
    )
    FROM preguntas_test p
    WHERE p.test_id = p_test_id
  );
END;
$$;

REVOKE ALL  ON FUNCTION public.get_preguntas_alumno(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_preguntas_alumno(UUID) TO authenticated;

-- Drop the old open-access policy
DROP POLICY IF EXISTS preguntas_alumno_read ON public.preguntas_test;

-- ============================================================
-- 1.4: Drop sesiones_alumno_confirm
-- This policy allowed alumno to UPDATE any column in their session row
-- as long as estado ended up in ('confirmada','rechazada').
-- Confirmation is already handled server-side by:
--   - process_session_confirmation (token-based, email link)
--   - confirmar_sesion_alumno (auth-based RPC)
-- Neither needs direct table UPDATE access.
-- ============================================================
DROP POLICY IF EXISTS sesiones_alumno_confirm ON public.sesiones;
