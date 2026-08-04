-- Añadir columna html_cache para servir informes vía Edge Function
ALTER TABLE public.informes ADD COLUMN IF NOT EXISTS html_cache TEXT;
