-- ============================================================
-- Marca de aviso enviado en los informes
-- 2026-08-20
--
-- Evita que ocultar y volver a publicar un informe le mande al
-- alumno el mismo aviso una y otra vez.
-- ============================================================

ALTER TABLE public.informes
  ADD COLUMN IF NOT EXISTS notificado_at TIMESTAMPTZ;

COMMENT ON COLUMN public.informes.notificado_at IS
  'Cuándo se avisó al alumno de que el informe estaba disponible. Si tiene valor, no se reenvía el aviso.';
