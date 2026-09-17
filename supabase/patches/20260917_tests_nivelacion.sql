-- ============================================================
-- Tests de nivelación
--
-- Un test de nivelación no busca una nota: busca decir en qué nivel
-- está el alumno y cuántas horas le convienen. Se corrige igual que
-- cualquier otro, pero el resultado se lee de otra forma.
--
-- Pegar en el editor SQL de Supabase. Es repetible.
-- ============================================================

-- ── Qué clase de test es ────────────────────────────────────
-- 'normal'     → autoevaluación de siempre, nota sobre 10
-- 'nivelacion' → sitúa al alumno en un nivel
ALTER TABLE public.tests
  ADD COLUMN IF NOT EXISTS tipo TEXT NOT NULL DEFAULT 'normal';

ALTER TABLE public.tests DROP CONSTRAINT IF EXISTS tests_tipo_check;
ALTER TABLE public.tests
  ADD CONSTRAINT tests_tipo_check CHECK (tipo IN ('normal', 'nivelacion'));

-- ── Las preguntas se agrupan por partes ─────────────────────
-- En inglés: Grammar & Vocabulary, Open Cloze, Word Formation,
-- Key Word Transformation y Vocabulary in Use. Sirve para decirle al
-- alumno en qué parte flojea, no solo cuánto ha sacado en total.
ALTER TABLE public.preguntas_test
  ADD COLUMN IF NOT EXISTS parte TEXT;

-- No todas las preguntas valen igual: una transformación de frase
-- cuesta más que marcar una opción.
ALTER TABLE public.preguntas_test
  ADD COLUMN IF NOT EXISTS puntos SMALLINT NOT NULL DEFAULT 1;

ALTER TABLE public.preguntas_test DROP CONSTRAINT IF EXISTS preguntas_puntos_check;
ALTER TABLE public.preguntas_test
  ADD CONSTRAINT preguntas_puntos_check CHECK (puntos BETWEEN 1 AND 10);

-- ── El resultado guarda el desglose ─────────────────────────
-- Nivel alcanzado, puntos por parte y horas recomendadas, para poder
-- volver a enseñarlo sin recalcular nada.
ALTER TABLE public.resultados_test
  ADD COLUMN IF NOT EXISTS detalle JSONB;

-- Comprobación: deben salir las cinco columnas nuevas.
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    (table_name = 'tests'           AND column_name = 'tipo')
    OR (table_name = 'preguntas_test' AND column_name IN ('parte', 'puntos'))
    OR (table_name = 'resultados_test' AND column_name = 'detalle')
  )
ORDER BY table_name, column_name;

-- ============================================================
-- Que las preguntas lleguen al alumno con su parte y sus puntos
--
-- El alumno no lee la tabla de preguntas: la pide por esta función,
-- que le da todo menos la respuesta correcta. Para pintar el desglose
-- del test de nivelación necesita saber a qué parte pertenece cada
-- pregunta y cuánto vale.
--
-- Se mantiene igual todo lo demás, incluida la comprobación de que el
-- test sea suyo y de que la respuesta correcta NO salga.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_preguntas_alumno(p_test_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alumno_id UUID;
BEGIN
  v_alumno_id := get_alumno_id();
  IF v_alumno_id IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM tests
    WHERE id = p_test_id
      AND visible = TRUE
      AND (alumno_id IS NULL OR alumno_id = v_alumno_id)
  ) THEN
    RAISE EXCEPTION 'Test no disponible';
  END IF;

  RETURN (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id',        p.id,
        'enunciado', p.enunciado,
        'opcion_a',  p.opcion_a,
        'opcion_b',  p.opcion_b,
        'opcion_c',  p.opcion_c,
        'opcion_d',  p.opcion_d,
        'orden',     p.orden,
        'parte',     p.parte,
        'puntos',    p.puntos
      ) ORDER BY p.orden
    )
    FROM preguntas_test p
    WHERE p.test_id = p_test_id
  );
END;
$$;

REVOKE ALL  ON FUNCTION public.get_preguntas_alumno(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_preguntas_alumno(UUID) TO authenticated;
