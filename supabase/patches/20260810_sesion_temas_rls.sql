-- ============================================================
-- sesion_temas: habilitar RLS + políticas
-- El admin debe poder leer todos los temas para generar informes.
-- El profesor puede insertar/leer los temas de sus propias sesiones.
-- ============================================================

-- Habilitar RLS (si no estaba activado)
ALTER TABLE public.sesion_temas ENABLE ROW LEVEL SECURITY;

-- Admin: acceso total
DROP POLICY IF EXISTS "sesion_temas_admin_all" ON public.sesion_temas;
CREATE POLICY "sesion_temas_admin_all"
ON public.sesion_temas
FOR ALL
USING (is_admin());

-- Profesor: leer y escribir los temas de sus propias sesiones
DROP POLICY IF EXISTS "sesion_temas_profesor_own" ON public.sesion_temas;
CREATE POLICY "sesion_temas_profesor_own"
ON public.sesion_temas
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.sesiones s
    JOIN public.profesores p ON p.id = s.profesor_id
    WHERE s.id = sesion_temas.sesion_id
      AND p.usuario_id = auth.uid()
  )
);

-- Alumno: solo lectura de sus propias sesiones
DROP POLICY IF EXISTS "sesion_temas_alumno_read" ON public.sesion_temas;
CREATE POLICY "sesion_temas_alumno_read"
ON public.sesion_temas
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.sesiones s
    JOIN public.alumnos a ON a.id = s.alumno_id
    WHERE s.id = sesion_temas.sesion_id
      AND a.usuario_id = auth.uid()
  )
);

-- ============================================================
-- preguntas_asignatura: lectura pública para todos los autenticados
-- ============================================================

ALTER TABLE public.preguntas_asignatura ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "preguntas_asignatura_read_all" ON public.preguntas_asignatura;
CREATE POLICY "preguntas_asignatura_read_all"
ON public.preguntas_asignatura
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "preguntas_asignatura_admin_all" ON public.preguntas_asignatura;
CREATE POLICY "preguntas_asignatura_admin_all"
ON public.preguntas_asignatura
FOR ALL
USING (is_admin());
