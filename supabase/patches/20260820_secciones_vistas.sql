-- ============================================================
-- Novedades por sección
-- 2026-08-20
--
-- Guarda cuándo miró cada usuario cada sección de su panel. Con
-- eso se calcula el contador rojo del menú: cuántas cosas han
-- llegado desde la última vez que entró.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.secciones_vistas (
  usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  seccion    TEXT NOT NULL,
  visto_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (usuario_id, seccion)
);

ALTER TABLE public.secciones_vistas ENABLE ROW LEVEL SECURITY;

-- Cada usuario solo ve y toca sus propias marcas.
DROP POLICY IF EXISTS "secciones_vistas_propias_select" ON public.secciones_vistas;
CREATE POLICY "secciones_vistas_propias_select" ON public.secciones_vistas
  FOR SELECT USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS "secciones_vistas_propias_insert" ON public.secciones_vistas;
CREATE POLICY "secciones_vistas_propias_insert" ON public.secciones_vistas
  FOR INSERT WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS "secciones_vistas_propias_update" ON public.secciones_vistas;
CREATE POLICY "secciones_vistas_propias_update" ON public.secciones_vistas
  FOR UPDATE USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS "secciones_vistas_admin" ON public.secciones_vistas;
CREATE POLICY "secciones_vistas_admin" ON public.secciones_vistas
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Para que "material nuevo" se pueda fechar: sin esto no hay forma de
-- saber cuándo se le asignó cada material al alumno.
CREATE INDEX IF NOT EXISTS idx_material_alumno_asignado
  ON public.material_alumno(alumno_id, asignado_at DESC);
