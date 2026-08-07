-- Expande el CHECK constraint de alumnos.nivel para incluir Primaria y Universidad
-- Antes solo aceptaba ESO y Bachillerato

-- Eliminar el constraint existente (nombre generado automáticamente por Postgres)
ALTER TABLE public.alumnos DROP CONSTRAINT IF EXISTS alumnos_nivel_check;

-- Añadir constraint expandido
ALTER TABLE public.alumnos
  ADD CONSTRAINT alumnos_nivel_check CHECK (
    nivel IS NULL OR nivel IN (
      '1PRI','2PRI','3PRI','4PRI','5PRI','6PRI',
      '1ESO','2ESO','3ESO','4ESO',
      '1BACH','2BACH',
      'UNIV'
    )
  );
