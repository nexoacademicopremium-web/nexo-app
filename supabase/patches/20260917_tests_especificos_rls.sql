-- ============================================================
-- Que un test específico solo lo pueda leer su destinatario
--
-- Con los tests dirigidos a un alumno concreto, el permiso de lectura
-- que había se queda corto: dejaba ver cualquier test visible, así que
-- un alumno podía leer por su cuenta el que se hizo para un compañero.
--
-- El panel ya los filtra, pero eso es la pantalla. Esto es el candado.
--
-- Pegar en el editor SQL de Supabase. Es repetible: borra el permiso
-- si existe y lo vuelve a crear igual.
-- ============================================================

DROP POLICY IF EXISTS "tests_alumno_read" ON public.tests;

CREATE POLICY "tests_alumno_read" ON public.tests
  FOR SELECT
  USING (
    visible = TRUE
    AND (
      -- Los de todo un curso
      alumno_id IS NULL
      -- o los suyos
      OR alumno_id = public.get_alumno_id()
    )
  );

-- Las preguntas van detrás del test: si no puede ver el test, tampoco
-- sus preguntas.
DROP POLICY IF EXISTS "preguntas_alumno_read" ON public.preguntas_test;

CREATE POLICY "preguntas_alumno_read" ON public.preguntas_test
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.tests t
      WHERE t.id = preguntas_test.test_id
        AND t.visible = TRUE
        AND (t.alumno_id IS NULL OR t.alumno_id = public.get_alumno_id())
    )
  );

-- Comprobación: deben salir las dos.
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname IN ('tests_alumno_read', 'preguntas_alumno_read');
