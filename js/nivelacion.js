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

    // De menor a mayor. `hasta` es el porcentaje máximo de ese tramo:
    // se trabaja en porcentaje para que los tramos sigan valiendo
    // aunque el test cambie de número de preguntas.
    tramos: [
      {
        nivel: 'Pre-B1',
        etiqueta: 'Elementary / Pre-Intermediate',
        hasta: 40,
        horas: '4-5 h / semana',
        consejo: 'Para construir cuanto antes una base sólida de gramática y vocabulario.',
      },
      {
        nivel: 'B1',
        etiqueta: 'Intermediate',
        hasta: 60,
        horas: '3-4 h / semana',
        consejo: 'Para afianzar la base y empezar a soltarse con textos más largos.',
      },
      {
        nivel: 'B2',
        etiqueta: 'Upper-Intermediate',
        hasta: 80,
        horas: '2-3 h / semana',
        consejo: 'Para pulir los usos avanzados y ganar naturalidad.',
      },
      {
        nivel: 'C1',
        etiqueta: 'Advanced',
        hasta: 94,
        horas: '2 h / semana',
        consejo: 'Para mantener el nivel y afinar matices y registro.',
      },
      {
        nivel: 'C2',
        etiqueta: 'Proficiency',
        hasta: 100,
        horas: '1-2 h / semana',
        consejo: 'Para conservar el nivel y no perder soltura.',
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

// preguntas: [{ id, parte, puntos, respuesta_correcta }]
// respuestas: { [preguntaId]: 'a' | 'b' | ... }
//
// Devuelve el desglose entero listo para pintar: nivel, totales, qué
// ha sacado en cada parte y en qué anda mejor y peor.
function calcularNivelacion(asignatura, preguntas, respuestas) {
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

    if (respuestas[p.id] && respuestas[p.id] === p.respuesta_correcta) {
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
  const porcentaje = total > 0 ? (puntos / total) * 100 : 0;

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
    porcentaje: Math.round(porcentaje),
    partes,
    fuertes: conPct.slice(0, 2).map(g => g.nombre),
    flojas:  conPct.slice(-2).reverse().map(g => g.nombre),
  };
}
