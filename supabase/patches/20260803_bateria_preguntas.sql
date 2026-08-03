-- ============================================================
-- Batería de preguntas dinámica por asignatura
-- Ejecutar en Supabase SQL Editor (en este orden)
-- ============================================================

-- 1. Añadir columnas a sesion_temas
ALTER TABLE public.sesion_temas
  ADD COLUMN IF NOT EXISTS respuestas_bateria JSONB,
  ADD COLUMN IF NOT EXISTS categoria_idioma   TEXT;

-- 2. Crear tabla de preguntas
CREATE TABLE IF NOT EXISTS public.preguntas_asignatura (
  id           SERIAL PRIMARY KEY,
  asignatura   TEXT        NOT NULL,  -- 'Matemáticas' | 'Física' | ... | 'Universal'
  categoria    TEXT,                  -- NULL | 'gramatica' | 'comprension'
  codigo       TEXT        NOT NULL,  -- 'U1' | 'M1' | 'G1' | ...
  orden        SMALLINT    NOT NULL,
  pregunta     TEXT        NOT NULL,
  opciones     JSONB       NOT NULL,
  es_universal BOOLEAN     NOT NULL DEFAULT FALSE
);

ALTER TABLE public.preguntas_asignatura ENABLE ROW LEVEL SECURITY;

CREATE POLICY "preguntas_asignatura_read" ON public.preguntas_asignatura
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- 3. Seed: 67 preguntas
INSERT INTO public.preguntas_asignatura
  (asignatura, categoria, codigo, orden, pregunta, opciones, es_universal)
VALUES

-- ── Bloque universal (U1–U3) ──────────────────────────────────
('Universal', NULL, 'U1', 1,
 'Comprensión general del tema trabajado',
 '["No entendido","Con dificultad","Bien","Con soltura"]', TRUE),

('Universal', NULL, 'U2', 2,
 'Autonomía resolviendo las actividades',
 '["Necesitó ayuda constante","Ayuda puntual","Resolvió solo"]', TRUE),

('Universal', NULL, 'U3', 3,
 'Actitud e implicación en la sesión',
 '["Muy implicado","Normal","Distraído","Resistente"]', TRUE),

-- ── Matemáticas (M1–M4) ───────────────────────────────────────
('Matemáticas', NULL, 'M1', 1,
 'Si falla, ¿en qué punto se atasca?',
 '["No entiende el enunciado","Entiende el enunciado pero no sabe qué método aplicar","Sabe qué hacer pero falla al ejecutarlo","Resuelve bien pero se equivoca al dar la respuesta final","No falló"]',
 FALSE),

('Matemáticas', NULL, 'M2', 2,
 'Cuando falla, ¿es un despiste puntual o algo sistemático?',
 '["Despiste puntual (lo ve si se le señala)","Error sistemático — no sabe que está mal","No aplica (no falló)"]',
 FALSE),

('Matemáticas', NULL, 'M3', 3,
 'Velocidad de cálculo/ejecución',
 '["Ágil","Normal","Lenta pero correcta","Lenta y con errores"]',
 FALSE),

('Matemáticas', NULL, 'M4', 4,
 'Aplica el procedimiento aprendido a un ejercicio nuevo (no idéntico)',
 '["Sí, sin problema","Con alguna pista","No, necesita mucho apoyo"]',
 FALSE),

-- ── Física (F1–F4) ────────────────────────────────────────────
('Física', NULL, 'F1', 1,
 'Comprende el fenómeno físico antes de aplicar fórmulas (lo explica con sus palabras)',
 '["Sí","Aplica fórmulas sin entender el porqué","Mixto"]',
 FALSE),

('Física', NULL, 'F2', 2,
 'Traduce el enunciado en datos, magnitudes y qué se pide',
 '["Autónomo","Con ayuda","No"]',
 FALSE),

('Física', NULL, 'F3', 3,
 'Ejecuta correctamente el procedimiento matemático (incluye unidades)',
 '["Sin errores","Algún error","Errores frecuentes"]',
 FALSE),

('Física', NULL, 'F4', 4,
 'Comprueba si el resultado final tiene sentido (unidades, magnitud, signo)',
 '["Sí, por iniciativa propia","Solo si se le indica","Nunca"]',
 FALSE),

-- ── Química (Q1–Q4) ───────────────────────────────────────────
('Química', NULL, 'Q1', 1,
 'Entiende qué ocurre a nivel de partículas (átomos/moléculas/iones), no solo maneja la fórmula escrita',
 '["Sí, lo explica a nivel de partículas","Solo maneja la fórmula sin explicar qué ocurre","Mixto"]',
 FALSE),

