// ============================================================
// NEXO ACADÉMICO — Tests de nivelación
//
// Convierte los puntos de un test en un nivel y una recomendación de
// horas semanales.
//
// De momento solo inglés. Para añadir otro idioma u otra asignatura,
// basta con otra entrada en NIVELES con sus tramos y sus partes.
//
// ⚠️ Los tramos y las horas son la parte que se ajusta con el uso:
//    están todos aquí arriba, en un sitio, para poder cambiarlos sin
//    tocar nada más.
// ============================================================

const NIVELACION = {
  ingles: {
    asignaturas: ['Inglés', 'Ingles', 'English'],

    // Las cinco partes, en el orden en que se presentan. El total de
    // puntos sale de las preguntas, no de aquí.
    partes: [
      'Grammar & Vocabulary',
      'Open Cloze',
      'Word Formation',
      'Key Word Transformation',
      'Vocabulary in Use',
    ],

    // De menor a mayor, por porcentaje de puntos acertados. Se trabaja
    // en porcentaje y no en puntos porque el test cambia de tamaño: el
    // de referencia tenía 109 preguntas y el nuevo ronda las 50.
    //
    // Tramos y textos según la especificación del 17-09-2026.
    tramos: [
      {
        nivel: 'Pre-B1',
        etiqueta: 'A2 o inferior — se recomienda una prueba de nivel más básica.',
        hasta: 39,
        horas: '4–5 h/semana',
        consejo: 'Para construir cuanto antes una base sólida de gramática y vocabulario.',
      },
      {
        nivel: 'B1',
        etiqueta: 'Usuario independiente — nivel intermedio.',
        hasta: 54,
        horas: '3–4 h/semana',
        consejo: 'Ritmo constante para consolidar el intermedio y dar el salto a B2.',
      },
      {
        nivel: 'B2',
        etiqueta: 'Usuario independiente — nivel intermedio alto.',
        hasta: 70,
        horas: '2–3 h/semana',
        consejo: 'Mantener el nivel mientras se amplía vocabulario y fluidez.',
      },
      {
        nivel: 'C1',
        etiqueta: 'Usuario competente — nivel avanzado.',
        hasta: 86,
        horas: '2 h/semana',
        consejo: 'Perfeccionamiento y preparación de examen (Advanced).',
      },
      {
        nivel: 'C2',
        etiqueta: 'Usuario competente — nivel de maestría.',
        hasta: 100,
        horas: '1–2 h/semana',
        consejo: 'Mantenimiento y matices — ya tiene un dominio muy alto.',
      },
    ],
  },
};

// ── Consultas ───────────────────────────────────────────────────

// Si la asignatura tiene test de nivelación montado, devuelve su
// configuración. Se compara sin tildes ni mayúsculas, que "Inglés" se
// escribe de varias formas.
function configNivelacion(asignatura) {
  if (!asignatura) return null;
  const limpia = (t) => t.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
  const buscada = limpia(asignatura);
  return Object.values(NIVELACION).find(c => c.asignaturas.some(a => limpia(a) === buscada)) || null;
}

function partesDeNivelacion(asignatura) {
  return configNivelacion(asignatura)?.partes || [];
}

// ── El cálculo ──────────────────────────────────────────────────

// Las de marcar se comparan tal cual. Las de escribir, ignorando
// mayúsculas, espacios de más, el punto final y el tipo de apóstrofe,
// que en el móvil es distinto del del teclado. Es la misma regla que
// aplica el servidor, para que la pantalla no diga una cosa y la
// corrección otra.
function _acierta(dada, esperada) {
  if (dada == null || esperada == null) return false;
  const limpia = (t) => String(t)
    .toLowerCase()
    .trim()
    .replace(/[\u2019\u2018\u0060\u00b4]/g, "'")
    .replace(/\s+/g, " ")
    .replace(/[.!?]+$/, "");
  const a = limpia(dada);
  return a !== "" && a === limpia(esperada);
}

// preguntas:    [{ id, parte, puntos, escribe }]
// respuestas:   { [preguntaId]: lo que contestó }
// solucionario: { [preguntaId]: lo que debía contestar }
//
// El solucionario lo devuelve el servidor al corregir: aquí no se
// sabe la respuesta correcta hasta entonces, y por eso esto se llama
// después de enviar y no antes.
//
// Devuelve el desglose entero listo para pintar: nivel, totales, qué
// ha sacado en cada parte y en qué anda mejor y peor.
function calcularNivelacion(asignatura, preguntas, respuestas, solucionario) {
  const config = configNivelacion(asignatura);
  if (!config) return null;

  const porParte = config.partes.map(nombre => ({
    nombre, puntos: 0, total: 0, correctas: 0, preguntas: 0,
  }));
  // Las preguntas sin parte asignada van juntas al final, para que no
  // se pierdan del recuento.
  const sueltas = { nombre: 'Otras', puntos: 0, total: 0, correctas: 0, preguntas: 0 };

  for (const p of preguntas) {
    const vale = Number(p.puntos) || 1;
    const grupo = porParte.find(g => g.nombre === p.parte) || sueltas;
    grupo.total     += vale;
    grupo.preguntas += 1;

    if (_acierta(respuestas[p.id], (solucionario || {})[p.id])) {
      grupo.puntos    += vale;
      grupo.correctas += 1;
    }
  }

  const partes = porParte.filter(g => g.preguntas > 0);
  if (sueltas.preguntas > 0) partes.push(sueltas);

  const puntos    = partes.reduce((s, g) => s + g.puntos, 0);
  const total     = partes.reduce((s, g) => s + g.total, 0);
  const correctas = partes.reduce((s, g) => s + g.correctas, 0);
  const preguntasN = partes.reduce((s, g) => s + g.preguntas, 0);
  // Se redondea ANTES de buscar el tramo, no después. Si no, un 70,09 %
  // se enseña como 70 % pero se clasifica como si pasara de 70, y el
  // alumno ve un nivel que no cuadra con el porcentaje que tiene
  // delante.
  const porcentaje = total > 0 ? Math.round((puntos / total) * 100) : 0;

  const tramo = config.tramos.find(t => porcentaje <= t.hasta)
             || config.tramos[config.tramos.length - 1];

  // Fuertes y flojas se miden por el porcentaje de cada parte, no por
  // los puntos: una parte de 60 puntos siempre sumaría más que una de
  // 10 y no querría decir que se lleve mejor.
  const conPct = partes
    .filter(g => g.total > 0)
    .map(g => ({ ...g, pct: (g.puntos / g.total) * 100 }))
    .sort((a, b) => b.pct - a.pct);

  return {
    nivel:      tramo.nivel,
    etiqueta:   tramo.etiqueta,
    horas:      tramo.horas,
    consejo:    tramo.consejo,
    puntos,
    total,
    correctas,
    preguntas:  preguntasN,
    porcentaje,
    partes,
    fuertes: conPct.slice(0, 2).map(g => g.nombre),
    flojas:  conPct.slice(-2).reverse().map(g => g.nombre),
  };
}
