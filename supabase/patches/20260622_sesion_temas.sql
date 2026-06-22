-- Tabla para el desglose por temas del formulario nuevo de registro de sesión
-- Ejecutar desde el SQL Editor de Supabase

CREATE TABLE IF NOT EXISTS public.sesion_temas (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sesion_id                 uuid NOT NULL REFERENCES public.sesiones(id) ON DELETE CASCADE,
  asignatura                text,
  tema                      text,
  tiempo_minutos            integer DEFAULT 0,
  -- Test de inicio
  test_inicio_propuestos    integer DEFAULT 0,
  test_inicio_solo          integer DEFAULT 0,
  test_inicio_ayuda         integer DEFAULT 0,
  test_inicio_sin_resolver  integer DEFAULT 0,
  -- P1-P2: ejercicios
  tipo_ejercicios           jsonb DEFAULT '[]',
  ejercicios_propuestos     integer DEFAULT 0,
  ejercicios_solo           integer DEFAULT 0,
  ejercicios_ayuda          integer DEFAULT 0,
  ejercicios_sin_resolver   integer DEFAULT 0,
  -- P3-P6: observaciones
  donde_falla               text,
  detecta_errores           text,
  actitud_dificultad        text,
  actitud_ritmo             text,
  -- Test de cierre
  test_cierre_propuestos    integer DEFAULT 0,
  test_cierre_solo          integer DEFAULT 0,
  test_cierre_ayuda         integer DEFAULT 0,
  test_cierre_sin_resolver  integer DEFAULT 0,
  -- Nota libre
  nota_profesor             text,
  created_at                timestamptz DEFAULT now()
);

-- RLS: el profesor solo ve los temas de sus propias sesiones
ALTER TABLE public.sesion_temas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profesor ve sus sesion_temas" ON public.sesion_temas
  FOR ALL
  USING (
    sesion_id IN (
      SELECT id FROM public.sesiones
      WHERE profesor_id = (
        SELECT id FROM public.profesores WHERE usuario_id = auth.uid()
      )
    )
  );
