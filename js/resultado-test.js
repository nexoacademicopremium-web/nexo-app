// ============================================================
// NEXO ACADÉMICO — Detalle de un test corregido
//
// Lo que contestó el alumno, pregunta por pregunta, con lo que era
// correcto al lado. Si el test era de nivelación, encima va el nivel
// que le salió y el reparto por partes.
//
// Lo usan el panel de administración y el del profesor: los dos tienen
// que ver exactamente lo mismo, o al hablar del alumno estarían mirando
// cosas distintas.
// ============================================================

// Trae todo lo que hace falta para pintar el detalle.
async function cargarResultadoTest(testId, alumnoId) {
  const [{ data: test }, { data: preguntas }, { data: resultado }] = await Promise.all([
    db.from('tests')
      .select('id,titulo,asignatura,nivel,tipo,alumno_id')
      .eq('id', testId).single(),
    db.from('preguntas_test')
      .select('id,enunciado,opcion_a,opcion_b,opcion_c,opcion_d,respuesta_correcta,respuestas_validas,parte,puntos,orden')
      .eq('test_id', testId).order('orden'),
    db.from('resultados_test')
      .select('respuestas,nota,detalle,completado_at')
      .eq('test_id', testId).eq('alumno_id', alumnoId).maybeSingle(),
  ]);

  return { test, preguntas: preguntas || [], resultado };
}

