-- ============================================================
-- NOTIFICACIONES PUSH — suscripciones de dispositivo
-- 2026-08-18
--
-- Cada fila es un navegador/dispositivo que ha dado permiso.
-- Un mismo usuario puede tener varias (móvil, portátil, tablet).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id   UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  endpoint     TEXT NOT NULL UNIQUE,
  p256dh       TEXT NOT NULL,
  auth         TEXT NOT NULL,
  user_agent   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_push_subs_usuario ON public.push_subscriptions(usuario_id);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Cada usuario gestiona solo sus propios dispositivos.
DROP POLICY IF EXISTS "push_subs_propias_select" ON public.push_subscriptions;
CREATE POLICY "push_subs_propias_select" ON public.push_subscriptions
  FOR SELECT USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS "push_subs_propias_insert" ON public.push_subscriptions;
CREATE POLICY "push_subs_propias_insert" ON public.push_subscriptions
  FOR INSERT WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS "push_subs_propias_update" ON public.push_subscriptions;
CREATE POLICY "push_subs_propias_update" ON public.push_subscriptions
  FOR UPDATE USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS "push_subs_propias_delete" ON public.push_subscriptions;
CREATE POLICY "push_subs_propias_delete" ON public.push_subscriptions
  FOR DELETE USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS "push_subs_admin_all" ON public.push_subscriptions;
CREATE POLICY "push_subs_admin_all" ON public.push_subscriptions
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());


-- ------------------------------------------------------------
-- Preferencias: permite apagar los avisos sin desinstalar nada.
-- ------------------------------------------------------------
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS notif_push  BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS notif_email BOOLEAN NOT NULL DEFAULT TRUE;
