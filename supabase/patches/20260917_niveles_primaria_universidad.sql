-- ============================================================
-- Admitir Primaria y Universidad en material y en profesores
--
-- Los desplegables ya los ofrecen, pero estas dos tablas seguían
-- aceptando solo de 1.º ESO a 2.º Bachillerato: al guardar un material
-- de Primaria o un profesor que llega a Universidad, la base de datos
-- lo rechazaba.
--
-- La tabla de alumnos ya se amplió en su día (patch 20260807).
--
-- Pegar en el editor SQL de Supabase. Es repetible.
-- ============================================================

-- Material: además de los cursos, mantiene 'todos' para lo que vale
-- para cualquiera.
ALTER TABLE public.material DROP CONSTRAINT IF EXISTS material_nivel_check;

ALTER TABLE public.material
  ADD CONSTRAINT material_nivel_check CHECK (
    nivel IS NULL OR nivel IN (
      '1PRI','2PRI','3PRI','4PRI','5PRI','6PRI',
      '1ESO','2ESO','3ESO','4ESO',
      '1BACH','2BACH',
      'UNIV',
      'todos'
    )
  );

-- Profesores: hasta qué curso puede dar clase.
ALTER TABLE public.profesores DROP CONSTRAINT IF EXISTS profesores_nivel_max_check;

ALTER TABLE public.profesores
  ADD CONSTRAINT profesores_nivel_max_check CHECK (
    nivel_max IS NULL OR nivel_max IN (
      '1PRI','2PRI','3PRI','4PRI','5PRI','6PRI',
      '1ESO','2ESO','3ESO','4ESO',
      '1BACH','2BACH',
      'UNIV'
    )
  );

-- Comprobación: las dos deben salir con los cursos nuevos dentro.
SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conname IN ('material_nivel_check', 'profesores_nivel_max_check');
