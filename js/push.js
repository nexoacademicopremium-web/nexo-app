// ============================================================
// NEXO ACADÉMICO — Notificaciones push (lado navegador)
//
// Registra el service worker, pide permiso y guarda la suscripción
// del dispositivo en Supabase. Se llama solo, sin bloquear la app:
// si el navegador no lo soporta o el usuario dice que no, la web
// sigue funcionando exactamente igual.
// ============================================================

const VAPID_PUBLIC_KEY = 'BOPbmcT8I00WlGFjF55jZNeF8ymcTQ_ttKyxvjdhGHC9Giqk84J3dVEVZcd9uCI6Cp1O-N6etypr48mjcOL5cFc';

function _urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64  = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw     = atob(base64);
  return Uint8Array.from([...raw].map(c => c.charCodeAt(0)));
}

function pushSoportado() {
  return 'serviceWorker' in navigator
      && 'PushManager' in window
      && 'Notification' in window;
}

// En iPhone el push solo existe si la web se ha añadido a la pantalla
// de inicio. Sirve para explicárselo al usuario en vez de fallar sin más.
function esIOSSinInstalar() {
  const esIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
  const instalada = window.navigator.standalone === true
    || window.matchMedia('(display-mode: standalone)').matches;
  return esIOS && !instalada;
}

let _swReg = null;

async function registrarServiceWorker() {
  if (!pushSoportado()) return null;
  if (_swReg) return _swReg;
  try {
    // El SW vive en la raíz para poder controlar /alumno, /profesor y /admin.
    _swReg = await navigator.serviceWorker.register(BASE_PATH + '/sw.js', { scope: '/' });
    await navigator.serviceWorker.ready;
    return _swReg;
  } catch (e) {
    console.warn('No se pudo registrar el service worker:', e);
    return null;
  }
}

// Guarda (o refresca) la suscripción de ESTE dispositivo.
async function guardarSuscripcion(sub) {
  const json = sub.toJSON();
  const { data: { user } } = await db.auth.getUser();
  if (!user) return false;

  const { error } = await db.from('push_subscriptions').upsert({
    usuario_id:   user.id,
    endpoint:     json.endpoint,
    p256dh:       json.keys.p256dh,
    auth:         json.keys.auth,
    user_agent:   navigator.userAgent.slice(0, 300),
    last_used_at: new Date().toISOString(),
  }, { onConflict: 'endpoint' });

  if (error) {
    console.warn('No se pudo guardar la suscripción push:', error.message);
    return false;
  }
  return true;
}

// Pide permiso explícitamente. Se llama desde un botón, nunca sola:
// los navegadores penalizan pedirlo nada más cargar.
async function activarNotificaciones() {
  if (!pushSoportado()) {
    return { ok: false, motivo: esIOSSinInstalar()
      ? 'En iPhone primero añade la web a la pantalla de inicio: Compartir → Añadir a inicio.'
      : 'Este navegador no admite notificaciones.' };
  }

  const permiso = await Notification.requestPermission();
  if (permiso !== 'granted') {
    return { ok: false, motivo: permiso === 'denied'
      ? 'Has bloqueado las notificaciones. Actívalas en los ajustes del navegador para este sitio.'
      : 'No se ha concedido el permiso.' };
  }

  const reg = await registrarServiceWorker();
  if (!reg) return { ok: false, motivo: 'No se pudo iniciar el servicio de avisos.' };

  try {
    const sub = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: _urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
    });
    const guardada = await guardarSuscripcion(sub);
    return guardada
      ? { ok: true }
      : { ok: false, motivo: 'No se pudo registrar este dispositivo.' };
  } catch (e) {
    console.warn('Suscripción push fallida:', e);
    return { ok: false, motivo: 'No se pudo activar en este dispositivo.' };
  }
}

async function desactivarNotificaciones() {
  const reg = await registrarServiceWorker();
  if (!reg) return false;
  const sub = await reg.pushManager.getSubscription();
  if (!sub) return true;
  await db.from('push_subscriptions').delete().eq('endpoint', sub.endpoint);
  await sub.unsubscribe();
  return true;
}

