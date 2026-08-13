-- ============================================================
-- AUDITORÍA BLOQUE B — Parches importantes pre-lanzamiento
-- 2026-08-13
-- ============================================================

-- ------------------------------------------------------------
-- B.1: RPC para ajustar bonos de forma segura (transaccional)
-- Reemplaza las múltiples escrituras del admin que no tenían
-- bloqueo ni transacción
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION ajustar_bono_admin(
  p_bono_id            UUID,
  p_horas_contratadas  NUMERIC(6,2),
  p_horas_consumidas   NUMERIC(6,2) DEFAULT NULL,
  p_modalidad          TEXT DEFAULT NULL,
  p_precio_base        NUMERIC(8,2) DEFAULT NULL,
  p_descuento          NUMERIC(5,2) DEFAULT NULL,
  p_precio_final       NUMERIC(8,2) DEFAULT NULL,
  p_fecha_compra       DATE DEFAULT NULL,
  p_estado             TEXT DEFAULT NULL,
  p_notas              TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bono         RECORD;
  v_alumno       RECORD;
  v_new_estado   TEXT;
  v_new_restantes NUMERIC(6,2);
  v_hay_otro_activo BOOLEAN;
BEGIN
  -- Solo admin puede ejecutar esto
  IF NOT is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Solo el administrador puede ajustar bonos');
  END IF;

  -- Bloquear el bono para evitar condiciones de carrera
  SELECT * INTO v_bono
  FROM bonos
  WHERE id = p_bono_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bono no encontrado');
  END IF;

  -- Bloquear también el alumno
  SELECT * INTO v_alumno
  FROM alumnos
  WHERE id = v_bono.alumno_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Alumno no encontrado');
  END IF;

  -- Determinar nuevo estado
  v_new_estado := COALESCE(p_estado, v_bono.estado);

  -- Si el estado cambia a 'activo', verificar que no hay otro bono activo
  IF v_new_estado = 'activo' AND v_bono.estado != 'activo' THEN
    SELECT EXISTS (
      SELECT 1 FROM bonos
      WHERE alumno_id = v_bono.alumno_id
        AND estado = 'activo'
        AND id != p_bono_id
    ) INTO v_hay_otro_activo;

    IF v_hay_otro_activo THEN
      -- Agotar el otro bono activo
      UPDATE bonos
      SET estado = 'agotado',
          horas_restantes = 0,
          agotado_at = NOW()
      WHERE alumno_id = v_bono.alumno_id
        AND estado = 'activo'
        AND id != p_bono_id;
    END IF;
  END IF;

  -- Calcular horas restantes
  IF p_horas_consumidas IS NOT NULL THEN
    v_new_restantes := GREATEST(0, p_horas_contratadas - p_horas_consumidas);
  ELSE
    -- Si solo cambian las horas contratadas, ajustar proporcionalmente
    v_new_restantes := GREATEST(0, v_bono.horas_restantes + (p_horas_contratadas - v_bono.horas_contratadas));
  END IF;

  -- Actualizar el bono
  UPDATE bonos SET
    horas_contratadas = p_horas_contratadas,
    horas_consumidas  = COALESCE(p_horas_consumidas, horas_consumidas),
    horas_restantes   = v_new_restantes,
    modalidad         = COALESCE(p_modalidad, modalidad),
    precio_base       = COALESCE(p_precio_base, precio_base),
    descuento         = COALESCE(p_descuento, descuento),
    precio_final      = COALESCE(p_precio_final, precio_final),
    fecha_compra      = COALESCE(p_fecha_compra, fecha_compra),
    estado            = v_new_estado,
    notas             = COALESCE(p_notas, notas),
    pagado            = TRUE,
    fecha_pago        = COALESCE(fecha_pago, CURRENT_DATE),
    updated_at        = NOW()
  WHERE id = p_bono_id;

  -- Actualizar el alumno si el bono es/era activo
  IF v_new_estado = 'activo' THEN
    UPDATE alumnos SET
      horas_bono_restantes = v_new_restantes,
      horas_bono_total     = p_horas_contratadas,
      updated_at           = NOW()
    WHERE id = v_bono.alumno_id;
  ELSIF v_bono.estado = 'activo' AND v_new_estado != 'activo' THEN
    -- Era activo y ya no lo es: poner a cero
    UPDATE alumnos SET
      horas_bono_restantes = 0,
      horas_bono_total     = 0,
      updated_at           = NOW()
    WHERE id = v_bono.alumno_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'bono_id', p_bono_id,
    'horas_restantes', v_new_restantes,
    'estado', v_new_estado
  );
