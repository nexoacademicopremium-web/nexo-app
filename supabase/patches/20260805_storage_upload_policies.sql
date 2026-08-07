-- ============================================================
-- Storage upload policies para bucket nexo-files
-- Idempotente: DROP IF EXISTS antes de cada CREATE
-- ============================================================

-- Profesores: subir material y tareas
DROP POLICY IF EXISTS "storage_profesor_insert" ON storage.objects;
CREATE POLICY "storage_profesor_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'nexo-files'
  AND EXISTS (
    SELECT 1 FROM public.profesores
    WHERE usuario_id = auth.uid() AND activo = TRUE
  )
);

-- Profesores: borrar archivos del bucket
DROP POLICY IF EXISTS "storage_profesor_delete" ON storage.objects;
CREATE POLICY "storage_profesor_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'nexo-files'
  AND EXISTS (
    SELECT 1 FROM public.profesores
    WHERE usuario_id = auth.uid() AND activo = TRUE
  )
);

-- Alumnos: subir entregas de tareas (solo carpeta tareas/)
DROP POLICY IF EXISTS "storage_alumno_insert" ON storage.objects;
CREATE POLICY "storage_alumno_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'nexo-files'
  AND (storage.foldername(name))[1] = 'tareas'
  AND EXISTS (
    SELECT 1 FROM public.alumnos
    WHERE usuario_id = auth.uid() AND activo = TRUE
  )
);

-- Admin: acceso total (idempotente)
DROP POLICY IF EXISTS "storage_admin_all" ON storage.objects;
CREATE POLICY "storage_admin_all"
ON storage.objects
FOR ALL
TO authenticated
USING    (bucket_id = 'nexo-files' AND public.is_admin())
WITH CHECK (bucket_id = 'nexo-files' AND public.is_admin());
