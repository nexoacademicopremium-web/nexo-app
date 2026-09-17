-- ============================================================
-- Tests dirigidos a un alumno concreto: que solo los vea él
--
-- ⚠️ CORREGIDO. Una versión anterior de este archivo recreaba el
--    permiso preguntas_alumno_read, que se había quitado a propósito
--    en agosto (patch 20260807_profesor_fase1_rls_fixes) porque
--    dejaba que un alumno leyera la tabla de preguntas entera,
--    respuesta correcta incluida.
--
--    Si llegaste a ejecutar la versión anterior, este archivo lo
--    deshace: el primer DROP se encarga.
--
--    Las preguntas no necesitan permiso: el alumno las pide por la
--    función get_preguntas_alumno, que ya comprueba que el test sea
--    suyo y no devuelve la respuesta correcta.
--
-- Pegar en el editor SQL de Supabase. Es repetible.
-- ============================================================

-- ── Lo que sí hace falta ────────────────────────────────────
-- El listado de tests del alumno sale de esta tabla, y hasta ahora
-- dejaba ver cualquiera que estuviera visible: con los tests dirigidos
-- a una persona, eso significa ver el de un compañero.
DROP POLICY IF EXISTS "tests_alumno_read" ON public.tests;

CREATE POLICY "tests_alumno_read" ON public.tests
  FOR SELECT
  USING (
    visible = TRUE
    AND (
      alumno_id IS NULL                      -- los de todo un curso
      OR alumno_id = public.get_alumno_id()  -- o los suyos
    )
  );

-- ── Lo que NO debe existir ──────────────────────────────────
-- Este permiso deja leer preguntas_test directamente, y ahí está la
-- respuesta correcta de cada pregunta.
DROP POLICY IF EXISTS "preguntas_alumno_read" ON public.preguntas_test;

-- Comprobación. Debe salir:
--   · tests_alumno_read      → SELECT     (tiene que estar)
--   · preguntas_alumno_read  → NO aparece (tiene que NO estar)
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname IN ('tests_alumno_read', 'preguntas_alumno_read');
