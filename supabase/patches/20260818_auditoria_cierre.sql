-- ============================================================
-- AUDITORÍA DE CIERRE — parche final
-- 2026-08-18
--
-- Cubre: B.4, N.1, N.2, C.1, C.2, C.13
-- Todo es idempotente: se puede ejecutar más de una vez sin daño.
-- ============================================================


-- ------------------------------------------------------------
-- B.4 — Los tests generales también se bloquean tras el primer
-- intento, y solo los tests asignados devuelven el solucionario.
-- (CREATE OR REPLACE: si ya se aplicó, lo deja igual.)
-- ------------------------------------------------------------
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
  v_nota          NUMERIC(4,2);
  v_solucionario  JSONB   := '{}'::JSONB;
  v_alumno_nombre TEXT;
  v_es_asignado   BOOLEAN;
BEGIN
  v_alumno_id := get_alumno_id();
  IF v_alumno_id IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  SELECT * INTO v_test FROM tests
  WHERE id = p_test_id AND visible = TRUE
    AND (alumno_id IS NULL OR alumno_id = v_alumno_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Test no encontrado o no disponible';
  END IF;

  v_es_asignado := (v_test.alumno_id IS NOT NULL);

  SELECT nota INTO v_existing
  FROM resultados_test
  WHERE test_id = p_test_id AND alumno_id = v_alumno_id;

  -- Se bloquea la repetición en TODOS los tests. Única excepción:
  -- test asignado que el profesor ha marcado como repetible.
  IF FOUND AND NOT (v_es_asignado AND COALESCE(v_test.puede_repetir, FALSE)) THEN
    RAISE EXCEPTION 'ya completado';
  END IF;

  FOR v_pq IN SELECT id, respuesta_correcta FROM preguntas_test WHERE test_id = p_test_id
  LOOP
    v_total := v_total + 1;
    IF v_es_asignado THEN
      v_solucionario := v_solucionario || jsonb_build_object(v_pq.id::TEXT, v_pq.respuesta_correcta);
    END IF;
    IF p_respuestas->>(v_pq.id::TEXT) = v_pq.respuesta_correcta THEN
      v_correctas := v_correctas + 1;
    END IF;
  END LOOP;

  IF v_total = 0 THEN
    RAISE EXCEPTION 'El test no tiene preguntas';
  END IF;

  v_nota := ROUND((v_correctas::NUMERIC / v_total) * 10, 2);

  INSERT INTO resultados_test (test_id, alumno_id, respuestas, nota, completado_at)
  VALUES (p_test_id, v_alumno_id, p_respuestas, v_nota, NOW())
  ON CONFLICT (test_id, alumno_id) DO UPDATE
    SET respuestas = EXCLUDED.respuestas, nota = EXCLUDED.nota, completado_at = EXCLUDED.completado_at;

  IF v_es_asignado THEN
    UPDATE tests SET puede_repetir = FALSE WHERE id = p_test_id;
  END IF;

  IF v_es_asignado AND v_test.creado_por IS NOT NULL THEN
    SELECT TRIM(u.nombre || ' ' || COALESCE(u.apellidos, ''))
    INTO v_alumno_nombre
    FROM usuarios u JOIN alumnos a ON a.usuario_id = u.id
    WHERE a.id = v_alumno_id;

    INSERT INTO avisos (destinatario_id, destinatario_rol, titulo, contenido, creado_por, visible)
    SELECT v_test.creado_por, 'profesor',
      'Test completado: ' || v_test.titulo,
      COALESCE(v_alumno_nombre, 'Un alumno') || ' ha completado el test "' || v_test.titulo || '" con nota ' || v_nota || '/10.',
      NULL, TRUE
    WHERE EXISTS (SELECT 1 FROM usuarios WHERE id = v_test.creado_por AND rol = 'profesor');
  END IF;

  RETURN jsonb_build_object(
    'nota', v_nota,
    'correctas', v_correctas,
    'total', v_total,
    'solucionario', CASE WHEN v_es_asignado THEN v_solucionario ELSE '{}'::JSONB END
  );
END;
$$;


-- ------------------------------------------------------------
-- N.1 — Límites en los campos numéricos que tocan el dinero.
--
-- Se añaden como NOT VALID: obligan a partir de ahora, pero no
-- fallan si hubiera alguna fila antigua fuera de rango. Al final
-- del fichero hay una consulta para revisarlo.
-- ------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_duracion') THEN
    ALTER TABLE public.sesiones ADD CONSTRAINT chk_duracion
      CHECK (duracion_minutos > 0 AND duracion_minutos <= 600) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_bono_horas') THEN
    ALTER TABLE public.bonos ADD CONSTRAINT chk_bono_horas
      CHECK (horas_contratadas >= 0 AND horas_restantes >= 0 AND horas_consumidas >= 0) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_bono_precios') THEN
    ALTER TABLE public.bonos ADD CONSTRAINT chk_bono_precios
      CHECK (COALESCE(precio_base,0) >= 0 AND COALESCE(precio_final,0) >= 0
             AND COALESCE(descuento,0) >= 0 AND COALESCE(descuento,0) <= 100) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_horas_alumno') THEN
    ALTER TABLE public.alumnos ADD CONSTRAINT chk_horas_alumno
      CHECK (COALESCE(horas_bono_restantes,0) >= 0 AND COALESCE(horas_deuda,0) >= 0) NOT VALID;
  END IF;
END $$;


-- ------------------------------------------------------------
-- N.2 — Permisos explícitos de ejecución.
-- Por defecto Postgres da EXECUTE a PUBLIC, lo que incluye al rol
-- anon (visitantes sin cuenta). Se retira y se da solo a usuarios
-- autenticados, igual que ya se hizo con corregir_test.
-- ------------------------------------------------------------
DO $$
DECLARE
  fn RECORD;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'ajustar_bono_admin',
        'confirmar_sesion_alumno',
        'entregar_tarea',
        'marcar_tarea_vista',
        'corregir_tarea'
      )
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', fn.sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', fn.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', fn.sig);
  END LOOP;
