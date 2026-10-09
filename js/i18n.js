// ============================================================
// NEXO ACADÉMICO — Idiomas
//
// El castellano es el idioma base: si a una traducción le falta una
// frase, se muestra la española en vez de una clave suelta o un hueco.
//
// En el HTML:   <span data-i18n="menu.inicio">Inicio</span>
// En atributos: <input data-i18n-ph="buscar.alumno" placeholder="...">
// En el JS:     t('avisos.guardado')
// Con valores:  t('sesiones.pendientes', { n: 3 })
// ============================================================

// Sin bandera: una bandera marca un país, no un idioma (el inglés no
// es solo de Reino Unido), y además es lo que hacía el selector
// parecer un selector de "portal de vuelos" en vez de una app seria.
const IDIOMAS = {
  es: { nombre: 'Español',  sigla: 'ES' },
  en: { nombre: 'English',  sigla: 'EN' },
  ru: { nombre: 'Русский',  sigla: 'RU' },
};

const IDIOMA_POR_DEFECTO = 'es';
const CLAVE_IDIOMA = 'nexo_idioma';

let _idioma = IDIOMA_POR_DEFECTO;
let _tabla  = {};

// ── Consulta ────────────────────────────────────────────────────

function idiomaActual() {
  return _idioma;
}

// Devuelve la frase traducida. Si no existe, cae al castellano; y si
// tampoco está ahí, devuelve la propia clave, que hace evidente el
// hueco al probar en vez de dejar la pantalla en blanco.
function t(clave, valores) {
  let frase = (_tabla[_idioma] && _tabla[_idioma][clave])
           || (_tabla.es && _tabla.es[clave])
           || clave;

  if (valores) {
    for (const k of Object.keys(valores)) {
      frase = frase.replace(new RegExp('\\{' + k + '\\}', 'g'), valores[k]);
    }
  }
  return frase;
}

// Plural sencillo: t2('clase', n) -> "clase" o "clases"
function tp(claveSingular, clavePlural, n, valores) {
  return t(n === 1 ? claveSingular : clavePlural, { ...(valores || {}), n });
}

// ── Aplicación sobre el documento ───────────────────────────────

function aplicarIdioma() {
  document.documentElement.lang = _idioma;

  document.querySelectorAll('[data-i18n]').forEach(el => {
    const clave = el.getAttribute('data-i18n');
    const traducido = t(clave);
    // Solo se toca el texto: así no se pierden los iconos ni los
    // contadores que viven dentro del mismo elemento.
    const nodo = [...el.childNodes].find(n => n.nodeType === 3 && n.textContent.trim());
    if (nodo) nodo.textContent = (nodo.textContent.startsWith(' ') ? ' ' : '') + traducido;
    else el.textContent = traducido;
  });

  const atributos = { ph: 'placeholder', title: 'title', alt: 'alt', aria: 'aria-label' };
  for (const [corto, real] of Object.entries(atributos)) {
    document.querySelectorAll('[data-i18n-' + corto + ']').forEach(el => {
      el.setAttribute(real, t(el.getAttribute('data-i18n-' + corto)));
    });
  }

  // Avisa a quien necesite repintar lo que genera por JavaScript.
  document.dispatchEvent(new CustomEvent('idiomacambiado', { detail: { idioma: _idioma } }));
}

// ── Cambio de idioma ────────────────────────────────────────────

async function cambiarIdioma(codigo) {
  if (!IDIOMAS[codigo]) return false;
  _idioma = codigo;
  localStorage.setItem(CLAVE_IDIOMA, codigo);
  aplicarIdioma();

  // Se guarda también en el perfil, para que el idioma acompañe a la
  // persona aunque entre desde otro dispositivo.
  try {
    const { data: { user } } = await db.auth.getUser();
    if (user) await db.from('usuarios').update({ idioma: codigo }).eq('id', user.id);
  } catch (e) {
    console.warn('No se pudo guardar el idioma en el perfil:', e);
  }
  return true;
}

// ── Arranque ────────────────────────────────────────────────────

function registrarTraducciones(codigo, tabla) {
  _tabla[codigo] = Object.assign(_tabla[codigo] || {}, tabla);
}

