-- Añadir columna para archivo corregido por el profesor
ALTER TABLE public.tareas ADD COLUMN IF NOT EXISTS archivo_correccion_url TEXT;

-- Actualizar RPC corregir_tarea para aceptar el archivo corregido
CREATE OR REPLACE FUNCTION public.corregir_tarea(
  p_tarea_id               uuid,
  p_nota                   numeric DEFAULT NULL,
  p_comentario             text    DEFAULT NULL,
  p_correccion             jsonb   DEFAULT '[]',
  p_archivo_correccion_url text    DEFAULT NULL
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
     SET nota                     = p_nota,
         comentario_general       = p_comentario,
         correccion_detallada     = COALESCE(p_correccion, '[]'),
         archivo_correccion_url   = p_archivo_correccion_url,
         fecha_correccion         = now(),
         estado                   = 'corregida',
         visto_por_alumno         = false
   WHERE id = p_tarea_id;

  RETURN jsonb_build_object('success', true);
END;
$$;
