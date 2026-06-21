// ============================================================
// NEXO ACADÉMICO — Auth Helper
// Include AFTER config.js on every protected page.
// Usage: const { session, usuario, alumnoData, profesorData }
//        = await requireAuth('alumno');
// ============================================================

async function requireAuth(requiredRole) {
  const { data: { session }, error } = await db.auth.getSession();

  if (!session) {
    const isAdmin = requiredRole === 'admin';
    window.location.href = BASE_PATH + (isAdmin ? '/admin/login.html' : '/login.html');
    return null;
  }

  const { data: usuario, error: uErr } = await db
    .from('usuarios')
    .select('*')
    .eq('id', session.user.id)
    .single();

  if (!usuario || !usuario.activo) {
    await db.auth.signOut();
    window.location.href = BASE_PATH + '/login.html';
    return null;
  }

  if (requiredRole && usuario.rol !== requiredRole && usuario.rol !== 'admin') {
    if (usuario.rol === 'alumno')   window.location.href = BASE_PATH + '/alumno/index.html';
    if (usuario.rol === 'profesor') window.location.href = BASE_PATH + '/profesor/index.html';
    if (usuario.rol === 'admin')    window.location.href = BASE_PATH + '/admin/index.html';
    return null;
  }

  let alumnoData   = null;
  let profesorData = null;

  if (usuario.rol === 'alumno') {
    const { data } = await db
      .from('alumnos')
      .select('*')
      .eq('usuario_id', usuario.id)
      .single();
    alumnoData = data;
  }

  if (usuario.rol === 'profesor') {
    const { data } = await db
      .from('profesores')
      .select('*')
      .eq('usuario_id', usuario.id)
      .single();
    profesorData = data;
  }

  return { session, usuario, alumnoData, profesorData };
}

async function logout() {
  await db.auth.signOut();
  window.location.href = BASE_PATH + '/login.html';
}

function getInitials(nombre, apellidos) {
  const n = (nombre || '').trim();
  const a = (apellidos || '').trim();
  if (!n) return '?';
  return (n[0] + (a ? a[0] : '')).toUpperCase();
}

function formatDate(dateStr) {
  if (!dateStr) return '—';
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' });
}

function formatShortDate(dateStr) {
  if (!dateStr) return '—';
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('es-ES', { day: 'numeric', month: 'short' });
}

function formatTime(timeStr) {
  if (!timeStr) return '';
  return timeStr.substring(0, 5);
}

function nivelLabel(nivel) {
  const map = {
    '1PRI': '1.º Primaria', '2PRI': '2.º Primaria', '3PRI': '3.º Primaria',
    '4PRI': '4.º Primaria', '5PRI': '5.º Primaria', '6PRI': '6.º Primaria',
    '1ESO': '1.º ESO', '2ESO': '2.º ESO', '3ESO': '3.º ESO', '4ESO': '4.º ESO',
    '1BACH': '1.º Bach', '2BACH': '2.º Bach',
    'UNIV': 'Universidad'
  };
  return map[nivel] || nivel || '—';
}

function estadoPill(estado) {
  const map = {
    pendiente_confirmacion: ['st-pend', 'Pendiente'],
    confirmada:             ['st-ok',   'Confirmada'],
    rechazada:              ['st-red',  'Rechazada'],
    cancelada:              ['st-grey', 'Cancelada']
  };
  const [cls, txt] = map[estado] || ['st-grey', estado];
  return `<span class="status-pill ${cls}">${txt}</span>`;
}

function showToast(msg, type = 'success') {
  const colors = {
    success: 'var(--green)',
    error: 'var(--red)',
    info: 'var(--blue)'
  };
  const t = document.createElement('div');
  t.style.cssText = `
    position:fixed;bottom:24px;right:24px;z-index:9999;
    background:var(--surface);border:0.5px solid ${colors[type]};
    border-left:3px solid ${colors[type]};border-radius:8px;
    padding:14px 20px;font-size:13px;color:var(--txt);
    max-width:340px;box-shadow:0 4px 24px rgba(0,0,0,.5);
    animation:slideIn .2s ease;
  `;
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 4000);
}

// Inject keyframe animation once
if (!document.getElementById('toast-style')) {
  const s = document.createElement('style');
  s.id = 'toast-style';
  s.textContent = `@keyframes slideIn{from{transform:translateX(120%);opacity:0}to{transform:none;opacity:1}}`;
  document.head.appendChild(s);
}
