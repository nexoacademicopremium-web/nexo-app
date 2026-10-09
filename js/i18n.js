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
  ru: { nombre: 'Русский',  bandera: '🇷🇺', sigla: 'RU' },
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
// Un único botón (bandera + siglas) que al pulsarlo despliega una
// tarjeta flotante con los idiomas disponibles, cada uno con su
// bandera y su nombre. La misma pieza sirve para colarla en una
// esquina (compacto) o para el menú lateral (normal, algo más
// grande y con "arriba" si el hueco de abajo es escaso).
//
// Se guarda con qué forma se montó cada uno, porque al cambiar de
// idioma se repintan todos a la vez y cada cual debe volver como era.

const _selectoresMontados = new Map();
const _ID_ESTILOS = 'nexo-idioma-css';
let _idiomaClickExterior = false;

function _inyectarEstilos() {
  if (document.getElementById(_ID_ESTILOS)) return;
  const s = document.createElement('style');
  s.id = _ID_ESTILOS;
  s.textContent = `
    .nexo-idioma-wrap{position:relative;display:inline-block}

    .nexo-idioma-trigger{display:inline-flex;align-items:center;gap:7px;
      background:transparent;border:.5px solid var(--border2,#1a2a4a);border-radius:9px;
      padding:7px 11px;cursor:pointer;font-family:inherit;color:var(--soft,#a8c8f0);
      font-size:12px;font-weight:500;transition:border-color .15s,background .15s}
    .nexo-idioma-trigger:hover{border-color:var(--blue,#6eaef0)}
    .nexo-idioma-trigger .nxi-flag{font-size:14px;line-height:1}
    .nexo-idioma-trigger .ti-chevron-down{font-size:12px;color:var(--muted,#4a6080);
      transition:transform .15s}
    .nexo-idioma-wrap[data-open="true"] .nexo-idioma-trigger{border-color:var(--blue,#6eaef0)}
    .nexo-idioma-wrap[data-open="true"] .ti-chevron-down{transform:rotate(180deg)}

    /* Compacto: solo bandera + siglas, pastilla pequeña para una esquina */
    .nexo-idioma-wrap[data-compacto="true"] .nexo-idioma-trigger{
      padding:5px 9px;gap:5px;font-size:11px;font-weight:700;letter-spacing:.03em;
      border-radius:20px}

    .nexo-idioma-panel{position:absolute;right:0;min-width:172px;
      background:var(--surface,#0a1530);border:.5px solid var(--border,#1a2a4a);
      border-radius:12px;padding:6px;box-shadow:0 14px 34px rgba(0,0,0,.5);z-index:200;
      display:flex;flex-direction:column;gap:1px;
      opacity:0;transform:translateY(-4px) scale(.98);pointer-events:none;
      transition:opacity .14s ease,transform .14s ease}
    .nexo-idioma-wrap[data-open="true"] .nexo-idioma-panel{
      opacity:1;transform:translateY(0) scale(1);pointer-events:auto}
    .nexo-idioma-wrap[data-arriba="true"] .nexo-idioma-panel{bottom:calc(100% + 6px)}
    .nexo-idioma-wrap:not([data-arriba="true"]) .nexo-idioma-panel{top:calc(100% + 6px)}

    .nexo-idioma-opt{display:flex;align-items:center;gap:9px;background:transparent;
      border:none;border-radius:8px;padding:8px 10px;cursor:pointer;font-family:inherit;
      color:var(--txt,#e0eaf8);font-size:12.5px;font-weight:500;text-align:left;width:100%}
    .nexo-idioma-opt .nxi-flag{font-size:15px}
    .nexo-idioma-opt .ti-check{margin-left:auto;color:var(--blue,#6eaef0);
      font-size:14px;opacity:0}
    .nexo-idioma-opt[aria-selected="true"]{background:rgba(110,174,240,.12)}
    .nexo-idioma-opt[aria-selected="true"] .ti-check{opacity:1}
    @media(hover:hover){
      .nexo-idioma-opt:not([aria-selected="true"]):hover{background:var(--border2,#0f1f35)}
    }`;
  document.head.appendChild(s);

  // Un solo listener global: cierra cualquier selector abierto al tocar
  // fuera, sin importar cuántos haya montados en la página.
  if (!_idiomaClickExterior) {
    _idiomaClickExterior = true;
    document.addEventListener('click', e => {
      document.querySelectorAll('.nexo-idioma-wrap[data-open="true"]').forEach(w => {
        if (!w.contains(e.target)) w.dataset.open = 'false';
      });
    });
  }
}

function montarSelectorIdioma(idContenedor, opciones) {
  const opc = opciones || _selectoresMontados.get(idContenedor) || {};
  _selectoresMontados.set(idContenedor, opc);

  const cont = document.getElementById(idContenedor);
  if (!cont) return;
  _inyectarEstilos();

  const compacto = !!opc.compacto;
  const actual = IDIOMAS[_idioma] || IDIOMAS[IDIOMA_POR_DEFECTO];

  const opts = Object.entries(IDIOMAS).map(([cod, info]) => {
    const activo = cod === _idioma;
    return `<button type="button" class="nexo-idioma-opt" data-idioma="${cod}" role="option"
              aria-selected="${activo}">
              <span class="nxi-flag" aria-hidden="true">${info.bandera}</span>
              <span>${info.nombre}</span>
              <i class="ti ti-check" aria-hidden="true"></i>
            </button>`;
  }).join('');

  cont.innerHTML = `
    <div class="nexo-idioma-wrap" data-compacto="${compacto}" data-arriba="${!!opc.arriba}" data-open="false">
      <button type="button" class="nexo-idioma-trigger" aria-haspopup="listbox" aria-expanded="false">
        <span class="nxi-flag" aria-hidden="true">${actual.bandera}</span>
        <span>${actual.sigla}</span>
        <i class="ti ti-chevron-down" aria-hidden="true"></i>
      </button>
      <div class="nexo-idioma-panel" role="listbox">${opts}</div>
    </div>`;

  const wrap    = cont.querySelector('.nexo-idioma-wrap');
  const trigger = cont.querySelector('.nexo-idioma-trigger');

  trigger.onclick = e => {
    e.stopPropagation();
    const abierto = wrap.dataset.open === 'true';
    // Al abrir uno, se cierran los demás selectores que hubiera en la página.
    document.querySelectorAll('.nexo-idioma-wrap').forEach(w => w.dataset.open = 'false');
    wrap.dataset.open = abierto ? 'false' : 'true';
  };

  cont.querySelectorAll('.nexo-idioma-opt').forEach(btn => {
    btn.onclick = async e => {
      e.stopPropagation();
      wrap.dataset.open = 'false';
      if (btn.getAttribute('aria-selected') === 'true') return;
      await cambiarIdioma(btn.dataset.idioma);
      // Se repintan todos: puede haber uno en el menú y otro en la portada
      _selectoresMontados.forEach((_, id) => montarSelectorIdioma(id));
    };
  });
}
