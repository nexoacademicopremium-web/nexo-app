-- Add PDF-test permission flag to profesores
-- Run once in Supabase SQL Editor
ALTER TABLE profesores
  ADD COLUMN IF NOT EXISTS puede_generar_test_pdf BOOLEAN DEFAULT FALSE;
