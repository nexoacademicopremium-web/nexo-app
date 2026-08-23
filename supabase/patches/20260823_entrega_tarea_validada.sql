-- ============================================================
-- Y.4 — La entrega de una tarea debe ser un archivo del propio alumno
-- 2026-08-23
--
-- entregar_tarea comprobaba bien QUIÉN entrega, pero aceptaba cualquier
-- cadena como enlace. Desde la consola, un alumno podía entregar:
--   · un enlace externo, que el profesor abriría al corregir
--   · el archivo de otro alumno, presentándolo como suyo
--
-- Ahora el enlace tiene que apuntar al almacén de la aplicación y, en
-- concreto, a la carpeta de ese alumno: tareas/entregas/<su id>/...
-- El cliente sube ahí desde este mismo cambio.
-- ============================================================

CREATE OR REPLACE FUNCTION public.entregar_tarea(
  p_tarea_id    uuid,
  p_archivo_url text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alumno_id  uuid;
  v_estado     text;
  v_yo         uuid;
  v_prefijo    text;
BEGIN
  v_yo := get_alumno_id();
  IF v_yo IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No autorizado');
  END IF;

  SELECT alumno_id, estado
    INTO v_alumno_id, v_estado
    FROM public.tareas
   WHERE id = p_tarea_id
   FOR UPDATE;

  IF v_alumno_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tarea no encontrada');
  END IF;

  IF v_alumno_id != v_yo THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sin permisos');
  END IF;

  IF v_estado != 'pendiente' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden entregar tareas pendientes');
  END IF;

  -- El archivo debe estar en el almacén de la aplicación y dentro de la
  -- carpeta de este alumno. Así no puede entregarse un enlace externo ni
  -- el trabajo de otra persona.
  v_prefijo := '/storage/v1/object/public/nexo-files/tareas/entregas/' || v_yo::text || '/';

  IF p_archivo_url IS NULL OR position(v_prefijo in p_archivo_url) = 0 THEN
    RETURN jsonb_build_object('success', false,
      'error', 'El archivo de la entrega no es válido. Vuelve a subirlo desde tu panel.');
  END IF;

  UPDATE public.tareas
     SET archivo_entrega_url = p_archivo_url,
         fecha_entrega       = now(),
         estado              = 'entregada'
   WHERE id = p_tarea_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL  ON FUNCTION public.entregar_tarea(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.entregar_tarea(uuid, text) TO authenticated;

-- ------------------------------------------------------------
-- Entregas anteriores al cambio
-- ------------------------------------------------------------
-- Las que ya existen están fuera de la carpeta del alumno, así que no
-- pasarían la comprobación. No se tocan: solo afecta a entregas nuevas.
-- Para verlas:
--   SELECT id, titulo, archivo_entrega_url FROM tareas
--   WHERE archivo_entrega_url IS NOT NULL
--     AND archivo_entrega_url NOT LIKE '%/tareas/entregas/%/%';
