-- ============================================================
-- Idioma preferido de cada persona
-- 2026-08-23
--
-- Se guarda en el perfil para que el idioma acompañe al usuario
-- aunque entre desde otro dispositivo. En el navegador se guarda
-- también una copia, para no esperar a la consulta al pintar.
-- ============================================================

ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS idioma TEXT NOT NULL DEFAULT 'es';

ALTER TABLE public.usuarios
  DROP CONSTRAINT IF EXISTS usuarios_idioma_check;

ALTER TABLE public.usuarios
  ADD CONSTRAINT usuarios_idioma_check CHECK (idioma IN ('es', 'en'));

COMMENT ON COLUMN public.usuarios.idioma IS
  'Idioma de la interfaz. Al añadir uno nuevo hay que ampliar también este CHECK.';