async function estadoNotificaciones() {
  if (!pushSoportado()) return 'no-soportado';
  if (Notification.permission === 'denied')  return 'bloqueado';
  if (Notification.permission === 'default') return 'sin-pedir';
  const reg = await registrarServiceWorker();
  const sub = reg ? await reg.pushManager.getSubscription() : null;
  return sub ? 'activo' : 'sin-pedir';
}

// ── Aviso para activar las notificaciones ───────────────────────
// Se monta solo, en cualquiera de los tres paneles, y únicamente si
// hay sesión y el permiso no se ha decidido todavía.

const _PUSH_DESCARTADO = 'nexo_push_descartado';

// El banner vive pegado al borde de abajo. En el móvil hay que dejar
// libre la barra de navegación inferior (70px + la zona segura del
// iPhone), o el aviso queda escondido detrás de ella.
const _ID_CSS_BANNER = 'nexo-push-css';

function _estilosBanner() {
  if (document.getElementById(_ID_CSS_BANNER)) return;
  const s = document.createElement('style');
  s.id = _ID_CSS_BANNER;
  s.textContent = `
    @keyframes nexoPushIn{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}

    #nexo-push-banner{position:fixed;left:14px;right:14px;z-index:9998;
      bottom:calc(16px + env(safe-area-inset-bottom,0px));
      max-width:440px;margin:0 auto;
      background:#0a1530;border:1px solid #1a2a4a;border-radius:14px;
      padding:14px 16px;box-shadow:0 12px 32px rgba(4,7,27,.6);
      display:flex;align-items:center;gap:13px;
      font-family:inherit;animation:nexoPushIn .25s ease}

    #nexo-push-banner .push-ico{width:38px;height:38px;border-radius:10px;background:#0f2240;
      display:flex;align-items:center;justify-content:center;flex-shrink:0}
    #nexo-push-banner .push-txt{flex:1;min-width:0}
    #nexo-push-banner .push-tit{color:#fff;font-size:13px;font-weight:600;margin-bottom:2px}
    #nexo-push-banner .push-sub{color:#a8c8f0;font-size:11.5px;line-height:1.45}
    #nexo-push-banner .push-acc{display:flex;flex-direction:column;gap:6px;flex-shrink:0}

    #nexo-push-banner #nexo-push-si{background:#154ca9;color:#fff;border:none;border-radius:8px;
      padding:8px 14px;font-size:12px;font-weight:600;cursor:pointer;font-family:inherit;white-space:nowrap}
    #nexo-push-banner #nexo-push-no{background:none;color:#6b83a5;border:none;padding:2px;
      font-size:11px;cursor:pointer;font-family:inherit;white-space:nowrap}

    /* Móvil: por encima de la barra de navegación de abajo */
    @media(max-width:768px){
      #nexo-push-banner{bottom:calc(84px + env(safe-area-inset-bottom,0px))}
    }

    /* Pantallas estrechas: el texto arriba y los botones en su propia
       fila, para que no se estrujen contra el borde */
    @media(max-width:430px){
      #nexo-push-banner{flex-wrap:wrap;gap:11px;padding:14px}
      #nexo-push-banner .push-txt{flex:1 1 0}
      #nexo-push-banner .push-acc{flex:1 1 100%;flex-direction:row-reverse;
        align-items:center;justify-content:space-between;gap:10px}
      #nexo-push-banner #nexo-push-si{flex:1;padding:10px 14px;font-size:12.5px}
      #nexo-push-banner #nexo-push-no{padding:10px 2px}
    }`;
  document.head.appendChild(s);
}

