-- =====================================================================
-- Test IA: extend tests + resultados RLS + RPCs
-- Run once in Supabase SQL Editor
-- =====================================================================

-- 1. New columns on tests
ALTER TABLE tests
  ADD COLUMN IF NOT EXISTS alumno_id    UUID REFERENCES alumnos(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS generado_ia  BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS puede_repetir BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS pdf_url      TEXT;

-- 2. Allow profesor to read resultados of tests they created
DROP POLICY IF EXISTS resultados_profesor_read ON resultados_test;
CREATE POLICY resultados_profesor_read ON resultados_test
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM tests
      WHERE tests.id = resultados_test.test_id
        AND tests.creado_por = auth.uid()
    )
  );

-- 3. RPC: alumno notifies profesor when test is completed (bypasses avisos RLS)
CREATE OR REPLACE FUNCTION notificar_test_completado(
  p_profesor_usuario_id UUID,
  p_alumno_nombre       TEXT,
  p_test_titulo         TEXT,
  p_nota                NUMERIC
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO avisos (destinatario_id, destinatario_rol, titulo, contenido, visible)
  VALUES (
    p_profesor_usuario_id,
    'profesor',
    'Test completado',
    p_alumno_nombre || ' ha completado el test "' || p_test_titulo
      || '" con nota ' || round(p_nota::numeric, 1) || '/10.',
    TRUE
  );
END;
$$;

-- 4. RPC: reset puede_repetir after alumno retakes (bypasses tests RLS for alumno)
CREATE OR REPLACE FUNCTION reset_puede_repetir(p_test_id UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE tests SET puede_repetir = FALSE WHERE id = p_test_id;
END;
$$;