('Química', NULL, 'Q2', 2,
 'Maneja correctamente fórmulas/nomenclatura',
 '["Sin errores","Errores puntuales","Errores frecuentes"]',
 FALSE),

('Química', NULL, 'Q3', 3,
 'Resuelve problemas numéricos (estequiometría, disoluciones...) con autonomía',
 '["Sí","Con ayuda","No","N/A (no se trabajó nada numérico)"]',
 FALSE),

('Química', NULL, 'Q4', 4,
 'Relaciona el fenómeno observado/experimental con la explicación a nivel de partículas',
 '["Sí","Con ayuda","No"]',
 FALSE),

-- ── Biología (B1–B4) ──────────────────────────────────────────
('Biología', NULL, 'B1', 1,
 'Entiende el proceso/mecanismo biológico (no solo memoriza el nombre)',
 '["Sí, explica el proceso con sus palabras","Solo memoriza términos sin explicar el proceso","Mixto"]',
 FALSE),

('Biología', NULL, 'B2', 2,
 'Dominio de terminología y nomenclatura específica del tema',
 '["Sin errores","Errores puntuales","Errores frecuentes"]',
 FALSE),

('Biología', NULL, 'B3', 3,
 'Relaciona estructura y función (ej. forma de una célula/órgano con lo que hace)',
 '["Sí","Con ayuda","No"]',
 FALSE),

('Biología', NULL, 'B4', 4,
 'Aplica el concepto a un caso o ejemplo nuevo',
 '["Sí, con autonomía","Con ayuda","No"]',
 FALSE),

-- ── Historia (H1–H4) ──────────────────────────────────────────
('Historia', NULL, 'H1', 1,
 'Analiza causas y consecuencias de los hechos',
 '["Explica relaciones causa-efecto con soltura","Identifica causas pero le cuesta relacionarlas","Solo enumera hechos sin relacionarlos"]',
 FALSE),

('Historia', NULL, 'H2', 2,
 'Sitúa cronológicamente y relaciona con otros periodos/hechos',
 '["Buena","Aceptable","Floja"]',
 FALSE),

('Historia', NULL, 'H3', 3,
 'Retiene datos clave (fechas, nombres, conceptos)',
 '["Bien","Con dificultad","Mal"]',
 FALSE),

('Historia', NULL, 'H4', 4,
 'Expresión y estructura al explicar o redactar',
 '["Buena","Mejorable","Floja"]',
 FALSE),

-- ── Economía (E1–E4) ──────────────────────────────────────────
('Economía', NULL, 'E1', 1,
 'Domina los conceptos y términos teóricos del tema',
 '["Buen dominio","Conoce lo básico con lagunas","No domina los conceptos"]',
 FALSE),

('Economía', NULL, 'E2', 2,
 'Aplica la teoría a un caso o dato concreto (no solo la recita)',
 '["Aplica con soltura","Con ayuda","Solo la recita, no la aplica"]',
 FALSE),

('Economía', NULL, 'E3', 3,
 'Argumenta con cadena de razonamiento (relaciona causa-efecto entre variables)',
 '["Autónomo","Con ayuda","Da respuestas sueltas sin conectar"]',
 FALSE),

('Economía', NULL, 'E4', 4,
 'Resuelve ejercicios numéricos/gráficos',
 '["Con autonomía","Con ayuda","No","N/A"]',
 FALSE),

-- ── Filosofía (Fi1–Fi4) ───────────────────────────────────────
('Filosofía', NULL, 'Fi1', 1,
 'Identifica la tesis/idea principal del texto o argumento',
 '["Sí, con precisión","Con ayuda","No la identifica"]',
 FALSE),

('Filosofía', NULL, 'Fi2', 2,
 'Reconstruye la estructura del argumento (premisas que sostienen la conclusión)',
 '["Autónomo","Con ayuda","No distingue premisas de conclusión"]',
 FALSE),

('Filosofía', NULL, 'Fi3', 3,
 'Comprende el contexto filosófico (autor, corriente, época) y lo relaciona con el texto',
 '["Sí","Parcialmente","No"]',
 FALSE),

('Filosofía', NULL, 'Fi4', 4,
 'Argumenta y valora críticamente con postura propia razonada (no solo repite)',
 '["Sí, con argumentos propios","Repite ideas sin argumentar","No lo consigue"]',
 FALSE),

