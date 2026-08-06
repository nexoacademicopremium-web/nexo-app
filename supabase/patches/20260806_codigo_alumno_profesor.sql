-- Añadir código interno a alumnos y profesores
ALTER TABLE public.alumnos    ADD COLUMN IF NOT EXISTS codigo TEXT;
ALTER TABLE public.profesores ADD COLUMN IF NOT EXISTS codigo TEXT;
