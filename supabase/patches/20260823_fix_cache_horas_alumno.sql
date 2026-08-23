-- ============================================================
-- El contador de horas del alumno se quedaba a cero
-- 2026-08-23
--
-- SÍNTOMA: un alumno con un bono activo de 11 horas veía "0 horas
-- restantes" en su panel. Las horas no se habían perdido —el bono las
-- conservaba— pero el contador que se muestra decía cero.
--
-- CAUSA: hay dos sitios donde se guarda lo mismo. La verdad está en
-- bonos.horas_restantes; alumnos.horas_bono_restantes es solo una copia
-- rápida para pintarla en pantalla. Y esa copia se actualizaba restando
-- sobre sí misma:
--
--     SET horas_bono_restantes = GREATEST(0, horas_bono_restantes - v_remaining)
--
-- recalcular_bonos_alumno pone esa copia a cero antes de reproducir las
-- sesiones. Al reproducirlas, la resta hacía 0 - 1 = 0, y la copia ya no
-- se recuperaba nunca. Por eso "recalcular" —que se usa justamente para
-- arreglar descuadres— los provocaba.
--
-- Casos observados:
--   · alumno con bono y sin sesiones  -> copia a 0, bono intacto
--   · alumno con bono y una sesión    -> copia a 0, bono intacto
--   · alumno cuyo bono se agotó       -> correcto, porque esa rama
--     asignaba el valor en vez de restarlo
--
-- ARREGLO: la copia deja de calcularse a mano. Se sincroniza siempre
-- desde el bono activo, que es la fuente de verdad.
-- ============================================================


