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

  if (requiredRole && usuario.rol !== requiredRole) {
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

function _fechaHoy() {
  const d = new Date();
  return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
}

function _fechaLocal(d) {
  return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
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
    'UNIV': 'Universidad',
    'todos': 'General'
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

// ─── Iconos y colores semánticos de asignatura ───────────────────────────────
function getSubjectMeta(name) {
  const n = (name || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'');
  if (/matem|calculo|algebra|aritm|estadis|geometr/.test(n)) return { ico:'ti-math-function',      cc:'#2563eb' };
  if (/fisica|mecanica|termodin|cinemat|dinamica/.test(n))   return { ico:'ti-atom',               cc:'#0891b2' };
  if (/quimic|organic|inorganic|estequi/.test(n))            return { ico:'ti-flask',              cc:'#7c3aed' };
  if (/biolog|anatom|celula|geneti|ecolog/.test(n))          return { ico:'ti-dna',                cc:'#059669' };
  if (/histori|edad|guerra|civilizac|contempor/.test(n))     return { ico:'ti-building-monument',  cc:'#b45309' };
  if (/geograf|mapa|clima|continen|paisaje/.test(n))         return { ico:'ti-map-2',              cc:'#0d9488' };
  if (/ingles|english|idioma|frances|aleman|chino/.test(n))  return { ico:'ti-world',              cc:'#1d4ed8' };
  if (/lengua|espanol|gramat|ortogr|sintax|morfol/.test(n))  return { ico:'ti-language',           cc:'#9333ea' };
  if (/literatur|obra|autor|novela|poesia|teatro/.test(n))   return { ico:'ti-feather',            cc:'#c026d3' };
  if (/filosof|etica|logica|epistem/.test(n))                return { ico:'ti-brain',              cc:'#7c3aed' };
  if (/economi|empresa|mercado|finanza/.test(n))             return { ico:'ti-chart-line',         cc:'#0f766e' };
  if (/tecnolog|informatic|programac|codigo/.test(n))        return { ico:'ti-cpu',                cc:'#0369a1' };
  if (/arte|plastica|dibujo|diseno|pintura/.test(n))         return { ico:'ti-palette',            cc:'#db2777' };
  if (/musica|solfeo|armonia|nota/.test(n))                  return { ico:'ti-music',              cc:'#7c3aed' };
  if (/educac.*fis|edfis|deporte|atletis/.test(n))           return { ico:'ti-run',                cc:'#16a34a' };
  if (/latin|griego|clasic/.test(n))                         return { ico:'ti-scroll',             cc:'#92400e' };
  if (/religion|religio|etica.*valor/.test(n))               return { ico:'ti-star',               cc:'#d97706' };
  if (/psicolog|sociolog/.test(n))                           return { ico:'ti-brain',              cc:'#0891b2' };
  if (/derecho|justicia|constituc/.test(n))                  return { ico:'ti-scale',              cc:'#374151' };
  return { ico:'ti-book-2', cc:'#154ca9' };
}

// ─── Iconos y colores semánticos de tema / bloque ────────────────────────────
function getTopicMeta(name) {
  const n = (name || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'');
  if (/funcion|polinomic|racional|logaritm|exponenc/.test(n)) return { ico:'ti-chart-line',         cc:'#2563eb' };
  if (/algebra|ecuacion|sistema|inecuac/.test(n))             return { ico:'ti-variable',           cc:'#7c3aed' };
  if (/geometr|triangul|circul|polig|figura/.test(n))         return { ico:'ti-triangle',           cc:'#0891b2' };
  if (/estadis|probabil|combinat|azar/.test(n))               return { ico:'ti-chart-bar',          cc:'#0d9488' };
  if (/trigon|seno|coseno|tangente/.test(n))                  return { ico:'ti-wave-sine',          cc:'#6d28d9' };
  if (/matri|determin|vector/.test(n))                        return { ico:'ti-grid-dots',          cc:'#1d4ed8' };
  if (/sucesion|progresion|serie/.test(n))                    return { ico:'ti-dots',               cc:'#0369a1' };
  if (/integral|derivad|limite|calculo/.test(n))              return { ico:'ti-sigma',              cc:'#4f46e5' };
  if (/numero|fraccion|decimal|potenci|radical/.test(n))      return { ico:'ti-numbers',            cc:'#1d4ed8' };
  if (/porcentaj|proporc|regla/.test(n))                      return { ico:'ti-percentage',         cc:'#0891b2' };
  if (/electric|circuito|corriente|voltaj|resistenc/.test(n)) return { ico:'ti-bolt',               cc:'#f59e0b' };
  if (/mecanica|fuerza|movimiento|cinemat|dinamica|energia/.test(n)) return { ico:'ti-arrows-move', cc:'#0369a1' };
  if (/optica|luz|lente|espejo|refrac/.test(n))               return { ico:'ti-eye',               cc:'#6d28d9' };
  if (/onda|vibrac|sonido|acustic/.test(n))                   return { ico:'ti-wave-square',        cc:'#0891b2' };
  if (/termodi|calor|temperatur|gas/.test(n))                 return { ico:'ti-thermometer',        cc:'#dc2626' };
  if (/magnet|campo|induccion/.test(n))                       return { ico:'ti-magnet',             cc:'#7c3aed' };
  if (/nuclear|radioact|cuantic/.test(n))                     return { ico:'ti-atom',               cc:'#059669' };
  if (/element|tabla|period/.test(n))                         return { ico:'ti-table',              cc:'#7c3aed' };
  if (/reaccion|estequio/.test(n))                            return { ico:'ti-exchange',           cc:'#0891b2' };
  if (/acido|base|ph|ion/.test(n))                            return { ico:'ti-droplet',            cc:'#dc2626' };
  if (/organica|hidrocarbur|alcohol|aldehid/.test(n))         return { ico:'ti-molecule',           cc:'#059669' };
  if (/enlace|orbital|configur/.test(n))                      return { ico:'ti-atom',               cc:'#7c3aed' };
  if (/celula|tejido|organel/.test(n))                        return { ico:'ti-dna',                cc:'#059669' };
  if (/geneti|herencia|adn|evolucion/.test(n))                return { ico:'ti-dna-2',              cc:'#16a34a' };
  if (/ecosistem|ecolog|bioma|biotop/.test(n))                return { ico:'ti-trees',              cc:'#15803d' };
  if (/anatom|cuerpo|sistem.*organ|aparato/.test(n))          return { ico:'ti-heart-rate-monitor', cc:'#dc2626' };
  if (/microb|bacteri|virus/.test(n))                         return { ico:'ti-microscope',         cc:'#0891b2' };
  if (/botanica|planta|fotosint/.test(n))                     return { ico:'ti-leaf',               cc:'#16a34a' };
  if (/guerra|conflicto|batalla/.test(n))                     return { ico:'ti-sword',              cc:'#dc2626' };
  if (/revolucion|independenc/.test(n))                       return { ico:'ti-flame',              cc:'#f59e0b' };
  if (/medieval|feud/.test(n))                                return { ico:'ti-castle',             cc:'#92400e' };
  if (/civilizac|antigua|grecia|roma/.test(n))                return { ico:'ti-building-monument',  cc:'#b45309' };
  if (/siglo|epoca|cronolog/.test(n))                         return { ico:'ti-clock-history',      cc:'#d97706' };
  if (/mapa|clima|relieve|rio|montana/.test(n))               return { ico:'ti-map-2',              cc:'#0d9488' };
  if (/sintax|oracion/.test(n))                               return { ico:'ti-binary-tree',        cc:'#7c3aed' };
  if (/gramat|morfolog|categoria/.test(n))                    return { ico:'ti-text-grammar',       cc:'#6d28d9' };
  if (/texto|redacc|escrit|composi/.test(n))                  return { ico:'ti-writing',            cc:'#9333ea' };
  if (/lectura|comprens|comentar/.test(n))                    return { ico:'ti-book-open',          cc:'#7c3aed' };
  if (/vocabular|semant|palabr/.test(n))                      return { ico:'ti-abc',                cc:'#0891b2' };
  if (/literatur|obra|genero|autor|novela|poesia/.test(n))    return { ico:'ti-feather',            cc:'#c026d3' };
  if (/introduc|concept|fundament|base/.test(n))              return { ico:'ti-rocket',             cc:'#2563eb' };
  if (/practic|ejercic|problem|activid/.test(n))              return { ico:'ti-pencil',             cc:'#059669' };
  if (/resum|sintesis|esquema/.test(n))                       return { ico:'ti-notes',              cc:'#0891b2' };
  if (/examen|evaluac|repaso/.test(n))                        return { ico:'ti-clipboard-check',    cc:'#dc2626' };
  if (/proyecto|trabajo|investig/.test(n))                    return { ico:'ti-folder',             cc:'#b45309' };
  return { ico:'ti-bookmark', cc:'#154ca9' };
}