function _montarBannerPush() {
  if (document.getElementById('nexo-push-banner')) return;
  _estilosBanner();

  const banner = document.createElement('div');
  banner.id = 'nexo-push-banner';

  banner.innerHTML = `
    <div class="push-ico">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#6eaef0" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
      </svg>
    </div>
    <div class="push-txt">
      <div class="push-tit">Activa los avisos</div>
      <div class="push-sub">Te avisamos en este dispositivo de las sesiones y novedades.</div>
    </div>
    <div class="push-acc">
      <button id="nexo-push-si">Activar</button>
      <button id="nexo-push-no">Ahora no</button>
    </div>`;

  document.body.appendChild(banner);

  const cerrar = () => banner.remove();

  banner.querySelector('#nexo-push-no').onclick = () => {
    localStorage.setItem(_PUSH_DESCARTADO, '1');
    cerrar();
  };

  banner.querySelector('#nexo-push-si').onclick = async () => {
    const btn = banner.querySelector('#nexo-push-si');
    btn.disabled = true;
    btn.textContent = 'Activando…';
    const r = await activarNotificaciones();
    cerrar();
    if (r.ok) {
      // Aviso de prueba inmediato: así se ve que funciona de verdad,
      // sin esperar a que ocurra nada en la plataforma.
      enviarAvisoDePrueba();
      _pintarEstadoPush();
      if (typeof showToast === 'function') showToast('Avisos activados — te llega uno de prueba');
    } else if (typeof showToast === 'function') {
      showToast(r.motivo, 'error');
    } else {
      alert(r.motivo);
    }
  };
}

// ── Tutorial de instalación ─────────────────────────────────────
// Reconoce el aparato para enseñar los pasos que tocan, y deja ver
// los del resto: mucha gente instala en un sitio y pregunta por otro.

function _detectarAparato() {
  const ua = navigator.userAgent;
  const iOS = /iPad|iPhone|iPod/.test(ua)
    // El iPad moderno se presenta como Mac; el táctil lo delata.
    || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  const android = /Android/.test(ua);
  const mac  = /Macintosh/.test(ua) && !iOS;
  const win  = /Windows/.test(ua);
  const esEdge = /Edg\//.test(ua);
  const esChrome = /Chrome|CriOS/.test(ua) && !esEdge;
  const esFirefox = /Firefox|FxiOS/.test(ua);
  const esSamsung = /SamsungBrowser/.test(ua);
  const esSafari = /Safari/.test(ua) && !esChrome && !esEdge && !esFirefox && !esSamsung;

  const instalada = window.navigator.standalone === true
    || window.matchMedia('(display-mode: standalone)').matches;

  let clave = 'otro';
  if (iOS)          clave = 'ios';
  else if (android) clave = esSamsung ? 'samsung' : 'android';
  else if (mac)     clave = esSafari ? 'mac-safari' : 'escritorio';
  else if (win)     clave = 'escritorio';

  return { clave, instalada, esSafari, esChrome, iOS, android };
}

const _GUIAS = {
  ios: {
    titulo: 'iPhone o iPad',
    nota: 'Es imprescindible: en iPhone y iPad los avisos <b>solo</b> llegan si Nexo está en la pantalla de inicio.',
    reqSafari: true,
    pasos: [
      'Abre Nexo en <b>Safari</b> (no vale Chrome en iPhone).',
      'Pulsa el botón <b>Compartir</b>: el cuadrado con una flecha hacia arriba, abajo en el centro.',
      'Baja por la lista y elige <b>Añadir a pantalla de inicio</b>.',
      'Pulsa <b>Añadir</b> arriba a la derecha.',
      'Cierra Safari y abre Nexo desde el icono nuevo.',
    ],
  },
  android: {
    titulo: 'Móvil o tablet Android',
    nota: 'Vale para Oppo, Xiaomi, Google Pixel, Motorola y cualquier Android con Chrome.',
    pasos: [
      'Abre Nexo en <b>Chrome</b>.',
      'Pulsa los <b>tres puntos</b> ⋮ de arriba a la derecha.',
      'Elige <b>Instalar aplicación</b> o <b>Añadir a pantalla de inicio</b>.',
      'Confirma pulsando <b>Instalar</b>.',
    ],
  },
  samsung: {
    titulo: 'Samsung con Internet',
    nota: 'Si usas el navegador propio de Samsung en vez de Chrome.',
    pasos: [
      'Pulsa las <b>tres rayas</b> ☰ de abajo a la derecha.',
      'Elige <b>Añadir página a</b>.',
      'Selecciona <b>Pantalla de inicio</b>.',
    ],
  },
  'mac-safari': {
    titulo: 'Mac con Safari',
    nota: 'Necesitas macOS Sonoma o posterior.',
    pasos: [
      'Con Nexo abierto, ve al menú <b>Archivo</b>.',
      'Elige <b>Añadir al Dock</b>.',
      'Nexo aparecerá en el Dock como una aplicación más.',
    ],
  },
  escritorio: {
    titulo: 'Ordenador con Chrome o Edge',
    nota: 'Sirve igual en Windows y en Mac.',
    pasos: [
      'Mira a la derecha de la barra de direcciones.',
      'Pulsa el icono de <b>instalar</b>: una pantalla con una flecha hacia abajo.',
      'Confirma con <b>Instalar</b>. Si no ves el icono, entra en los tres puntos ⋮ y busca <b>Instalar Nexo</b>.',
    ],
  },
};

