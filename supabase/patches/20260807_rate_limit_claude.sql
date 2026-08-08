-- Rate limiting para llamadas a Claude API
-- Evita abuso por parte de profesores o admin comprometidos

CREATE TABLE IF NOT EXISTS public.claude_usage_log (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id  UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  funcion     TEXT NOT NULL,  -- 'generar-informe' | 'generate-test-from-pdf'
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_claude_usage_usuario_fn_ts
  ON public.claude_usage_log (usuario_id, funcion, created_at DESC);

-- Solo admin puede ver el log completo; nadie puede insertarlo directamente
ALTER TABLE public.claude_usage_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "claude_log_admin_all" ON public.claude_usage_log
  FOR ALL USING (public.is_admin());

-- Limits por función (ajustar según necesidad)
-- generar-informe:       máx 10 por día, admin-wide
-- generate-test-from-pdf: máx 15 por día por profesor
COMMENT ON TABLE public.claude_usage_log IS
  'Límites: generar-informe 10/día global; generate-test-from-pdf 15/día/usuario';
