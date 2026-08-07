-- ============================================================
-- Storage upload policies para bucket nexo-files
-- Ejecutar desde Supabase Dashboard → SQL Editor
-- ============================================================

-- Profesores: pueden subir enunciados de tareas y material
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

-- Alumnos: pueden subir entregas de tareas
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

-- Profesores: pueden borrar sus propios archivos del bucket
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

-- Admin: INSERT completo (por si no existe ya)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename  = 'objects'
      AND policyname = 'storage_admin_all'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "storage_admin_all"
      ON storage.objects
      FOR ALL
      TO authenticated
      USING    (bucket_id = 'nexo-files' AND public.is_admin())
      WITH CHECK (bucket_id = 'nexo-files' AND public.is_admin());
    $p$;
  END IF;
END $$;
