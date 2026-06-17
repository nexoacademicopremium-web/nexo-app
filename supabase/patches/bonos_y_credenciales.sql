-- ============================================================
-- PATCH: bonos + admin_credenciales
-- Ejecutar en Supabase → SQL Editor
-- ============================================================

-- 1. Añadir columnas faltantes en bonos (IF NOT EXISTS es seguro)
ALTER TABLE public.bonos
  ADD COLUMN IF NOT EXISTS pagado          BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS fecha_pago      DATE,
  ADD COLUMN IF NOT EXISTS horas_consumidas NUMERIC(6,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS horas_restantes  NUMERIC(6,2) NOT NULL DEFAULT 0;

-- 2. Asegurar política admin en bonos (puede existir ya, ignorar error)
DO $$ BEGIN
  CREATE POLICY "bonos_admin_all" ON public.bonos
    FOR ALL USING (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Política INSERT para alumno (reserva desde panel alumno)
DO $$ BEGIN
  CREATE POLICY "bonos_alumno_insert" ON public.bonos
    FOR INSERT WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.alumnos a
        WHERE a.id = public.bonos.alumno_id AND a.usuario_id = auth.uid()
      )
      AND estado = 'reservado'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 4. Tabla admin_credenciales (para guardar usuario + contraseña de cada cuenta)
CREATE TABLE IF NOT EXISTS public.admin_credenciales (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id     UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  username       TEXT NOT NULL,
  password_plain TEXT NOT NULL,
  updated_at     TIMESTAMPTZ DEFAULT NOW(),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (usuario_id),
  UNIQUE (username)
);

ALTER TABLE public.admin_credenciales ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "admin_credenciales_admin_all" ON public.admin_credenciales
    FOR ALL USING (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
