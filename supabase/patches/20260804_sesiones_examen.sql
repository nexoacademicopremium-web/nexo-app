-- Campos de examen próximo en sesiones
-- Ejecutar en: Supabase Dashboard → SQL Editor

ALTER TABLE public.sesiones
  ADD COLUMN IF NOT EXISTS examen_proximo    BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS examen_fecha      DATE,
  ADD COLUMN IF NOT EXISTS examen_asignatura TEXT,
  ADD COLUMN IF NOT EXISTS examen_tema       TEXT;
