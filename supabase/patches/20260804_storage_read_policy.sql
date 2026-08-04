-- Permitir a usuarios autenticados leer archivos del bucket nexo-files
-- (necesario para generar signed URLs desde el cliente)
-- Ejecutar en: Supabase Dashboard → SQL Editor

CREATE POLICY "auth_read_nexo_files"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'nexo-files');

-- Si el bucket ya es público, este parche no es necesario pero tampoco hace daño.
-- Si los PDFs siguen sin abrir tras este parche, ve a:
-- Supabase Dashboard → Storage → nexo-files → Make Public