// Misma regla que el servidor al corregir: sin mayúsculas, sin espacios
// de más, sin el punto final y con el apóstrofe del móvil igualado al
// del teclado.
function _mismaRespuesta(dada, esperada) {
  if (dada == null || esperada == null) return false;
  const limpia = (t) => String(t)
    .toLowerCase()
    .trim()
    .replace(/[’‘`´]/g, "'")
    .replace(/\s+/g, ' ')
    .replace(/[.!?]+$/, '');
  const a = limpia(dada);
  return a !== '' && a === limpia(esperada);
}

// ¿Acertó esta pregunta? Las de escribir admiten varias formas.
function _acertoPregunta(p, dada) {
  if (p.respuestas_validas && p.respuestas_validas.length) {
    return p.respuestas_validas.some(v => _mismaRespuesta(dada, v));
  }
  return dada === p.respuesta_correcta;
}

// El HTML del detalle entero.
function pintarResultadoTest({ test, preguntas, resultado }) {
  if (!resultado) {
    return '<div class="empty-state" style="padding:26px">'
         + '<i class="ti ti-hourglass"></i><p>Todavía no lo ha hecho</p></div>';
  }

  const respuestas = resultado.respuestas || {};
  const d = resultado.detalle;

  // ── Cabecera ──────────────────────────────────────────────
  let cabecera;
  if (d && d.nivel) {
    // Nivelación: lo que importa es el nivel, no la nota.
    const partes = (d.partes || []).map(g => {
      const pct = g.total > 0 ? (g.puntos / g.total) * 100 : 0;
      return `<div style="padding:8px 0;border-bottom:.5px solid var(--border2)">
        <div style="display:flex;justify-content:space-between;gap:10px;font-size:12.5px">
          <span style="color:var(--soft)">${escHTML(g.nombre)}</span>
          <b style="color:#fff;white-space:nowrap">${g.puntos}/${g.total}</b>
        </div>
        <div style="height:3px;background:var(--dark);border-radius:2px;margin-top:5px;overflow:hidden">
          <div style="height:100%;width:${pct.toFixed(0)}%;background:var(--blue)"></div>
        </div>
      </div>`;
    }).join('');

    cabecera = `
      <div style="background:linear-gradient(135deg,#1e2a45,#2a3854);border-radius:13px;padding:20px;text-align:center;margin-bottom:14px">
        <div style="color:#a8c8f0;font-size:10px;letter-spacing:.14em;text-transform:uppercase;font-weight:700">Nivel</div>
        <div style="color:#fff;font-size:34px;font-weight:800;line-height:1.15;margin:4px 0 2px">${escHTML(d.nivel)}</div>
        <div style="color:#c9d9ef;font-size:12.5px">${escHTML(d.etiqueta || '')}</div>
        <div style="color:#fff;font-size:12px;margin-top:10px;opacity:.9">
          ${d.puntos}/${d.total} puntos · ${d.porcentaje}% · ${d.correctas}/${d.preguntas} correctas
        </div>
      </div>
      <div style="background:var(--surface);border:.5px solid var(--border);border-radius:11px;padding:13px 15px;margin-bottom:14px;font-size:12.5px;color:var(--soft);line-height:1.6">
        <b style="color:#fff">${escHTML(d.horas || '')}</b> — ${escHTML(d.consejo || '')}
      </div>
      ${partes ? `<div style="background:var(--surface);border:.5px solid var(--border);border-radius:11px;padding:13px 15px 4px;margin-bottom:14px">
        <div style="color:var(--blue);font-size:10px;letter-spacing:.1em;text-transform:uppercase;font-weight:700;margin-bottom:4px">Por partes</div>
        ${partes}
      </div>` : ''}`;
  } else {
    const nota = Number(resultado.nota) || 0;
    const color = nota >= 5 ? 'var(--green)' : 'var(--red)';
    cabecera = `
      <div style="background:var(--surface);border:.5px solid var(--border);border-radius:13px;padding:20px;text-align:center;margin-bottom:14px">
        <div style="color:${color};font-size:40px;font-weight:800;line-height:1">${nota}</div>
        <div style="color:var(--muted);font-size:11px;margin-top:4px">sobre 10</div>
      </div>`;
  }

  // ── Pregunta por pregunta ─────────────────────────────────
  let parteActual = null;
  const cuerpo = preguntas.map((p, i) => {
    let separador = '';
    if (p.parte && p.parte !== parteActual) {
      parteActual = p.parte;
      separador = `<div style="margin:18px 0 10px;padding-bottom:7px;border-bottom:1px solid var(--border)">
        <span style="color:var(--blue);font-size:10.5px;letter-spacing:.12em;text-transform:uppercase;font-weight:700">
          ${escHTML(p.parte)}</span></div>`;
    }

    const dada     = respuestas[p.id];
    const acierta  = _acertoPregunta(p, dada);
    const esEscrita = !!(p.respuestas_validas && p.respuestas_validas.length);

    // Lo que contestó y lo que era, en el mismo idioma: si es de
    // marcar, se enseña el texto de la opción, no la letra suelta.
    const texto = (v) => {
      if (v == null || v === '') return null;
      if (esEscrita) return String(v);
      const op = p['opcion_' + v];
      return op ? `${String(v).toUpperCase()}) ${op}` : String(v);
    };

    const suya     = texto(dada);
    const correcta = esEscrita ? p.respuestas_validas[0] : texto(p.respuesta_correcta);

    return `${separador}
      <div style="background:var(--dark);border:.5px solid var(--border);border-left:3px solid ${acierta ? 'var(--green)' : 'var(--red)'};border-radius:9px;padding:12px 14px;margin-bottom:9px">
        <div style="display:flex;gap:9px;align-items:flex-start;margin-bottom:9px">
          <i class="ti ti-${acierta ? 'check' : 'x'}" style="color:${acierta ? 'var(--green)' : 'var(--red)'};font-size:15px;flex-shrink:0;margin-top:2px"></i>
          <div style="color:#fff;font-size:12.5px;line-height:1.5;white-space:pre-line;min-width:0">${i + 1}. ${escHTML(p.enunciado)}</div>
        </div>
        <div style="padding-left:24px;font-size:12px;line-height:1.7">
          <div style="color:${acierta ? 'var(--green)' : 'var(--red)'}">
            Contestó: <b>${suya ? escHTML(suya) : '— en blanco —'}</b>
          </div>
          ${acierta ? '' : `<div style="color:var(--soft)">Correcta: <b>${escHTML(correcta || '—')}</b>${
            esEscrita && p.respuestas_validas.length > 1
              ? `<span style="color:var(--muted);font-size:11px"> (también valía: ${escHTML(p.respuestas_validas.slice(1).join(', '))})</span>`
              : ''}</div>`}
        </div>
      </div>`;
  }).join('');

  const fallos = preguntas.filter(p => !_acertoPregunta(p, respuestas[p.id])).length;

  return `${cabecera}
    <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;margin:18px 0 12px;flex-wrap:wrap">
      <span style="color:var(--soft);font-size:13px;font-weight:600">Respuestas</span>
      <span style="color:var(--muted);font-size:12px">
        ${fallos} ${fallos === 1 ? 'fallo' : 'fallos'} de ${preguntas.length}
      </span>
    </div>
    ${cuerpo}`;
}