function _htmlGuia(g, abierta) {
  const pasos = g.pasos.map(p => `<li style="margin-bottom:9px;line-height:1.55">${p}</li>`).join('');
  const nota = g.nota
    ? `<p style="color:var(--muted);font-size:12.5px;margin:0 0 12px;line-height:1.5">${g.nota}</p>` : '';
  if (abierta) {
    return `${nota}<ol style="margin:0;padding-left:20px;color:var(--soft);font-size:13.5px">${pasos}</ol>`;
  }
  return `<details style="border-top:.5px solid var(--border2);padding:10px 0 2px">
    <summary style="cursor:pointer;color:var(--soft);font-size:13px;font-weight:500;list-style:revert">${g.titulo}</summary>
    <div style="padding:10px 0 6px">${nota}
      <ol style="margin:0;padding-left:20px;color:var(--soft);font-size:13.5px">${pasos}</ol>
    </div>
  </details>`;
}

async function montarTutorialInstalacion(idContenedor) {
  const cont = document.getElementById(idContenedor);
  if (!cont) return;

  const ap = _detectarAparato();
  const estado = await estadoNotificaciones();
  const guia = _GUIAS[ap.clave] || _GUIAS.escritorio;

  // Aviso de Safari: en iPhone, Chrome no puede instalar ni recibir avisos.
  const avisoNavegador = (ap.clave === 'ios' && !ap.esSafari)
    ? `<div style="background:#3a2a00;border:.5px solid #7a5a00;border-radius:9px;padding:12px 14px;margin-bottom:14px;color:#fbbf24;font-size:12.5px;line-height:1.5">
         Estás usando un navegador que en iPhone no puede instalar la app. Abre Nexo en <b>Safari</b> para poder hacerlo.
       </div>` : '';

  const estadoAvisos = {
    'activo':       ['Avisos activados en este dispositivo', 'var(--green)', 'ti-circle-check'],
    'sin-pedir':    ['Los avisos no están activados todavía', '#fbbf24', 'ti-alert-circle'],
    'bloqueado':    ['Los avisos están bloqueados en este navegador', 'var(--red)', 'ti-ban'],
    'no-soportado': ['Este navegador no admite avisos', 'var(--muted)', 'ti-info-circle'],
  }[estado] || ['—', 'var(--muted)', 'ti-info-circle'];

  const yaInstalada = ap.instalada
    ? `<div style="display:flex;align-items:center;gap:9px;background:#0d2d1e;border:.5px solid #1a7f5e;border-radius:9px;padding:12px 14px;margin-bottom:16px">
         <i class="ti ti-circle-check" style="color:var(--green);font-size:17px"></i>
         <span style="color:var(--green);font-size:13px;font-weight:500">Ya tienes Nexo instalado en este dispositivo</span>
       </div>` : '';

  cont.innerHTML = `
    <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:6px">
      <h2 style="color:#fff;font-size:15px;font-weight:700;margin:0">Recibir avisos en este dispositivo</h2>
      <span style="display:inline-flex;align-items:center;gap:6px;color:${estadoAvisos[1]};font-size:12px">
        <i class="ti ${estadoAvisos[2]}" style="font-size:15px"></i>${estadoAvisos[0]}
      </span>
    </div>
    <p style="color:var(--muted);font-size:12.5px;margin:0 0 16px;line-height:1.55">
      Instala Nexo como una aplicación para que los avisos de sesiones, tareas e informes te lleguen al momento.
    </p>

    ${yaInstalada}
    ${avisoNavegador}

    ${estado !== 'activo' && estado !== 'no-soportado' ? `
      <button onclick="gestionarNotificaciones()" style="background:var(--blue);color:#fff;border:none;border-radius:9px;padding:11px 18px;font-size:13px;font-weight:600;cursor:pointer;font-family:inherit;margin-bottom:18px">
        <i class="ti ti-bell"></i> Activar los avisos
      </button>` : ''}

    ${!ap.instalada ? `
      <div style="background:rgba(255,255,255,.03);border:.5px solid var(--border2);border-radius:11px;padding:16px 18px;margin-bottom:14px">
        <div style="color:var(--blue);font-size:11px;letter-spacing:.1em;text-transform:uppercase;font-weight:700;margin-bottom:4px">Tu dispositivo</div>
        <div style="color:#fff;font-size:14px;font-weight:600;margin-bottom:10px">${guia.titulo}</div>
        ${_htmlGuia(guia, true)}
      </div>` : ''}

    <div style="margin-top:6px">
      <div style="color:var(--muted);font-size:11px;letter-spacing:.1em;text-transform:uppercase;font-weight:700;margin-bottom:6px">Otros dispositivos</div>
      ${Object.entries(_GUIAS)
          .filter(([k]) => k !== ap.clave || ap.instalada)
          .map(([, g]) => _htmlGuia(g, false)).join('')}
    </div>`;
}

