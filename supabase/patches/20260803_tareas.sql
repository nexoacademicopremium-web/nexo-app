-- ============================================================
-- TAREAS — Nexo Académico
-- Ejecutar desde el SQL Editor de Supabase
-- ============================================================

-- ── Tabla principal ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tareas (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  profesor_id           uuid        NOT NULL REFERENCES public.profesores(id) ON DELETE CASCADE,
  alumno_id             uuid        NOT NULL REFERENCES public.alumnos(id)    ON DELETE CASCADE,
  asignatura            text,
  titulo                text        NOT NULL,
  descripcion           text,
  archivo_enunciado_url text,
  fecha_creacion        timestamptz NOT NULL DEFAULT now(),
  fecha_limite          date,
  estado                text        NOT NULL DEFAULT 'pendiente'
                        CHECK (estado IN ('pendiente','entregada','corregida')),
  archivo_entrega_url   text,
  fecha_entrega         timestamptz,
  nota                  numeric,
  comentario_general    text,
  correccion_detallada  jsonb       NOT NULL DEFAULT '[]',
  fecha_correccion      timestamptz,
  visto_por_alumno      boolean     NOT NULL DEFAULT false
);

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE public.tareas ENABLE ROW LEVEL SECURITY;

-- Alumno: lee solo sus tareas
CREATE POLICY "tareas_alumno_read" ON public.tareas
  FOR SELECT
  USING (alumno_id = get_alumno_id());

-- Profesor: lee e inserta sus tareas (updates van solo por RPC)
CREATE POLICY "tareas_profesor_read" ON public.tareas
  FOR SELECT
  USING (profesor_id = get_profesor_id());

CREATE POLICY "tareas_profesor_insert" ON public.tareas
  FOR INSERT
  WITH CHECK (profesor_id = get_profesor_id());

-- Admin: acceso completo
CREATE POLICY "tareas_admin_all" ON public.tareas
  FOR ALL
  USING (is_admin());

-- ── RPC: entregar_tarea ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.entregar_tarea(
  p_tarea_id    uuid,
  p_archivo_url text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_alumno_id uuid;
  v_estado    text;
BEGIN
  SELECT alumno_id, estado
    INTO v_alumno_id, v_estado
    FROM public.tareas
   WHERE id = p_tarea_id;

  IF v_alumno_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tarea no encontrada');
  END IF;

  IF v_alumno_id != get_alumno_id() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos');
  END IF;

  IF v_estado != 'pendiente' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden entregar tareas pendientes');
  END IF;

  UPDATE public.tareas
     SET archivo_entrega_url = p_archivo_url,
         fecha_entrega       = now(),
         estado              = 'entregada'
   WHERE id = p_tarea_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── RPC: corregir_tarea ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.corregir_tarea(
  p_tarea_id   uuid,
  p_nota       numeric DEFAULT NULL,
  p_comentario text    DEFAULT NULL,
  p_correccion jsonb   DEFAULT '[]'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_profesor_id uuid;
  v_estado      text;
BEGIN
  SELECT profesor_id, estado
    INTO v_profesor_id, v_estado
    FROM public.tareas
   WHERE id = p_tarea_id;

  IF v_profesor_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tarea no encontrada');
  END IF;

  IF v_profesor_id != get_profesor_id() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos');
  END IF;

  IF v_estado != 'entregada' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden corregir tareas entregadas');
  END IF;

  UPDATE public.tareas
     SET nota                = p_nota,
         comentario_general  = p_comentario,
         correccion_detallada = COALESCE(p_correccion, '[]'),
         fecha_correccion    = now(),
         estado              = 'corregida',
         visto_por_alumno    = false
   WHERE id = p_tarea_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── RPC: marcar_tarea_vista ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.marcar_tarea_vista(p_tarea_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_alumno_id uuid;
BEGIN
  SELECT alumno_id
    INTO v_alumno_id
    FROM public.tareas
   WHERE id = p_tarea_id;

  IF v_alumno_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tarea no encontrada');
  END IF;

  IF v_alumno_id != get_alumno_id() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos');
  END IF;

  UPDATE public.tareas
     SET visto_por_alumno = true
   WHERE id = p_tarea_id;

  RETURN jsonb_build_object('success', true);
END;
$$;