END $$;


-- ------------------------------------------------------------
-- C.1 — sesiones_profesor_update sin WITH CHECK.
-- Sin esto, un profesor puede reasignar una sesión suya a un
-- alumno que no es suyo, o marcarla confirmada saltándose el
-- consumo de bono.
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "sesiones_profesor_update" ON public.sesiones;

CREATE POLICY "sesiones_profesor_update" ON public.sesiones
  FOR UPDATE
  USING (profesor_id = public.get_profesor_id())
  WITH CHECK (
    profesor_id = public.get_profesor_id()
    AND EXISTS (
      SELECT 1 FROM public.alumno_profesor ap
      WHERE ap.alumno_id  = sesiones.alumno_id
        AND ap.profesor_id = public.get_profesor_id()
    )
  );


-- ------------------------------------------------------------
-- C.2 — Códigos internos duplicables.
-- Índice único parcial: no afecta a las filas sin código.
-- Si falla, es que ya hay duplicados: la consulta del final los
-- localiza.
-- ------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_alumnos_codigo_unico
  ON public.alumnos(codigo) WHERE codigo IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profesores_codigo_unico
  ON public.profesores(codigo) WHERE codigo IS NOT NULL;


-- ------------------------------------------------------------
-- C.13 — Un alumno podía listar los títulos de todos los tests
-- del sistema. Ahora solo ve los generales y los suyos.
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "tests_alumno_read" ON public.tests;

CREATE POLICY "tests_alumno_read" ON public.tests
  FOR SELECT USING (
    visible = TRUE
    AND (alumno_id IS NULL OR alumno_id = public.get_alumno_id())
  );


-- ============================================================
-- COMPROBACIONES (ejecutar después, deben salir 0 filas)
-- ============================================================
-- Filas fuera de rango que impedirían validar los CHECK:
--
--   SELECT 'sesiones' t, count(*) FROM sesiones
--     WHERE duracion_minutos <= 0 OR duracion_minutos > 600
--   UNION ALL SELECT 'bonos', count(*) FROM bonos
--     WHERE horas_contratadas < 0 OR horas_restantes < 0 OR horas_consumidas < 0
--   UNION ALL SELECT 'alumnos', count(*) FROM alumnos
--     WHERE horas_bono_restantes < 0 OR horas_deuda < 0;
--
-- Códigos duplicados:
--
--   SELECT codigo, count(*) FROM alumnos WHERE codigo IS NOT NULL
--     GROUP BY codigo HAVING count(*) > 1;