// Orden de preferencia: lo guardado en este navegador, luego el perfil,
// luego el idioma del navegador, y si nada encaja, castellano.
async function iniciarIdioma() {
  let elegido = localStorage.getItem(CLAVE_IDIOMA);

  if (!elegido) {
    try {
      const { data: { user } } = await db.auth.getUser();
      if (user) {
        const { data } = await db.from('usuarios').select('idioma').eq('id', user.id).single();
        if (data?.idioma && IDIOMAS[data.idioma]) elegido = data.idioma;
      }
    } catch { /* sin sesión todavía */ }
  }

  if (!elegido) {
    const delNavegador = (navigator.language || '').slice(0, 2).toLowerCase();
    if (IDIOMAS[delNavegador]) elegido = delNavegador;
  }

  _idioma = IDIOMAS[elegido] ? elegido : IDIOMA_POR_DEFECTO;
  aplicarIdioma();
  return _idioma;
}

// ── Selector para el menú ───────────────────────────────────────
//
// Botón minimalista (icono + siglas, sin banderas) que al pulsarlo
// abre un menú flotante con el nombre de cada idioma. El menú se
// monta una sola vez en <body> con position:fixed y se coloca con
// coordenadas calculadas en cada apertura — así nunca lo recorta un
// contenedor con overflow (el sidebar, una cabecera con scroll...),
// que es justo lo que pasaba con la versión anterior en el móvil y
// en el menú lateral.
//
// Se guarda con qué forma se montó cada selector, porque al cambiar
// de idioma se repintan todos a la vez y cada cual debe volver como era.

const _selectoresMontados = new Map();
const _ID_ESTILOS = 'nexo-idioma-css';
const _ID_PANEL   = 'nexo-idioma-panel-global';
let _idiomaTriggerAbierto = null; // el <button> que abrió el panel, o null

function _inyectarEstilos() {
  if (document.getElementById(_ID_ESTILOS)) return;
  const s = document.createElement('style');
  s.id = _ID_ESTILOS;
  s.textContent = `
    .nexo-idioma-trigger{display:inline-flex;align-items:center;gap:6px;
      background:transparent;border:.5px solid var(--border2,#1a2a4a);border-radius:7px;
      padding:6px 10px;cursor:pointer;font-family:inherit;color:var(--soft,#a8c8f0);
      font-size:12px;font-weight:500;line-height:1;transition:border-color .15s,color .15s}
    .nexo-idioma-trigger:hover{border-color:var(--blue,#6eaef0);color:var(--txt,#e0eaf8)}
    .nexo-idioma-trigger .ti-language{font-size:14px;color:var(--muted,#4a6080)}
    .nexo-idioma-trigger .ti-chevron-down{font-size:11px;color:var(--muted,#4a6080);
      transition:transform .15s}
    .nexo-idioma-trigger[aria-expanded="true"]{border-color:var(--blue,#6eaef0);color:var(--txt,#e0eaf8)}
    .nexo-idioma-trigger[aria-expanded="true"] .ti-chevron-down{transform:rotate(180deg)}

    /* Compacto: pastilla pequeña y redondeada, para una esquina */
    .nexo-idioma-trigger.compacto{padding:4px 9px;gap:4px;font-size:10.5px;
      font-weight:600;letter-spacing:.02em;border-radius:20px}
    .nexo-idioma-trigger.compacto .ti-language{font-size:12px}

    #${_ID_PANEL}{position:fixed;min-width:150px;max-width:calc(100vw - 16px);
      background:var(--surface,#0a1530);border:.5px solid var(--border,#1a2a4a);
      border-radius:11px;padding:5px;box-shadow:0 16px 36px rgba(0,0,0,.5);z-index:1000;
      display:none;flex-direction:column;gap:1px}
    #${_ID_PANEL}.open{display:flex}

    .nexo-idioma-opt{display:flex;align-items:center;gap:9px;background:transparent;
      border:none;border-radius:7px;padding:9px 10px;cursor:pointer;font-family:inherit;
      color:var(--txt,#e0eaf8);font-size:13px;font-weight:450;text-align:left;width:100%}
    .nexo-idioma-opt .ti-check{margin-left:auto;color:var(--blue,#6eaef0);
      font-size:14px;opacity:0;flex-shrink:0}
    .nexo-idioma-opt[aria-selected="true"]{color:var(--soft,#a8c8f0);font-weight:600}
    .nexo-idioma-opt[aria-selected="true"] .ti-check{opacity:1}
    @media(hover:hover){
      .nexo-idioma-opt:hover{background:var(--border2,#0f1f35)}
    }`;
  document.head.appendChild(s);
}

