-- ============================================================
-- AUDITORÍA BLOQUE A — Parches críticos pre-lanzamiento
-- 2026-08-13
-- ============================================================

-- ------------------------------------------------------------
-- A.1: Quitar permiso de escritura a alumnos en resultados_test
-- El RPC corregir_test es SECURITY DEFINER y no necesita este permiso
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "resultados_alumno_own" ON public.resultados_test;

CREATE POLICY "resultados_alumno_read" ON public.resultados_test
  FOR SELECT USING (alumno_id = public.get_alumno_id());

-- ------------------------------------------------------------
-- A.2: Permitir a profesores subir y gestionar material
-- ------------------------------------------------------------

-- El profesor puede crear/editar/borrar material que él mismo haya subido
CREATE POLICY "material_profesor_all" ON public.material
  FOR ALL
  USING (subido_por = auth.uid())
  WITH CHECK (subido_por = auth.uid());

-- El profesor puede asignar material a sus alumnos
CREATE POLICY "material_alumno_profesor_insert" ON public.material_alumno
  FOR INSERT
  WITH CHECK (
    asignado_por = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.alumno_profesor ap
      WHERE ap.alumno_id = material_alumno.alumno_id
        AND ap.profesor_id = public.get_profesor_id()
    )
  );

-- El profesor puede ver las asignaciones que él hizo
CREATE POLICY "material_alumno_profesor_read" ON public.material_alumno
  FOR SELECT USING (asignado_por = auth.uid());

-- El profesor puede borrar las asignaciones que él hizo
CREATE POLICY "material_alumno_profesor_delete" ON public.material_alumno
  FOR DELETE USING (asignado_por = auth.uid());

-- ------------------------------------------------------------
-- A.3: Añadir token de acceso temporal a informes
-- ------------------------------------------------------------
ALTER TABLE public.informes
  ADD COLUMN IF NOT EXISTS token UUID DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS token_expira TIMESTAMPTZ;

-- Índice para búsqueda rápida por token
CREATE INDEX IF NOT EXISTS idx_informes_token ON public.informes(token);

-- ------------------------------------------------------------
-- A.4: Eliminar función huérfana sin protección
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS public.reset_puede_repetir(UUID);

-- ------------------------------------------------------------
-- Verificación post-parche (ejecutar manualmente)
-- ------------------------------------------------------------
-- 1. Con sesión de alumno, intentar:
--    db.from('resultados_test').upsert({test_id:'...', alumno_id:'...', nota:10, respuestas:{}})
--    Debe dar error de permisos (new row violates row-level security policy)
--
-- 2. Con sesión de profesor, intentar subir un PDF y guardar la ficha
--    Debe funcionar
--
-- 3. Verificar que reset_puede_repetir ya no existe:
--    SELECT proname FROM pg_proc WHERE proname = 'reset_puede_repetir';
--    Debe devolver 0 filas