END;
$$;

-- ------------------------------------------------------------
-- B.4: Bloquear repetición en tests generales
-- Modificar corregir_test para que también bloquee tests generales
-- después de la primera vez, y no devolver solucionario en generales
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
  -- Authenticated alumno only
  v_alumno_id := get_alumno_id();
  IF v_alumno_id IS NULL THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  -- Test must exist, be visible, and belong to this alumno (or be general)
  SELECT *
  INTO v_test
  FROM tests
  WHERE id        = p_test_id
    AND visible   = TRUE
    AND (alumno_id IS NULL OR alumno_id = v_alumno_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Test no encontrado o no disponible';
  END IF;

  v_es_asignado := (v_test.alumno_id IS NOT NULL);

  -- Check for existing result
  SELECT nota INTO v_existing
  FROM resultados_test
  WHERE test_id = p_test_id AND alumno_id = v_alumno_id;

  -- B.4 FIX: Block re-submission for ALL tests (assigned or general)
  -- Exception: assigned tests with puede_repetir = TRUE
  IF FOUND THEN
    IF v_es_asignado AND COALESCE(v_test.puede_repetir, FALSE) THEN
      -- Test asignado con repetición permitida: OK, continuar
      NULL;
    ELSE
      -- Bloquear: test general ya hecho, o test asignado sin repetición
      RAISE EXCEPTION 'ya completado';
    END IF;
  END IF;

  -- Score server-side
  FOR v_pq IN
    SELECT id, respuesta_correcta
    FROM preguntas_test
    WHERE test_id = p_test_id
  LOOP
    v_total := v_total + 1;
    -- Solo acumular solucionario para tests asignados
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

  -- Persist result
  INSERT INTO resultados_test (test_id, alumno_id, respuestas, nota, completado_at)
  VALUES (p_test_id, v_alumno_id, p_respuestas, v_nota, NOW())
  ON CONFLICT (test_id, alumno_id) DO UPDATE
    SET respuestas    = EXCLUDED.respuestas,
        nota          = EXCLUDED.nota,
        completado_at = EXCLUDED.completado_at;

  -- Lock assigned test once submitted (no más puede_repetir)
  IF v_es_asignado THEN
    UPDATE tests SET puede_repetir = FALSE WHERE id = p_test_id;
  END IF;

  -- Notify professor via aviso (assigned tests only, fire-and-forget)
  IF v_es_asignado AND v_test.creado_por IS NOT NULL THEN
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

  -- B.4 FIX: Solo devolver solucionario para tests asignados
  RETURN jsonb_build_object(
    'nota',        v_nota,
    'correctas',   v_correctas,
    'total',       v_total,
    'solucionario', CASE WHEN v_es_asignado THEN v_solucionario ELSE '{}'::JSONB END
  );
END;
$$;

REVOKE ALL  ON FUNCTION public.corregir_test(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.corregir_test(UUID, JSONB) TO authenticated;

-- ------------------------------------------------------------
-- Verificación post-parche
-- ------------------------------------------------------------
-- 1. Editar un bono desde admin: debe funcionar sin errores
-- 2. Verificar que las horas del alumno se actualizan correctamente
-- 3. Intentar hacer un test general dos veces: debe rechazar la segunda