// Control permanente de los avisos, accesible desde el menú. Hace falta
// porque el aviso automático solo sale una vez: quien pulsó "ahora no"
// se quedaba sin forma de activarlos.
async function gestionarNotificaciones() {
  const estado = await estadoNotificaciones();

  if (estado === 'no-soportado') {
    alert(esIOSSinInstalar()
      ? 'Para recibir avisos en el iPhone, primero añade Nexo a la pantalla de inicio:\n\n'
        + 'Pulsa el botón Compartir (el cuadrado con la flecha) y elige "Añadir a pantalla de inicio".\n\n'
        + 'Luego abre Nexo desde ese icono y vuelve a intentarlo.'
      : 'Este navegador no admite avisos.');
    return;
  }

  if (estado === 'bloqueado') {
    alert('Los avisos están bloqueados en este navegador.\n\n'
      + 'Para permitirlos: pulsa el candado (o el icono de ajustes) junto a la dirección web, '
      + 'busca "Notificaciones" y cámbialo a "Permitir". Después recarga la página.');
    return;
  }

  if (estado === 'activo') {
    if (confirm('Los avisos ya están activados en este dispositivo.\n\n'
              + '¿Quieres enviarte uno de prueba?\n\n'
              + '(Para desactivarlos, pulsa Cancelar y luego confirma)')) {
      const r = await enviarAvisoDePrueba();
      const n = r?.push?.enviados ?? 0;
      if (typeof showToast === 'function') {
        showToast(n > 0 ? 'Aviso de prueba enviado' : 'No se pudo enviar el aviso', n > 0 ? 'success' : 'error');
      }
    } else if (confirm('¿Desactivar los avisos en este dispositivo?')) {
      await desactivarNotificaciones();
      if (typeof showToast === 'function') showToast('Avisos desactivados en este dispositivo');
      _pintarEstadoPush();
    }
    return;
  }

  // Estado 'sin-pedir': se activa
  const r = await activarNotificaciones();
  if (r.ok) {
    localStorage.removeItem(_PUSH_DESCARTADO);
    enviarAvisoDePrueba();
    if (typeof showToast === 'function') showToast('Avisos activados — te llega uno de prueba');
    _pintarEstadoPush();
  } else {
    alert(r.motivo);
  }
}

