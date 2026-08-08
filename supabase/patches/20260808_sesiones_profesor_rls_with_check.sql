-- ============================================================
-- Sesiones: split sesiones_profesor_own into separate policies
-- so that INSERT also validates alumno is assigned to the professor.
-- Previously, FOR ALL USING had no check on alumno_id — a professor
-- could insert a session for any alumno via direct API calls.
-- ============================================================

-- 1. Drop the old combined policy
DROP POLICY IF EXISTS "sesiones_profesor_own" ON public.sesiones;
DROP POLICY IF EXISTS "sesiones_profesor_select_update_delete" ON public.sesiones;
DROP POLICY IF EXISTS "sesiones_profesor_update" ON public.sesiones;
DROP POLICY IF EXISTS "sesiones_profesor_delete" ON public.sesiones;
DROP POLICY IF EXISTS "sesiones_profesor_insert" ON public.sesiones;

-- 2. SELECT: professor sees own sessions (no change in behaviour)
CREATE POLICY "sesiones_profesor_select_update_delete"
ON public.sesiones
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profesores
    WHERE usuario_id = auth.uid() AND id = sesiones.profesor_id
  )
);

-- 3. UPDATE: professor updates own sessions (no change in behaviour)
CREATE POLICY "sesiones_profesor_update"
ON public.sesiones
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.profesores
    WHERE usuario_id = auth.uid() AND id = sesiones.profesor_id
  )
);

-- 4. DELETE: professor deletes own sessions (no change in behaviour)
CREATE POLICY "sesiones_profesor_delete"
ON public.sesiones
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public.profesores
    WHERE usuario_id = auth.uid() AND id = sesiones.profesor_id
  )
);

-- 5. INSERT: also validate that alumno_id is assigned to this professor
--    via alumno_profesor junction. Prevents inserting sessions for
--    alumnos that don't belong to this professor.
CREATE POLICY "sesiones_profesor_insert"
ON public.sesiones
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profesores p
    WHERE p.usuario_id = auth.uid() AND p.id = sesiones.profesor_id
  )
  AND EXISTS (
    SELECT 1 FROM public.alumno_profesor ap
    WHERE ap.profesor_id = sesiones.profesor_id
      AND ap.alumno_id = sesiones.alumno_id
  )
);
