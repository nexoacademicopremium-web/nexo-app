-- ============================================================
-- Comprobar (y arreglar) que un profesor puede borrar su material
--
-- Ejecutar en el editor SQL de Supabase. La primera consulta solo
-- mira; no cambia nada. Si devuelve las cuatro filas, los permisos
-- ya están y no hace falta ejecutar el resto.
-- ============================================================

-- 1. ¿Están los permisos puestos?
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE (schemaname = 'public'  AND tablename IN ('material', 'material_alumno')
       AND policyname LIKE '%profesor%')
   OR (schemaname = 'storage' AND tablename = 'objects'
       AND policyname IN ('storage_profesor_delete', 'storage_profesor_insert'))
ORDER BY tablename, policyname;

-- Se esperan, al menos:
--   material           material_profesor_all            ALL
--   material_alumno    material_alumno_profesor_delete  DELETE
--   objects            storage_profesor_delete          DELETE
--   objects            storage_profesor_insert          INSERT


-- ============================================================
-- 2. Si falta alguna, ejecutar lo que sigue. Es repetible: primero
--    borra el permiso si existiera y lo vuelve a crear igual, así
--    que no rompe nada aunque ya estuviera puesto.
-- ============================================================

-- El profesor maneja el material que él mismo subió, y solo ese.
DROP POLICY IF EXISTS "material_profesor_all" ON public.material;
CREATE POLICY "material_profesor_all" ON public.material
  FOR ALL
  USING      (subido_por = auth.uid())
  WITH CHECK (subido_por = auth.uid());

-- Y las asignaciones a alumnos que hizo él.
DROP POLICY IF EXISTS "material_alumno_profesor_delete" ON public.material_alumno;
CREATE POLICY "material_alumno_profesor_delete" ON public.material_alumno
  FOR DELETE USING (asignado_por = auth.uid());

-- Borrar el archivo en sí del almacén.
DROP POLICY IF EXISTS "storage_profesor_delete" ON storage.objects;
CREATE POLICY "storage_profesor_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'nexo-files'
    AND EXISTS (
      SELECT 1 FROM public.profesores
      WHERE usuario_id = auth.uid() AND activo = TRUE
    )
  );

-- Y subirlo, que va en el mismo paquete.
DROP POLICY IF EXISTS "storage_profesor_insert" ON storage.objects;
CREATE POLICY "storage_profesor_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'nexo-files'
    AND EXISTS (
      SELECT 1 FROM public.profesores
      WHERE usuario_id = auth.uid() AND activo = TRUE
    )
  );