-- ------------------------------------------------------------
-- Pone el contador del alumno igual a su bono activo.
-- Si no tiene ninguno activo, queda a cero, que es lo correcto.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._sincronizar_horas_alumno(p_alumno_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Subconsultas escalares: si no hay bono activo devuelven NULL y el
  -- COALESCE lo deja en cero, que es justo lo que toca.
  UPDATE public.alumnos
  SET horas_bono_total = COALESCE((
        SELECT horas_contratadas FROM public.bonos
        WHERE alumno_id = p_alumno_id AND estado = 'activo'
        ORDER BY COALESCE(fecha_pago, created_at) ASC
        LIMIT 1), 0),
      horas_bono_restantes = COALESCE((
        SELECT horas_restantes FROM public.bonos
        WHERE alumno_id = p_alumno_id AND estado = 'activo'
        ORDER BY COALESCE(fecha_pago, created_at) ASC
        LIMIT 1), 0)
  WHERE id = p_alumno_id;
END;
$$;


-- ------------------------------------------------------------
-- _consumir_horas_sesion — misma lógica, pero el contador se
-- sincroniza desde el bono en vez de restarse sobre sí mismo.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._consumir_horas_sesion(
  p_alumno_id  UUID,
  p_duracion_h NUMERIC,
  p_fecha_ts   TIMESTAMPTZ DEFAULT NOW()
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_activo    public.bonos%ROWTYPE;
  v_deuda     NUMERIC;
  v_net       NUMERIC;
  v_remaining NUMERIC;
BEGIN
  v_remaining := p_duracion_h;

  LOOP
    -- FOR UPDATE: bloquea el bono activo mientras esta transacción trabaja
    SELECT * INTO v_activo
    FROM public.bonos
    WHERE alumno_id = p_alumno_id AND estado = 'activo'
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
      -- Sin bono activo: intentar activar el primero en espera
      SELECT * INTO v_activo
      FROM public.bonos
      WHERE alumno_id = p_alumno_id AND estado = 'en_espera'
      ORDER BY fecha_pago ASC NULLS LAST, created_at ASC
      LIMIT 1
      FOR UPDATE;

      IF NOT FOUND THEN
        -- Sin bonos disponibles: acumular deuda
        UPDATE public.alumnos
        SET horas_deuda = COALESCE(horas_deuda, 0) + v_remaining
        WHERE id = p_alumno_id;
        PERFORM public._sincronizar_horas_alumno(p_alumno_id);
        RETURN;
      END IF;

      SELECT COALESCE(horas_deuda, 0) INTO v_deuda
      FROM public.alumnos WHERE id = p_alumno_id;
      v_net := GREATEST(0, v_activo.horas_contratadas - v_deuda);

      UPDATE public.bonos
      SET estado           = CASE WHEN v_net = 0 THEN 'agotado' ELSE 'activo' END,
          horas_consumidas = LEAST(v_activo.horas_contratadas, v_deuda),
          horas_restantes  = v_net,
          agotado_at       = CASE WHEN v_net = 0 THEN COALESCE(agotado_at, p_fecha_ts) ELSE NULL END
      WHERE id = v_activo.id;

      UPDATE public.alumnos
      SET horas_deuda = GREATEST(0, v_deuda - v_activo.horas_contratadas)
      WHERE id = p_alumno_id;
      PERFORM public._sincronizar_horas_alumno(p_alumno_id);

      IF v_net = 0 THEN
        CONTINUE;
      END IF;

      SELECT * INTO v_activo FROM public.bonos WHERE id = v_activo.id;
    END IF;

    IF v_remaining <= v_activo.horas_restantes THEN
      UPDATE public.bonos
      SET horas_consumidas = horas_consumidas + v_remaining,
          horas_restantes  = horas_restantes  - v_remaining
      WHERE id = v_activo.id;

      IF v_activo.horas_restantes - v_remaining = 0 THEN
        PERFORM public._activar_siguiente_bono(p_alumno_id, p_fecha_ts);
      END IF;

      -- El contador se toma del bono, ya actualizado. Antes se restaba
      -- sobre sí mismo y por eso se quedaba clavado en cero.
      PERFORM public._sincronizar_horas_alumno(p_alumno_id);
      RETURN;

    ELSE
      UPDATE public.bonos
      SET estado           = 'agotado',
          horas_consumidas = horas_contratadas,
          horas_restantes  = 0,
          agotado_at       = COALESCE(agotado_at, p_fecha_ts)
      WHERE id = v_activo.id;

      v_remaining := v_remaining - v_activo.horas_restantes;
    END IF;
  END LOOP;
END;
$$;


-- ------------------------------------------------------------
-- recalcular_bonos_alumno — sincroniza el contador al terminar,
-- también cuando el alumno no tiene ninguna sesión confirmada.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalcular_bonos_alumno(p_alumno_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sesion     RECORD;
  v_bono_row   RECORD;
  v_bono_pre   public.bonos%ROWTYPE;
  v_primera    BOOLEAN := TRUE;
  v_duracion_h NUMERIC;
  v_deuda      NUMERIC;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo administradores pueden recalcular bonos';
  END IF;

  PERFORM 1 FROM public.alumnos WHERE id = p_alumno_id FOR UPDATE;
  PERFORM 1 FROM public.bonos   WHERE alumno_id = p_alumno_id FOR UPDATE;

  -- 1. Resetear todos los bonos en orden FIFO
  FOR v_bono_row IN
    SELECT id, horas_contratadas
    FROM public.bonos
    WHERE alumno_id = p_alumno_id
    ORDER BY COALESCE(fecha_pago, created_at) ASC, id ASC
  LOOP
    UPDATE public.bonos
    SET horas_consumidas = 0,
        horas_restantes  = CASE WHEN v_primera THEN v_bono_row.horas_contratadas ELSE 0 END,
        estado           = CASE WHEN v_primera THEN 'activo' ELSE 'en_espera' END,
        agotado_at       = NULL
    WHERE id = v_bono_row.id;
    v_primera := FALSE;
  END LOOP;

  -- 2. Resetear la deuda y sincronizar el contador con el bono activo.
  --    Antes se ponía el contador a cero y se esperaba a que las
  --    sesiones lo reconstruyeran: si no había sesiones, se quedaba a
  --    cero para siempre.
  UPDATE public.alumnos SET horas_deuda = 0 WHERE id = p_alumno_id;
  PERFORM public._sincronizar_horas_alumno(p_alumno_id);

  -- 3. Reproducir sesiones confirmadas en orden cronológico
  FOR v_sesion IN
    SELECT id, duracion_minutos,
           COALESCE(confirmada_at, registrada_at, NOW()) AS fecha_ts
    FROM public.sesiones
    WHERE alumno_id = p_alumno_id AND estado = 'confirmada'
    ORDER BY COALESCE(confirmada_at, registrada_at) ASC, id ASC
  LOOP
    v_duracion_h := v_sesion.duracion_minutos / 60.0;

    SELECT * INTO v_bono_pre FROM public.bonos
    WHERE alumno_id = p_alumno_id AND estado = 'activo' LIMIT 1;
    IF NOT FOUND THEN
      SELECT * INTO v_bono_pre FROM public.bonos
      WHERE alumno_id = p_alumno_id AND estado = 'en_espera'
      ORDER BY fecha_pago ASC NULLS LAST, created_at ASC LIMIT 1;
    END IF;

    IF FOUND THEN
      IF v_bono_pre.estado = 'activo' THEN
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, v_bono_pre.horas_restantes)
        WHERE id = v_sesion.id;
      ELSE
        SELECT COALESCE(horas_deuda, 0) INTO v_deuda FROM public.alumnos WHERE id = p_alumno_id;
        UPDATE public.sesiones
        SET bono_id = v_bono_pre.id,
            horas_deducidas = LEAST(v_duracion_h, GREATEST(0, v_bono_pre.horas_contratadas - v_deuda))
        WHERE id = v_sesion.id;
      END IF;
    ELSE
      UPDATE public.sesiones SET bono_id = NULL, horas_deducidas = NULL WHERE id = v_sesion.id;
    END IF;

    PERFORM public._consumir_horas_sesion(p_alumno_id, v_duracion_h, v_sesion.fecha_ts);
  END LOOP;

  -- 4. Última sincronización, por si el bucle no llegó a ejecutarse.
  PERFORM public._sincronizar_horas_alumno(p_alumno_id);
END;
$$;


GRANT EXECUTE ON FUNCTION public.recalcular_bonos_alumno(UUID) TO authenticated;
REVOKE ALL ON FUNCTION public._sincronizar_horas_alumno(UUID) FROM PUBLIC, anon;


-- ============================================================
-- Reparar los alumnos que ya están descuadrados
-- ============================================================
DO $$
DECLARE
  v_alumno RECORD;
BEGIN
  FOR v_alumno IN SELECT id FROM public.alumnos LOOP
    PERFORM public._sincronizar_horas_alumno(v_alumno.id);
  END LOOP;
END $$;


-- Comprobación: no debe devolver ninguna fila.
-- SELECT u.nombre, a.horas_bono_restantes AS contador,
--        COALESCE(SUM(b.horas_restantes), 0) AS bonos
-- FROM alumnos a
-- JOIN usuarios u ON u.id = a.usuario_id
-- LEFT JOIN bonos b ON b.alumno_id = a.id AND b.estado = 'activo'
-- GROUP BY a.id, u.nombre, a.horas_bono_restantes
-- HAVING ROUND(a.horas_bono_restantes - COALESCE(SUM(b.horas_restantes),0), 2) <> 0;
