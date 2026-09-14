-- ============================================================
-- Añadir Termodinámica al catálogo de asignaturas
--
-- Pegar en el editor SQL de Supabase y ejecutar. Se puede lanzar
-- varias veces sin miedo: si la asignatura ya existe, no hace nada.
--
-- Una vez ejecutado aparece sola en todas partes (fichas de alumno y
-- de profesor, material, tests, informes), porque todas esas listas
-- leen de esta misma tabla.
-- ============================================================

INSERT INTO public.asignaturas (id, nombre)
SELECT COALESCE(MAX(id), 0) + 1, 'Termodinámica'
FROM public.asignaturas
WHERE NOT EXISTS (
  SELECT 1 FROM public.asignaturas WHERE nombre = 'Termodinámica'
);

-- Comprobación: debe salir en la lista.
SELECT id, nombre FROM public.asignaturas ORDER BY nombre;