-- ── Geografía (Gg1–Gg4) ───────────────────────────────────────
('Geografía', NULL, 'Gg1', 1,
 'Interpreta y utiliza mapas, gráficos y datos geográficos',
 '["Autónomo","Con ayuda","No"]',
 FALSE),

('Geografía', NULL, 'Gg2', 2,
 'Relaciona patrones espaciales con sus causas (no solo localiza, explica el porqué)',
 '["Explica el porqué","Solo describe dónde está","No"]',
 FALSE),

('Geografía', NULL, 'Gg3', 3,
 'Relaciona factores físicos y humanos (cómo el medio influye en la actividad humana y viceversa)',
 '["Sí","Parcialmente","No"]',
 FALSE),

('Geografía', NULL, 'Gg4', 4,
 'Retiene y localiza datos clave (nombres, cifras, ubicaciones)',
 '["Bien","Con dificultad","Mal"]',
 FALSE),

-- ── Lengua Castellana — Gramática/Norma (G1–G4) ──────────────
('Lengua Castellana', 'gramatica', 'G1', 1,
 'Nivel de comprensión de la norma/estructura',
 '["Identifica los elementos correctamente","Entiende las relaciones entre ellos","Aplica de forma autónoma en casos nuevos"]',
 FALSE),

('Lengua Castellana', 'gramatica', 'G2', 2,
 'Cuando falla, ¿es porque no conoce la regla o porque le cuesta aplicarla?',
 '["No conoce la regla","La conoce pero falla al aplicarla","No falló"]',
 FALSE),

('Lengua Castellana', 'gramatica', 'G3', 3,
 'Dominio ortográfico en lo trabajado',
 '["Buen dominio","Errores puntuales","Errores frecuentes"]',
 FALSE),

('Lengua Castellana', 'gramatica', 'G4', 4,
 'Autonomía resolviendo ejercicios de aplicación',
 '["Necesitó ayuda constante","Ayuda puntual","Resolvió solo"]',
 FALSE),

-- ── Lengua Castellana — Comprensión y Expresión (C1–C4) ──────
('Lengua Castellana', 'comprension', 'C1', 1,
 'Nivel de comprensión lectora alcanzado',
 '["Literal (identifica info explícita)","Inferencial (deduce lo no explícito)","Crítico (valora y argumenta sobre el texto)"]',
 FALSE),

('Lengua Castellana', 'comprension', 'C2', 2,
 'Expresión escrita: ideas y organización',
 '["Ideas claras y bien organizadas","Ideas presentes pero mal estructuradas","Le cuesta expresar y organizar ideas por escrito"]',
 FALSE),

('Lengua Castellana', 'comprension', 'C3', 3,
 'Dominio de gramática/ortografía en la producción propia',
 '["Buen dominio","Errores puntuales","Errores frecuentes"]',
 FALSE),

('Lengua Castellana', 'comprension', 'C4', 4,
 'Análisis literario (si aplica al texto trabajado)',
 '["Autónomo","Con ayuda","No lo consigue","N/A"]',
 FALSE),

-- ── Valenciano — Gramática/Norma (idéntico a Lengua) ─────────
('Valenciano', 'gramatica', 'G1', 1,
 'Nivel de comprensión de la norma/estructura',
 '["Identifica los elementos correctamente","Entiende las relaciones entre ellos","Aplica de forma autónoma en casos nuevos"]',
 FALSE),

('Valenciano', 'gramatica', 'G2', 2,
 'Cuando falla, ¿es porque no conoce la regla o porque le cuesta aplicarla?',
 '["No conoce la regla","La conoce pero falla al aplicarla","No falló"]',
 FALSE),

('Valenciano', 'gramatica', 'G3', 3,
 'Dominio ortográfico en lo trabajado',
 '["Buen dominio","Errores puntuales","Errores frecuentes"]',
 FALSE),

('Valenciano', 'gramatica', 'G4', 4,
 'Autonomía resolviendo ejercicios de aplicación',
 '["Necesitó ayuda constante","Ayuda puntual","Resolvió solo"]',
 FALSE),

-- ── Valenciano — Comprensión y Expresión (idéntico a Lengua) ─
('Valenciano', 'comprension', 'C1', 1,
 'Nivel de comprensión lectora alcanzado',
 '["Literal (identifica info explícita)","Inferencial (deduce lo no explícito)","Crítico (valora y argumenta sobre el texto)"]',
 FALSE),

('Valenciano', 'comprension', 'C2', 2,
 'Expresión escrita: ideas y organización',
 '["Ideas claras y bien organizadas","Ideas presentes pero mal estructuradas","Le cuesta expresar y organizar ideas por escrito"]',
 FALSE),

