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

const IDIOMAS = {
  es: { nombre: 'Español',  bandera: '🇪🇸', sigla: 'ES' },
  en: { nombre: 'English',  bandera: '🇬🇧', sigla: 'EN' },
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
// Hay dos formas del mismo selector:
//   normal   → bandera + nombre completo, para el menú lateral
//   compacto → solo las siglas (ES · EN), para colarlo en una esquina
//              sin robarle sitio al contenido
//
// Se guarda con qué forma se montó cada uno, porque al cambiar de
// idioma se repintan todos a la vez y cada cual debe volver como era.

const _selectoresMontados = new Map();
const _ID_ESTILOS = 'nexo-idioma-css';

function _inyectarEstilos() {
  if (document.getElementById(_ID_ESTILOS)) return;
  const s = document.createElement('style');
  s.id = _ID_ESTILOS;
  s.textContent = `
    .nexo-idioma-btn{border-radius:8px;padding:7px 12px;font-size:12px;font-weight:600;
      cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;gap:6px;
      background:transparent;color:var(--muted,#7a8ba8);border:1px solid var(--border2,#1a2a4a)}
    .nexo-idioma-btn[aria-pressed="true"]{background:var(--blue,#154ca9);color:#fff;
      border-color:var(--blue,#154ca9)}

    /* Forma compacta: una píldora partida en dos, discreta */
    .nexo-idioma-seg{display:inline-flex;border:1px solid var(--border2,#1a2a4a);
      border-radius:9px;overflow:hidden;background:rgba(255,255,255,.02)}
    .nexo-idioma-seg .nexo-idioma-btn{border:0;border-radius:0;padding:5px 10px;
      font-size:11px;font-weight:700;letter-spacing:.04em;background:transparent;
      color:var(--muted,#7a8ba8);transition:background .15s ease,color .15s ease}
    .nexo-idioma-seg .nexo-idioma-btn + .nexo-idioma-btn{border-left:1px solid var(--border2,#1a2a4a)}
    .nexo-idioma-seg .nexo-idioma-btn[aria-pressed="true"]{background:var(--blue,#154ca9);color:#fff}
    @media(hover:hover){
      .nexo-idioma-seg .nexo-idioma-btn:not([aria-pressed="true"]):hover{color:var(--soft,#a8c8f0)}
    }`;
  document.head.appendChild(s);
}

function montarSelectorIdioma(idContenedor, opciones) {
  const opc = opciones || _selectoresMontados.get(idContenedor) || {};
  _selectoresMontados.set(idContenedor, opc);

  const cont = document.getElementById(idContenedor);
  if (!cont) return;
  _inyectarEstilos();

  const compacto = !!opc.compacto;

  const botones = Object.entries(IDIOMAS).map(([cod, info]) => {
    const activo = cod === _idioma;
    const dentro = compacto
      ? (info.sigla || cod.toUpperCase())
      : `<span aria-hidden="true">${info.bandera}</span> ${info.nombre}`;
    return `<button class="nexo-idioma-btn" data-idioma="${cod}"
              aria-pressed="${activo}" title="${info.nombre}"
              aria-label="${info.nombre}">${dentro}</button>`;
  }).join(compacto ? '' : ' ');

  cont.innerHTML = compacto ? `<div class="nexo-idioma-seg">${botones}</div>` : botones;

  cont.querySelectorAll('.nexo-idioma-btn').forEach(btn => {
    btn.onclick = async () => {
      if (btn.getAttribute('aria-pressed') === 'true') return;
      await cambiarIdioma(btn.dataset.idioma);
      // Se repintan todos: puede haber uno en el menú y otro en la portada
      _selectoresMontados.forEach((_, id) => montarSelectorIdioma(id));
    };
  });
}
