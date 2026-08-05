-- Tabla currículo de temas por etapa/curso/asignatura
-- Ejecutar en: Supabase Dashboard → SQL Editor

CREATE TABLE IF NOT EXISTS public.curriculo_temas (
  id         SERIAL PRIMARY KEY,
  etapa      TEXT NOT NULL,
  curso      TEXT NOT NULL,
  modalidad  TEXT,
  asignatura TEXT NOT NULL,
  fiabilidad TEXT NOT NULL DEFAULT 'G',
  bloque     TEXT NOT NULL,
  tema       TEXT NOT NULL,
  añadido    BOOLEAN NOT NULL DEFAULT FALSE
);

-- RLS: lectura libre para autenticados, escritura solo admin
ALTER TABLE public.curriculo_temas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "curriculo_read_all"
  ON public.curriculo_temas FOR SELECT
  USING (TRUE);

CREATE POLICY "curriculo_admin_all"
  ON public.curriculo_temas FOR ALL
  USING (is_admin());

-- Índices para consultas frecuentes
CREATE INDEX IF NOT EXISTS curriculo_temas_curso_asig_idx
  ON public.curriculo_temas (curso, asignatura);
