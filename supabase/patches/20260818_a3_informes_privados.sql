-- ============================================================
-- A.3 — Los informes dejan de servirse como PDF público
-- 2026-08-18
--
-- El PDF pasa a guardarse como RUTA interna del bucket (pdf_path).
-- ver-informe valida el token y entrega el PDF con enlace firmado
-- de 120 s, así que ya no circula ninguna URL pública ni eterna.
-- ============================================================

ALTER TABLE public.informes
  ADD COLUMN IF NOT EXISTS pdf_path TEXT;

COMMENT ON COLUMN public.informes.pdf_path IS
  'Ruta interna en el bucket nexo-files. Nunca es una URL pública: el PDF se sirve firmado desde ver-informe.';

-- ------------------------------------------------------------
-- Revocar los enlaces de los informes ya publicados.
-- Sus URLs públicas siguen vivas en el bucket, así que además hay
-- que borrar la carpeta informes/ desde Storage (ver instrucciones).
-- Al republicar cada informe se regenera el enlace con token.
-- ------------------------------------------------------------
UPDATE public.informes
SET pdf_url      = NULL,
    archivo_url  = NULL,
    token_expira = NOW()
WHERE pdf_url LIKE '%/storage/v1/object/public/%'
   OR archivo_url LIKE '%/storage/v1/object/public/%';
