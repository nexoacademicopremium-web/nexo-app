-- ============================================================
-- AUDITORÍA — Corrección de policies sin WITH CHECK
-- 2026-08-16
-- ============================================================

-- ------------------------------------------------------------
-- 1. Corregir tests_profesor_manage: dividir en policies separadas
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "tests_profesor_manage" ON public.tests;

CREATE POLICY "tests_profesor_select" ON public.tests
  FOR SELECT USING (creado_por = auth.uid());

CREATE POLICY "tests_profesor_insert" ON public.tests
  FOR INSERT WITH CHECK (creado_por = auth.uid());

CREATE POLICY "tests_profesor_update" ON public.tests
  FOR UPDATE USING (creado_por = auth.uid())
  WITH CHECK (creado_por = auth.uid());

CREATE POLICY "tests_profesor_delete" ON public.tests
  FOR DELETE USING (creado_por = auth.uid());

-- ------------------------------------------------------------
-- 2. Corregir sesion_temas_profesor_own: agregar WITH CHECK
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "sesion_temas_profesor_own" ON public.sesion_temas;

CREATE POLICY "sesion_temas_profesor_select" ON public.sesion_temas
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.sesiones s
      JOIN public.profesores p ON p.id = s.profesor_id
      WHERE s.id = sesion_temas.sesion_id
        AND p.usuario_id = auth.uid()
    )
  );

CREATE POLICY "sesion_temas_profesor_insert" ON public.sesion_temas
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.sesiones s
      JOIN public.profesores p ON p.id = s.profesor_id
      WHERE s.id = sesion_temas.sesion_id
        AND p.usuario_id = auth.uid()
    )
  );

CREATE POLICY "sesion_temas_profesor_update" ON public.sesion_temas
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.sesiones s
      JOIN public.profesores p ON p.id = s.profesor_id
      WHERE s.id = sesion_temas.sesion_id
        AND p.usuario_id = auth.uid()
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.sesiones s
      JOIN public.profesores p ON p.id = s.profesor_id
      WHERE s.id = sesion_temas.sesion_id
        AND p.usuario_id = auth.uid()
    )
  );

CREATE POLICY "sesion_temas_profesor_delete" ON public.sesion_temas
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.sesiones s
      JOIN public.profesores p ON p.id = s.profesor_id
      WHERE s.id = sesion_temas.sesion_id
        AND p.usuario_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- 3. Corregir calendario_alumno: agregar WITH CHECK
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "cal_alumno_own" ON public.calendario_alumno;

CREATE POLICY "cal_alumno_select" ON public.calendario_alumno
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.alumnos a WHERE a.id = calendario_alumno.alumno_id AND a.usuario_id = auth.uid())
  );

CREATE POLICY "cal_alumno_insert" ON public.calendario_alumno
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.alumnos a WHERE a.id = calendario_alumno.alumno_id AND a.usuario_id = auth.uid())
  );

CREATE POLICY "cal_alumno_update" ON public.calendario_alumno
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.alumnos a WHERE a.id = calendario_alumno.alumno_id AND a.usuario_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.alumnos a WHERE a.id = calendario_alumno.alumno_id AND a.usuario_id = auth.uid())
  );

CREATE POLICY "cal_alumno_delete" ON public.calendario_alumno
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.alumnos a WHERE a.id = calendario_alumno.alumno_id AND a.usuario_id = auth.uid())
  );

-- ------------------------------------------------------------
-- 4. Corregir calendario_profesor: agregar WITH CHECK
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "cal_profesor_own" ON public.calendario_profesor;

CREATE POLICY "cal_profesor_select" ON public.calendario_profesor
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profesores p WHERE p.id = calendario_profesor.profesor_id AND p.usuario_id = auth.uid())
  );

CREATE POLICY "cal_profesor_insert" ON public.calendario_profesor
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profesores p WHERE p.id = calendario_profesor.profesor_id AND p.usuario_id = auth.uid())
  );

CREATE POLICY "cal_profesor_update" ON public.calendario_profesor
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profesores p WHERE p.id = calendario_profesor.profesor_id AND p.usuario_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.profesores p WHERE p.id = calendario_profesor.profesor_id AND p.usuario_id = auth.uid())
  );

CREATE POLICY "cal_profesor_delete" ON public.calendario_profesor
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profesores p WHERE p.id = calendario_profesor.profesor_id AND p.usuario_id = auth.uid())
  );