('Valenciano', 'comprension', 'C3', 3,
 'Dominio de gramática/ortografía en la producción propia',
 '["Buen dominio","Errores puntuales","Errores frecuentes"]',
 FALSE),

('Valenciano', 'comprension', 'C4', 4,
 'Análisis literario (si aplica al texto trabajado)',
 '["Autónomo","Con ayuda","No lo consigue","N/A"]',
 FALSE),

-- ── Inglés — Gramática/Vocabulario (G1–G4) ───────────────────
('Inglés', 'gramatica', 'G1', 1,
 'Nivel de comprensión de la estructura/regla trabajada',
 '["Identifica los elementos correctamente","Entiende las relaciones entre ellos","Aplica de forma autónoma en casos nuevos"]',
 FALSE),

('Inglés', 'gramatica', 'G2', 2,
 'Cuando falla, ¿es porque no conoce la regla o porque le cuesta aplicarla?',
 '["No conoce la regla","La conoce pero falla al aplicarla","No falló"]',
 FALSE),

('Inglés', 'gramatica', 'G3', 3,
 'Dominio de vocabulario del tema',
 '["Buen dominio","Vocabulario limitado","Confunde términos con frecuencia"]',
 FALSE),

('Inglés', 'gramatica', 'G4', 4,
 'Autonomía resolviendo ejercicios de aplicación',
 '["Necesitó ayuda constante","Ayuda puntual","Resolvió solo"]',
 FALSE),

-- ── Inglés — Comprensión y Expresión escrita (C1–C4) ─────────
('Inglés', 'comprension', 'C1', 1,
 'Nivel de comprensión lectora alcanzado (reading)',
 '["Literal (identifica info explícita)","Inferencial (deduce lo no explícito)","Crítico (valora y argumenta sobre el texto)"]',
 FALSE),

('Inglés', 'comprension', 'C2', 2,
 'Expresión escrita: ideas y organización (writing)',
 '["Ideas claras y bien organizadas","Ideas presentes pero mal estructuradas","Le cuesta expresar y organizar ideas por escrito"]',
 FALSE),

('Inglés', 'comprension', 'C3', 3,
 'Dominio gramatical/ortográfico en la producción propia',
 '["Buen dominio","Errores puntuales","Errores frecuentes"]',
 FALSE),

('Inglés', 'comprension', 'C4', 4,
 'Traducción/interpretación de estructuras complejas (si aplica)',
 '["Autónoma","Con ayuda","No lo consigue","N/A"]',
 FALSE),

-- ── Francés — Gramática/Vocabulario (G1–G4) ──────────────────
('Francés', 'gramatica', 'G1', 1,
 'Nivel de comprensión de la estructura/regla trabajada',
 '["Identifica los elementos correctamente","Entiende las relaciones entre ellos","Aplica de forma autónoma en casos nuevos"]',
 FALSE),

('Francés', 'gramatica', 'G2', 2,
 'Cuando falla, ¿es porque no conoce la regla o porque le cuesta aplicarla?',
 '["No conoce la regla","La conoce pero falla al aplicarla","No falló"]',
 FALSE),

('Francés', 'gramatica', 'G3', 3,
 'Dominio de vocabulario del tema',
 '["Buen dominio","Vocabulario limitado","Confunde términos con frecuencia"]',
 FALSE),

('Francés', 'gramatica', 'G4', 4,
 'Autonomía resolviendo ejercicios de aplicación',
 '["Necesitó ayuda constante","Ayuda puntual","Resolvió solo"]',
 FALSE),

-- ── Francés — Comprensión y Expresión escrita (C1–C4) ────────
('Francés', 'comprension', 'C1', 1,
 'Nivel de comprensión lectora alcanzado (lecture)',
 '["Literal (identifica info explícita)","Inferencial (deduce lo no explícito)","Crítico (valora y argumenta sobre el texto)"]',
 FALSE),

('Francés', 'comprension', 'C2', 2,
 'Expresión escrita: ideas y organización (écriture)',
 '["Ideas claras y bien organizadas","Ideas presentes pero mal estructuradas","Le cuesta expresar y organizar ideas por escrito"]',
 FALSE),

('Francés', 'comprension', 'C3', 3,
 'Dominio gramatical/ortográfico en la producción propia',
 '["Buen dominio","Errores puntuales","Errores frecuentes"]',
 FALSE),

('Francés', 'comprension', 'C4', 4,
 'Traducción/interpretación de estructuras complejas (si aplica)',
 '["Autónoma","Con ayuda","No lo consigue","N/A"]',
 FALSE);
