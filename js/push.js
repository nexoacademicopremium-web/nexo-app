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

function _montarBannerPush() {
  if (document.getElementById('nexo-push-banner')) return;

  const banner = document.createElement('div');
  banner.id = 'nexo-push-banner';
  banner.style.cssText = [
    'position:fixed', 'left:16px', 'right:16px', 'bottom:16px', 'z-index:9998',
    'max-width:440px', 'margin:0 auto',
    'background:#0a1530', 'border:1px solid #1a2a4a', 'border-radius:14px',
    'padding:16px 18px', 'box-shadow:0 12px 32px rgba(4,7,27,.6)',
    'display:flex', 'align-items:center', 'gap:14px',
    'font-family:inherit', 'animation:nexoPushIn .25s ease',
  ].join(';');

  banner.innerHTML = `
    <style>@keyframes nexoPushIn{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}</style>
    <div style="width:38px;height:38px;border-radius:10px;background:#0f2240;display:flex;align-items:center;justify-content:center;flex-shrink:0">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#6eaef0" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
      </svg>
    </div>
    <div style="flex:1;min-width:0">
      <div style="color:#fff;font-size:13px;font-weight:600;margin-bottom:2px">Activa los avisos</div>
      <div style="color:#a8c8f0;font-size:11.5px;line-height:1.45">Te avisamos en este dispositivo de las sesiones y novedades.</div>
    </div>
    <div style="display:flex;flex-direction:column;gap:6px;flex-shrink:0">
      <button id="nexo-push-si" style="background:#154ca9;color:#fff;border:none;border-radius:8px;padding:8px 14px;font-size:12px;font-weight:600;cursor:pointer;font-family:inherit">Activar</button>
      <button id="nexo-push-no" style="background:none;color:#4a6080;border:none;padding:2px;font-size:11px;cursor:pointer;font-family:inherit">Ahora no</button>
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
    if (typeof showToast === 'function') {
      showToast(r.ok ? 'Avisos activados en este dispositivo' : r.motivo, r.ok ? 'success' : 'error');
    } else if (!r.ok) {
      alert(r.motivo);
    }
  };
}

async function _iniciarPush() {
  try {
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
