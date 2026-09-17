-- ============================================================
-- Preguntas de respuesta escrita
--
-- Tres de las cinco partes del test de nivel de inglés no son de
-- marcar A/B/C/D: se responden escribiendo. Open Cloze pide una
-- palabra, Word Formation una derivada y Key Word Transformation
-- media frase.
--
-- La corrección sigue haciéndose en el servidor. Si se hiciera en el
-- navegador, el alumno tendría que recibir las soluciones para poder
-- comparar, y bastaría con mirarlas antes de contestar.
--
-- Pegar en el editor SQL de Supabase. Es repetible.
-- ============================================================

-- ── Las formas que se dan por buenas ────────────────────────
-- En un hueco caben varias palabras igual de correctas: en
-- "walked ___ the old streets" valen around, through, along y down.
-- Dar por mala una que no lo es le baja el nivel al alumno sin motivo.
--
-- Si esta columna tiene algo, la pregunta es de escribir. Si está
-- vacía, es de las de siempre.
ALTER TABLE public.preguntas_test
  ADD COLUMN IF NOT EXISTS respuestas_validas TEXT[];

-- ── Comparar lo escrito con lo esperado ─────────────────────
-- Se ignoran mayúsculas, espacios de más, el punto final y el tipo de
-- apóstrofe: el móvil pone ' y el teclado pone ', y las dos son la
-- misma palabra.
CREATE OR REPLACE FUNCTION public._normalizar_respuesta(p_txt TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(
           regexp_replace(
             lower(translate(trim(COALESCE(p_txt, '')), '’‘`´', '''''''''')),
             '\s+', ' ', 'g'),
           '[.!?]+$', '');
$$;

-- ── Corrección ──────────────────────────────────────────────
-- Cambia respecto a la anterior:
--   · entiende las preguntas de escribir
--   · suma puntos además de aciertos, porque no todas valen igual
--   · devuelve las dos cifras, para la nota y para el nivel
CREATE OR REPLACE FUNCTION public.corregir_test(
  p_test_id    UUID,
  p_respuestas JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alumno_id     UUID;
  v_test          RECORD;
  v_existing      RECORD;
  v_pq            RECORD;
  v_correctas     INTEGER := 0;
  v_total         INTEGER := 0;
  v_puntos        NUMERIC := 0;
  v_puntos_total  NUMERIC := 0;
  v_nota          NUMERIC(4,2);
  v_solucionario  JSONB   := '{}'::JSONB;
  v_alumno_nombre TEXT;
  v_dada          TEXT;
  v_acierta       BOOLEAN;
BEGIN
  v_alumno_id := get_alumno_id();
  IF v_alumno_id IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  SELECT *
  INTO v_test
  FROM tests
  WHERE id        = p_test_id
    AND visible   = TRUE
    AND (alumno_id IS NULL OR alumno_id = v_alumno_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Test no encontrado o no disponible';
  END IF;

  SELECT nota INTO v_existing
  FROM resultados_test
  WHERE test_id = p_test_id AND alumno_id = v_alumno_id;

  IF FOUND AND v_test.alumno_id IS NOT NULL AND NOT COALESCE(v_test.puede_repetir, FALSE) THEN
    RAISE EXCEPTION 'ya completado';
  END IF;

  FOR v_pq IN
    SELECT id, respuesta_correcta, respuestas_validas, COALESCE(puntos, 1) AS puntos
    FROM preguntas_test
    WHERE test_id = p_test_id
  LOOP
    v_total        := v_total + 1;
    v_puntos_total := v_puntos_total + v_pq.puntos;
    v_dada         := p_respuestas->>(v_pq.id::TEXT);

    IF v_pq.respuestas_validas IS NOT NULL AND array_length(v_pq.respuestas_validas, 1) > 0 THEN
      -- De escribir: vale cualquiera de las formas aceptadas.
      v_acierta := EXISTS (
        SELECT 1
        FROM unnest(v_pq.respuestas_validas) AS valida
        WHERE _normalizar_respuesta(valida) = _normalizar_respuesta(v_dada)
          AND _normalizar_respuesta(v_dada) <> ''
      );
      -- En el solucionario se enseña la primera, que es la de
      -- referencia.
      v_solucionario := v_solucionario
        || jsonb_build_object(v_pq.id::TEXT, v_pq.respuestas_validas[1]);
    ELSE
      -- De marcar opción, como siempre.
      v_acierta      := v_dada = v_pq.respuesta_correcta;
      v_solucionario := v_solucionario
        || jsonb_build_object(v_pq.id::TEXT, v_pq.respuesta_correcta);
    END IF;

    IF v_acierta THEN
      v_correctas := v_correctas + 1;
      v_puntos    := v_puntos + v_pq.puntos;
    END IF;
  END LOOP;

  IF v_total = 0 THEN
    RAISE EXCEPTION 'El test no tiene preguntas';
  END IF;

  -- La nota sale de los puntos, no del número de preguntas: si una
  -- vale el doble, tiene que pesar el doble.
  v_nota := ROUND((v_puntos / NULLIF(v_puntos_total, 0)) * 10, 2);

  INSERT INTO resultados_test (test_id, alumno_id, respuestas, nota, completado_at)
  VALUES (p_test_id, v_alumno_id, p_respuestas, v_nota, NOW())
  ON CONFLICT (test_id, alumno_id) DO UPDATE
    SET respuestas    = EXCLUDED.respuestas,
        nota          = EXCLUDED.nota,
        completado_at = EXCLUDED.completado_at;

  IF v_test.alumno_id IS NOT NULL THEN
    UPDATE tests SET puede_repetir = FALSE WHERE id = p_test_id;
  END IF;

  IF v_test.alumno_id IS NOT NULL AND v_test.creado_por IS NOT NULL THEN
    SELECT TRIM(u.nombre || ' ' || COALESCE(u.apellidos, ''))
    INTO v_alumno_nombre
    FROM usuarios u
    JOIN alumnos  a ON a.usuario_id = u.id
    WHERE a.id = v_alumno_id;

    INSERT INTO avisos (destinatario_id, destinatario_rol, titulo, contenido, creado_por, visible)
    SELECT
      v_test.creado_por,
      'profesor',
      'Test completado: ' || v_test.titulo,
      COALESCE(v_alumno_nombre, 'Un alumno')
        || ' ha completado el test "' || v_test.titulo
        || '" con nota ' || v_nota || '/10.',
      NULL,
      TRUE
    WHERE EXISTS (
      SELECT 1 FROM usuarios WHERE id = v_test.creado_por AND rol = 'profesor'
    );
  END IF;

  RETURN jsonb_build_object(
    'nota',          v_nota,
    'correctas',     v_correctas,
    'total',         v_total,
    'puntos',        v_puntos,
    'puntos_total',  v_puntos_total,
    'solucionario',  v_solucionario
  );
END;
$$;

REVOKE ALL  ON FUNCTION public.corregir_test(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.corregir_test(UUID, JSONB) TO authenticated;

-- ── Y que las preguntas lleguen con lo que hace falta ────────
-- Se le añade el texto de apoyo y la palabra clave, que las partes de
-- escribir los necesitan para presentarse. La respuesta correcta
-- sigue sin salir.
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
        'puntos',    p.puntos,
        -- Solo dice si hay que escribir, no qué hay que escribir.
        'escribe',   (p.respuestas_validas IS NOT NULL
                      AND array_length(p.respuestas_validas, 1) > 0)
      ) ORDER BY p.orden
    )
    FROM preguntas_test p
    WHERE p.test_id = p_test_id
  );
END;
$$;

REVOKE ALL  ON FUNCTION public.get_preguntas_alumno(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_preguntas_alumno(UUID) TO authenticated;

-- Comprobación de que la comparación de texto hace lo que debe.
SELECT
  public._normalizar_respuesta('  Have Seen  ')      AS espacios_y_mayusculas,
  public._normalizar_respuesta('don’t have to')      AS apostrofe_de_movil,
  public._normalizar_respuesta('impressive.')        AS punto_final,
  public._normalizar_respuesta('has  been   learning') AS espacios_de_mas;