// Se manda un push a uno mismo. Útil para comprobar el canal aislado
// de la lógica de destinatarios.
async function enviarAvisoDePrueba() {
  try {
    const { data, error } = await db.functions.invoke('notificar', { body: { evento: 'prueba' } });
    if (error) throw error;
    return data;
  } catch (e) {
    console.warn('Aviso de prueba fallido:', e);
    return null;
  }
}

// Pinta en el menú si los avisos están puestos o no, para que se vea de
// un vistazo sin tener que entrar a mirar.
async function _pintarEstadoPush() {
  const pill = document.getElementById('notif-estado-pill');
  if (!pill) return;
  const estado = await estadoNotificaciones();
  const mapa = {
    'activo':       ['Activos',  '#0d2d1e', '#34d399'],
    'sin-pedir':    ['Activar',  '#3a2a00', '#fbbf24'],
    'bloqueado':    ['Bloqueado','#2d0d0d', '#f87171'],
    'no-soportado': ['No dispo', '#1a1a1a', '#888888'],
  };
  const [txt, bg, col] = mapa[estado] || mapa['sin-pedir'];
  pill.textContent = txt;
  pill.style.background = bg;
  pill.style.color = col;
}

async function _iniciarPush() {
  try {
    _pintarEstadoPush();
    if (!pushSoportado()) return;
    // Sin sesión no hay a quién asociar el dispositivo.
    const { data: { user } } = await db.auth.getUser();
    if (!user) return;

    if (Notification.permission === 'granted') {
      await sincronizarPushSiYaConcedido();
      return;
    }
    if (Notification.permission === 'denied') return;
    if (localStorage.getItem(_PUSH_DESCARTADO)) return;

    // Un respiro para no competir con la carga del panel.
    setTimeout(_montarBannerPush, 2500);
  } catch (e) {
    console.warn('Inicio de push omitido:', e);
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', _iniciarPush);
} else {
  _iniciarPush();
}

// Si el usuario ya dio permiso en otra visita, se refresca la suscripción
// en silencio: los endpoints caducan y hay que renovarlos.
async function sincronizarPushSiYaConcedido() {
  try {
    if (!pushSoportado() || Notification.permission !== 'granted') return;
    const reg = await registrarServiceWorker();
    if (!reg) return;
    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: _urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
      });
    }
    await guardarSuscripcion(sub);
  } catch (e) {
    console.warn('Sincronización push omitida:', e);
  }
}

// ── Visor de la guía en PDF ─────────────────────────────────────
// Con Nexo instalada como aplicación no hay pestañas, ni barra de
// direcciones, ni botón de volver: un PDF abierto con target="_blank"
// se adueña de la ventana y deja al usuario sin salida más que cerrar
// la app. Por eso se abre en una capa propia, que sí tiene su cierre.
//
// Se puede salir de tres formas: el aspa, la tecla Escape y el botón
// de volver del móvil (se mete una entrada en el historial para que
// ese gesto cierre la capa en vez de sacar al usuario de la sección).

const _ID_VISOR_GUIA = 'nexo-visor-guia';

// El visor lo usan los dos paneles y cada uno prefija sus claves de
// forma distinta, así que se prueban ambas antes de rendirse al
// castellano de reserva.
function _txt(claves, castellano) {
  if (typeof t !== 'function') return castellano;
  for (const c of [].concat(claves)) {
    const v = t(c);
    if (v !== c) return v;
  }
  return castellano;
}

