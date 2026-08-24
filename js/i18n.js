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
  es: { nombre: 'Español',  bandera: '🇪🇸' },
  en: { nombre: 'English',  bandera: '🇬🇧' },
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

const _selectoresMontados = new Set();

function montarSelectorIdioma(idContenedor) {
  _selectoresMontados.add(idContenedor);
  const cont = document.getElementById(idContenedor);
  if (!cont) return;

  cont.innerHTML = Object.entries(IDIOMAS).map(([cod, info]) => `
    <button class="nexo-idioma-btn" data-idioma="${cod}"
            aria-pressed="${cod === _idioma}"
            style="background:${cod === _idioma ? 'var(--blue)' : 'transparent'};
                   color:${cod === _idioma ? '#fff' : 'var(--muted)'};
                   border:1px solid ${cod === _idioma ? 'var(--blue)' : 'var(--border2)'};
                   border-radius:8px;padding:7px 12px;font-size:12px;font-weight:600;
                   cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;gap:6px">
      <span aria-hidden="true">${info.bandera}</span> ${info.nombre}
    </button>`).join(' ');

  cont.querySelectorAll('.nexo-idioma-btn').forEach(btn => {
    btn.onclick = async () => {
      await cambiarIdioma(btn.dataset.idioma);
      // Se repintan todos: puede haber uno en el menú y otro en la portada
      _selectoresMontados.forEach(id => montarSelectorIdioma(id));
    };
  });
}