// El panel es uno solo para toda la página — se reutiliza y se
// reposiciona, en vez de tener una copia por cada botón montado.
function _panelIdioma() {
  let panel = document.getElementById(_ID_PANEL);
  if (panel) return panel;
  panel = document.createElement('div');
  panel.id = _ID_PANEL;
  panel.setAttribute('role', 'listbox');
  document.body.appendChild(panel);

  document.addEventListener('click', e => {
    if (!panel.classList.contains('open')) return;
    if (panel.contains(e.target)) return;
    if (_idiomaTriggerAbierto && _idiomaTriggerAbierto.contains(e.target)) return;
    _cerrarPanelIdioma();
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') _cerrarPanelIdioma();
  });
  // Un selector abierto no puede quedarse "flotando" en el sitio
  // antiguo si la página se desplaza o cambia de tamaño (p. ej. al
  // girar el móvil o al abrirse el teclado).
  window.addEventListener('scroll', () => _cerrarPanelIdioma(), true);
  window.addEventListener('resize', () => _cerrarPanelIdioma());

  return panel;
}

function _cerrarPanelIdioma() {
  const panel = document.getElementById(_ID_PANEL);
  if (panel) panel.classList.remove('open');
  if (_idiomaTriggerAbierto) _idiomaTriggerAbierto.setAttribute('aria-expanded', 'false');
  _idiomaTriggerAbierto = null;
}

function _abrirPanelIdioma(trigger) {
  const panel = _panelIdioma();

  panel.innerHTML = Object.entries(IDIOMAS).map(([cod, info]) => {
    const activo = cod === _idioma;
    return `<button type="button" class="nexo-idioma-opt" data-idioma="${cod}" role="option"
              aria-selected="${activo}">
              <span>${info.nombre}</span>
              <i class="ti ti-check" aria-hidden="true"></i>
            </button>`;
  }).join('');

  panel.querySelectorAll('.nexo-idioma-opt').forEach(btn => {
    btn.onclick = async e => {
      e.stopPropagation();
      _cerrarPanelIdioma();
      if (btn.getAttribute('aria-selected') === 'true') return;
      await cambiarIdioma(btn.dataset.idioma);
      // Se repintan todos los botones montados: puede haber uno en el
      // menú lateral y otro en la esquina de la portada.
      _selectoresMontados.forEach((_, id) => montarSelectorIdioma(id));
    };
  });

  panel.classList.add('open');
  _idiomaTriggerAbierto = trigger;
  trigger.setAttribute('aria-expanded', 'true');

  // Posición: pegado al botón, pero sin salirse nunca de la pantalla
  // — ni por la derecha ni por abajo. Es justo lo que fallaba antes
  // en el móvil, donde "a la derecha del botón" podía caer fuera.
  const r = trigger.getBoundingClientRect();
  const vw = document.documentElement.clientWidth;
  const vh = document.documentElement.clientHeight;
  const ph = panel.offsetHeight;
  const pw = panel.offsetWidth;
  const margen = 8;

  let left = r.right - pw;           // alineado por la derecha del botón…
  left = Math.max(margen, Math.min(left, vw - pw - margen)); // …sin salirse

  let top = r.bottom + 6;
  const cabeAbajo = top + ph <= vh - margen;
  if (!cabeAbajo) top = Math.max(margen, r.top - 6 - ph);    // se abre hacia arriba

  panel.style.left = `${left}px`;
  panel.style.top  = `${top}px`;
}

function montarSelectorIdioma(idContenedor, opciones) {
  const opc = opciones || _selectoresMontados.get(idContenedor) || {};
  _selectoresMontados.set(idContenedor, opc);

  const cont = document.getElementById(idContenedor);
  if (!cont) return;
  _inyectarEstilos();

  const compacto = !!opc.compacto;
  const actual = IDIOMAS[_idioma] || IDIOMAS[IDIOMA_POR_DEFECTO];

  cont.innerHTML = `
    <button type="button" class="nexo-idioma-trigger${compacto ? ' compacto' : ''}"
      aria-haspopup="listbox" aria-expanded="false">
      <i class="ti ti-language" aria-hidden="true"></i>
      <span>${actual.sigla}</span>
      <i class="ti ti-chevron-down" aria-hidden="true"></i>
    </button>`;

  const trigger = cont.querySelector('.nexo-idioma-trigger');
  trigger.onclick = e => {
    e.stopPropagation();
    const yaAbierto = _idiomaTriggerAbierto === trigger;
    _cerrarPanelIdioma();
    if (!yaAbierto) _abrirPanelIdioma(trigger);
  };
}