function _estilosVisorGuia() {
  if (document.getElementById('nexo-visor-css')) return;
  const s = document.createElement('style');
  s.id = 'nexo-visor-css';
  s.textContent = `
    #${_ID_VISOR_GUIA}{position:fixed;inset:0;z-index:100000;background:var(--bg,#04071b);
      display:flex;flex-direction:column;animation:nexoVisorIn .2s ease}
    @keyframes nexoVisorIn{from{opacity:0}to{opacity:1}}

    #${_ID_VISOR_GUIA} .vg-head{display:flex;align-items:center;justify-content:space-between;
      gap:12px;flex-shrink:0;background:var(--dark,#070c22);
      border-bottom:.5px solid var(--border,#1a2a4a);
      padding:calc(env(safe-area-inset-top,0px) + 12px) 16px 12px}
    #${_ID_VISOR_GUIA} .vg-tit{color:#fff;font-size:14px;font-weight:700;
      overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    #${_ID_VISOR_GUIA} .vg-x{background:rgba(255,255,255,.06);color:#fff;border:none;
      width:34px;height:34px;border-radius:9px;font-size:16px;line-height:1;cursor:pointer;
      flex-shrink:0;font-family:inherit;display:flex;align-items:center;justify-content:center}
    #${_ID_VISOR_GUIA} .vg-x:hover{background:rgba(255,255,255,.12)}

    #${_ID_VISOR_GUIA} iframe{flex:1;width:100%;border:0;background:#fff;min-height:0}

    #${_ID_VISOR_GUIA} .vg-pie{flex-shrink:0;background:var(--dark,#070c22);
      border-top:.5px solid var(--border,#1a2a4a);text-align:center;
      padding:11px 16px calc(env(safe-area-inset-bottom,0px) + 11px)}
    #${_ID_VISOR_GUIA} .vg-pie a{color:var(--blue,#6eaef0);font-size:12.5px;
      text-decoration:none;font-weight:600}`;
  document.head.appendChild(s);
}

function abrirGuiaInstalacion(url) {
  if (document.getElementById(_ID_VISOR_GUIA)) return;
  _estilosVisorGuia();

  const pdf = new URL(url || 'assets/guia-instalar-nexo.pdf', document.baseURI).href;

  const ov = document.createElement('div');
  ov.id = _ID_VISOR_GUIA;
  ov.innerHTML = `
    <div class="vg-head">
      <span class="vg-tit">${_txt(['alumno.guia_titulo','profesor.guia_titulo'], 'Guía de instalación')}</span>
      <button class="vg-x" aria-label="${_txt(['alumno.cerrar','profesor.cerrar'], 'Cerrar')}">&times;</button>
    </div>
    <iframe src="${pdf}" title="${_txt(['alumno.guia_titulo','profesor.guia_titulo'], 'Guía de instalación')}"></iframe>
    <div class="vg-pie">
      <a href="${pdf}" target="_blank" rel="noopener noreferrer">
        ${_txt(['alumno.abrir_en_navegador','profesor.abrir_en_navegador'], 'Abrir en el navegador ↗')}
      </a>
    </div>`;

  document.body.appendChild(ov);
  // Se bloquea el desplazamiento de detrás para que no se mueva el
  // fondo mientras se lee la guía.
  const scrollPrevio = document.body.style.overflow;
  document.body.style.overflow = 'hidden';

  const alTeclado = (e) => { if (e.key === 'Escape') cerrar(); };
  const alVolver  = () => cerrar(false);

  function cerrar(consumirHistorial = true) {
    window.removeEventListener('popstate', alVolver);
    document.removeEventListener('keydown', alTeclado);
    document.body.style.overflow = scrollPrevio;
    ov.remove();
    if (consumirHistorial && history.state && history.state.nexoVisorGuia) history.back();
  }

  ov.querySelector('.vg-x').onclick = () => cerrar();
  document.addEventListener('keydown', alTeclado);

  // El botón de volver del móvil cierra la capa en vez de sacar al
  // usuario de donde estaba.
  try {
    history.pushState({ nexoVisorGuia: true }, '');
    window.addEventListener('popstate', alVolver);
  } catch { /* algún navegador puede negarlo; quedan el aspa y Escape */ }
}
