-- Allow profesor to manage (INSERT/UPDATE/DELETE) their own tests
-- Run once in Supabase SQL Editor
DROP POLICY IF EXISTS tests_profesor_manage ON tests;
CREATE POLICY tests_profesor_manage ON tests
  FOR ALL USING (creado_por = auth.uid());

-- Allow profesor to manage preguntas of their own tests
DROP POLICY IF EXISTS preguntas_profesor_manage ON preguntas_test;
CREATE POLICY preguntas_profesor_manage ON preguntas_test
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM tests
      WHERE tests.id = preguntas_test.test_id
        AND tests.creado_por = auth.uid()
    )
  );
