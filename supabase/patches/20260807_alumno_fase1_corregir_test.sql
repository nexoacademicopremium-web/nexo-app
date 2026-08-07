-- Alumno Fase 1: corregir_test RPC (server-side scoring)
-- Replaces client-side nota calculation. Returns nota, correctas, total
-- and solucionario so the student can see correct answers after submission.
-- Also revokes direct client access to auto_confirm_old_sessions.

-- ============================================================
-- 1. corregir_test
-- ============================================================
CREATE OR REPLACE FUNCTION public.corregir_test(
  p_test_id    UUID,
  p_respuestas JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alumno_id     UUID;
  v_test          RECORD;
  v_existing      RECORD;
  v_pq            RECORD;
  v_correctas     INTEGER := 0;
  v_total         INTEGER := 0;
  v_nota          NUMERIC(4,2);
  v_solucionario  JSONB   := '{}'::JSONB;
  v_alumno_nombre TEXT;
BEGIN
  -- Authenticated alumno only
  v_alumno_id := get_alumno_id();
  IF v_alumno_id IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  -- Test must exist, be visible, and belong to this alumno (or be general)
  SELECT *
  INTO v_test
  FROM tests
  WHERE id        = p_test_id
    AND visible   = TRUE
    AND (alumno_id IS NULL OR alumno_id = v_alumno_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Test no encontrado o no disponible';
  END IF;

  -- Check for existing result
  SELECT nota INTO v_existing
  FROM resultados_test
  WHERE test_id = p_test_id AND alumno_id = v_alumno_id;

  -- Block re-submission if assigned test and cannot repeat
  IF FOUND AND v_test.alumno_id IS NOT NULL AND NOT COALESCE(v_test.puede_repetir, FALSE) THEN
    RAISE EXCEPTION 'ya completado';
  END IF;

  -- Score server-side
  FOR v_pq IN
    SELECT id, respuesta_correcta
    FROM preguntas_test
    WHERE test_id = p_test_id
  LOOP
    v_total       := v_total + 1;
    v_solucionario := v_solucionario || jsonb_build_object(v_pq.id::TEXT, v_pq.respuesta_correcta);
    IF p_respuestas->>(v_pq.id::TEXT) = v_pq.respuesta_correcta THEN
      v_correctas := v_correctas + 1;
    END IF;
  END LOOP;

  IF v_total = 0 THEN
    RAISE EXCEPTION 'El test no tiene preguntas';
  END IF;

  v_nota := ROUND((v_correctas::NUMERIC / v_total) * 10, 2);

  -- Persist result
  INSERT INTO resultados_test (test_id, alumno_id, respuestas, nota, completado_at)
  VALUES (p_test_id, v_alumno_id, p_respuestas, v_nota, NOW())
  ON CONFLICT (test_id, alumno_id) DO UPDATE
    SET respuestas    = EXCLUDED.respuestas,
        nota          = EXCLUDED.nota,
        completado_at = EXCLUDED.completado_at;

  -- Lock assigned test once submitted (no más puede_repetir)
  IF v_test.alumno_id IS NOT NULL THEN
    UPDATE tests SET puede_repetir = FALSE WHERE id = p_test_id;
  END IF;

  -- Notify professor via aviso (assigned tests only, fire-and-forget)
  IF v_test.alumno_id IS NOT NULL AND v_test.creado_por IS NOT NULL THEN
    SELECT TRIM(u.nombre || ' ' || COALESCE(u.apellidos, ''))
    INTO v_alumno_nombre
    FROM usuarios u
    JOIN alumnos  a ON a.usuario_id = u.id
    WHERE a.id = v_alumno_id;

    INSERT INTO avisos (destinatario_id, destinatario_rol, titulo, contenido, creado_por, visible)
    SELECT
      v_test.creado_por,
      'profesor',
      'Test completado: ' || v_test.titulo,
      COALESCE(v_alumno_nombre, 'Un alumno')
        || ' ha completado el test "' || v_test.titulo
        || '" con nota ' || v_nota || '/10.',
      NULL,
      TRUE
    WHERE EXISTS (
      SELECT 1 FROM usuarios WHERE id = v_test.creado_por AND rol = 'profesor'
    );
  END IF;

  RETURN jsonb_build_object(
    'nota',        v_nota,
    'correctas',   v_correctas,
    'total',       v_total,
    'solucionario', v_solucionario
  );
END;
$$;

REVOKE ALL  ON FUNCTION public.corregir_test(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.corregir_test(UUID, JSONB) TO authenticated;

-- ============================================================
-- 2. get_solucionario — correct answers for an already-completed test
-- Only returns data if the alumno has already submitted a result.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_solucionario(
  p_test_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alumno_id UUID;
  v_solucionario JSONB := '{}'::JSONB;
  v_pq RECORD;
BEGIN
  v_alumno_id := get_alumno_id();
  IF v_alumno_id IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  -- Only serve solucionario if the alumno already has a result
  IF NOT EXISTS (
    SELECT 1 FROM resultados_test
    WHERE test_id = p_test_id AND alumno_id = v_alumno_id
  ) THEN
    RAISE EXCEPTION 'Test no completado';
  END IF;

  FOR v_pq IN
    SELECT id, respuesta_correcta
    FROM preguntas_test
    WHERE test_id = p_test_id
  LOOP
    v_solucionario := v_solucionario || jsonb_build_object(v_pq.id::TEXT, v_pq.respuesta_correcta);
  END LOOP;

  RETURN v_solucionario;
END;
$$;

REVOKE ALL  ON FUNCTION public.get_solucionario(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_solucionario(UUID) TO authenticated;

-- ============================================================
-- 3. Revoke direct client access to auto_confirm_old_sessions
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.auto_confirm_old_sessions() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.auto_confirm_old_sessions() FROM anon;
