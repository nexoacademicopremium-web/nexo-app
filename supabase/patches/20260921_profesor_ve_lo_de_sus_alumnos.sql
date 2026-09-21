-- ============================================================
-- El profesor ve lo de sus alumnos, lo haya creado quien lo haya creado
--
-- Hasta ahora un profesor solo veía lo que había creado él. Si el test
-- de inglés de Javier lo montaba el administrador, su profesora de
-- inglés no lo veía ni sabía qué nota había sacado, que es justo lo
-- que necesita para dar la clase siguiente.
--
-- La regla: un profesor ve lo de un alumno cuando le da clase, y solo
-- de las asignaturas que le da. Si a Javier le dan inglés y mates dos
-- profesores distintos, cada uno ve lo suyo.
--
-- Pegar en el editor SQL de Supabase. Es repetible.
-- ============================================================

-- ── Quién da clase a quién, y de qué ────────────────────────
-- Devuelve TRUE si el profesor que llama le da clase a ese alumno.
-- Si se le pasa una asignatura, además tiene que ser una de las que
-- le da.
--
-- Va como SECURITY DEFINER para poder mirar alumno_profesor sin que
-- los permisos de esa tabla se muerdan la cola con estos.
CREATE OR REPLACE FUNCTION public.profesor_da_clase_a(
  p_alumno_id  UUID,
  p_asignatura TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM alumno_profesor ap
    LEFT JOIN asignaturas a ON a.id = ap.asignatura_id
    WHERE ap.alumno_id   = p_alumno_id
      AND ap.profesor_id = get_profesor_id()
      AND (
        p_asignatura IS NULL        -- no se pregunta por asignatura
        OR ap.asignatura_id IS NULL -- le da clase sin asignatura concreta
        OR lower(trim(a.nombre)) = lower(trim(p_asignatura))
      )
  );
$$;

REVOKE ALL  ON FUNCTION public.profesor_da_clase_a(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.profesor_da_clase_a(UUID, TEXT) TO authenticated;


-- ── Tests ───────────────────────────────────────────────────
-- Los suyos, los de sus alumnos, y los generales de las asignaturas
-- que imparte (que son los que sus alumnos pueden encontrarse).
DROP POLICY IF EXISTS "tests_profesor_select" ON public.tests;

CREATE POLICY "tests_profesor_select" ON public.tests
  FOR SELECT
  USING (
    creado_por = auth.uid()
    OR (
      alumno_id IS NOT NULL
      AND profesor_da_clase_a(alumno_id, asignatura)
    )
    OR (
      -- Generales: los ve si imparte esa asignatura a alguien
      alumno_id IS NULL
      AND EXISTS (
        SELECT 1
        FROM alumno_profesor ap
        JOIN asignaturas a ON a.id = ap.asignatura_id
        WHERE ap.profesor_id = get_profesor_id()
          AND lower(trim(a.nombre)) = lower(trim(tests.asignatura))
      )
    )
  );


-- ── Preguntas ───────────────────────────────────────────────
-- Quien puede ver un test puede ver sus preguntas. Se apoya en la
-- política de arriba en vez de repetir la condición.
DROP POLICY IF EXISTS preguntas_profesor_manage ON public.preguntas_test;

-- Mirar: cualquier test que le esté permitido ver.
--
-- El primer AND es imprescindible y no sobra: sin él, esta política
-- valdría también para los alumnos, y como las políticas se suman,
-- un alumno podría leer preguntas_test de sus propios tests con la
-- respuesta correcta dentro. Se quitó por eso en agosto.
-- get_profesor_id() devuelve NULL para quien no es profesor.
CREATE POLICY "preguntas_profesor_select" ON public.preguntas_test
  FOR SELECT
  USING (
    get_profesor_id() IS NOT NULL
    AND EXISTS (SELECT 1 FROM tests t WHERE t.id = preguntas_test.test_id)
  );

-- Tocar: solo las de los tests que montó él.
CREATE POLICY "preguntas_profesor_write" ON public.preguntas_test
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM tests t
      WHERE t.id = preguntas_test.test_id
        AND t.creado_por = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM tests t
      WHERE t.id = preguntas_test.test_id
        AND t.creado_por = auth.uid()
    )
  );


-- ── Resultados ──────────────────────────────────────────────
-- Lo que de verdad hacía falta: qué ha sacado su alumno.
DROP POLICY IF EXISTS resultados_profesor_read ON public.resultados_test;

CREATE POLICY resultados_profesor_read ON public.resultados_test
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tests t
      WHERE t.id = resultados_test.test_id
        AND (
          t.creado_por = auth.uid()
          OR profesor_da_clase_a(resultados_test.alumno_id, t.asignatura)
        )
    )
  );


-- ── Material ────────────────────────────────────────────────
-- El que él subió, y el que tengan asignado sus alumnos.
DROP POLICY IF EXISTS "material_profesor_all" ON public.material;

-- Mirar.
CREATE POLICY "material_profesor_select" ON public.material
  FOR SELECT
  USING (
    subido_por = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM material_alumno ma
      WHERE ma.material_id = material.id
        AND profesor_da_clase_a(ma.alumno_id, material.asignatura)
    )
  );

-- Tocar: solo lo suyo.
CREATE POLICY "material_profesor_write" ON public.material
  FOR ALL
  USING      (subido_por = auth.uid())
  WITH CHECK (subido_por = auth.uid());


-- ── Asignaciones de material ────────────────────────────────
-- Para saber a quién se lo asignaron, aunque lo asignara el admin.
DROP POLICY IF EXISTS "material_alumno_profesor_read" ON public.material_alumno;

CREATE POLICY "material_alumno_profesor_read" ON public.material_alumno
  FOR SELECT
  USING (
    asignado_por = auth.uid()
    OR profesor_da_clase_a(alumno_id)
  );


-- Comprobación: deben salir todas.
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname IN (
    'tests_profesor_select',
    'preguntas_profesor_select', 'preguntas_profesor_write',
    'resultados_profesor_read',
    'material_profesor_select', 'material_profesor_write',
    'material_alumno_profesor_read'
  )
ORDER BY tablename, policyname;
