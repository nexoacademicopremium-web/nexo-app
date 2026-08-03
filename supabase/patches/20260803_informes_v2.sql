-- Informes v2: migrar tabla manual → sistema con IA
-- Ejecutar en Supabase SQL Editor

-- 1. Añadir columnas nuevas
ALTER TABLE public.informes
  ADD COLUMN IF NOT EXISTS contenido    JSONB,
  ADD COLUMN IF NOT EXISTS eliminado    BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS fecha_inicio DATE,
  ADD COLUMN IF NOT EXISTS fecha_fin    DATE,
  ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS pdf_url      TEXT;

-- 2. Añadir columna estado con default 'visible' (seguro para filas existentes)
ALTER TABLE public.informes ADD COLUMN IF NOT EXISTS estado TEXT NOT NULL DEFAULT 'visible';

-- 3. Constraints
ALTER TABLE public.informes DROP CONSTRAINT IF EXISTS informes_estado_check;
ALTER TABLE public.informes ADD CONSTRAINT informes_estado_check CHECK (estado IN ('oculto', 'visible'));

ALTER TABLE public.informes DROP CONSTRAINT IF EXISTS informes_tipo_check;
ALTER TABLE public.informes ADD CONSTRAINT informes_tipo_check CHECK (tipo IN ('mensual', 'semanal', 'personalizado'));

-- 4. Sincronizar estado con la columna visible existente
UPDATE public.informes SET estado = 'oculto' WHERE visible = FALSE OR visible IS NULL;

-- 5. Rellenar fecha_inicio / fecha_fin desde fecha en filas antiguas
UPDATE public.informes SET fecha_inicio = fecha, fecha_fin = fecha WHERE fecha_inicio IS NULL AND fecha IS NOT NULL;

-- 6. Rellenar pdf_url desde archivo_url en filas antiguas
UPDATE public.informes SET pdf_url = archivo_url WHERE pdf_url IS NULL AND archivo_url IS NOT NULL;

-- 7. Actualizar RLS alumno: usar estado en vez de visible
DROP POLICY IF EXISTS informes_alumno_read ON public.informes;
CREATE POLICY informes_alumno_read ON public.informes FOR SELECT USING (
  estado = 'visible' AND eliminado = FALSE AND
  EXISTS (
    SELECT 1 FROM public.alumnos
    WHERE alumnos.id = informes.alumno_id AND alumnos.usuario_id = auth.uid()
  )
);

-- 8. Reconstruir índice
DROP INDEX IF EXISTS idx_informes_alumno;
CREATE INDEX idx_informes_alumno ON public.informes(alumno_id) WHERE eliminado = FALSE;
