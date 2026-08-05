-- Añadir columna tema a tareas
ALTER TABLE public.tareas ADD COLUMN IF NOT EXISTS tema TEXT;
