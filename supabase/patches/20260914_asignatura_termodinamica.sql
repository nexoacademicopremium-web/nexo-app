-- ============================================================
-- Añadir Termodinámica al catálogo de asignaturas
--
-- Pegar en el editor SQL de Supabase y ejecutar. Se puede lanzar
-- varias veces sin miedo: si la asignatura ya existe, no hace nada.
--
-- El id NO se pone a mano: la columna es GENERATED ALWAYS AS IDENTITY
-- y Postgres lo asigna él. Si se le pasa uno, responde con
-- "cannot insert a non-DEFAULT value into column id".
--
-- Una vez ejecutado aparece sola en todas partes (fichas de alumno y
-- de profesor, material, tests, informes), porque todas esas listas
-- leen de esta misma tabla.
-- ============================================================

INSERT INTO public.asignaturas (nombre)
SELECT 'Termodinámica'
WHERE NOT EXISTS (
  SELECT 1 FROM public.asignaturas WHERE nombre = 'Termodinámica'
);

-- Comprobación: debe salir en la lista.
SELECT id, nombre FROM public.asignaturas ORDER BY nombre;
