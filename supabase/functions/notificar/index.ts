import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import webpush from 'npm:web-push@3.6.7'

// ============================================================
// NOTIFICAR — push al dispositivo + email
//
// El cliente NO elige a quién se avisa: manda el evento y el id
// del recurso, y aquí se deduce el destinatario desde la base de
// datos. Así un profesor no puede lanzar avisos a quien quiera.
// ============================================================

const ORIGENES = [
  'https://app.nexoacademico.com',
  'https://nexoacademico.com',
  'http://localhost:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5500',
]

function cors(req: Request) {
  const origin = req.headers.get('Origin') || ''
  // Se admite el dominio propio y las direcciones de vista previa de
  // ESTE proyecto. Antes valía cualquier subdominio de netlify.app, lo
  // que dejaba entrar a sitios de terceros.
  const ok = ORIGENES.includes(origin)
    || /^https:\/\/([a-z0-9-]+\.)?nexo-app-64p\.pages\.dev$/.test(origin)
    || /^https:\/\/([a-z0-9-]+--)?nexoacademico-app\.netlify\.app$/.test(origin)
  return {
    'Access-Control-Allow-Origin': ok ? origin : 'https://app.nexoacademico.com',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

const APP_BASE_URL   = Deno.env.get('APP_BASE_URL')   || 'https://app.nexoacademico.com'
// El remitente debe pertenecer a un dominio verificado en Resend. No
// puede ser una dirección de Gmail: Google rechaza que otro servicio
// envíe en su nombre.
const FROM_EMAIL     = Deno.env.get('FROM_EMAIL')     || 'clases@nexoacademico.com'
// Si una familia responde al aviso, la respuesta va al correo de Nexo.
const REPLY_TO       = Deno.env.get('REPLY_TO')       || 'nexoacademicopremium@gmail.com'
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const VAPID_PUBLIC   = Deno.env.get('VAPID_PUBLIC_KEY')
const VAPID_PRIVATE  = Deno.env.get('VAPID_PRIVATE_KEY')
const VAPID_SUBJECT  = Deno.env.get('VAPID_SUBJECT')  || 'mailto:nexoacademicopremium@gmail.com'

if (VAPID_PUBLIC && VAPID_PRIVATE) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE)
}

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

// ── Envío push ──────────────────────────────────────────────────
async function enviarPush(usuarioIds: string[], payload: Record<string, unknown>) {
  if (!VAPID_PUBLIC || !VAPID_PRIVATE || usuarioIds.length === 0) return { enviados: 0 }

  // Respeta a quien haya apagado los avisos
  const { data: activos } = await admin
    .from('usuarios').select('id').in('id', usuarioIds).eq('notif_push', true)
  const permitidos = (activos || []).map(u => u.id)
  if (permitidos.length === 0) return { enviados: 0 }

  const { data: subs } = await admin
    .from('push_subscriptions')
    .select('id, endpoint, p256dh, auth')
    .in('usuario_id', permitidos)

  if (!subs?.length) return { enviados: 0 }

  const cuerpo = JSON.stringify(payload)
  let enviados = 0
  const caducadas: string[] = []
  const errores: string[] = []

  await Promise.all(subs.map(async (s) => {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        cuerpo,
      )
      enviados++
    } catch (e: any) {
      // 404/410 = el navegador ya no acepta ese endpoint: se limpia.
      if (e?.statusCode === 404 || e?.statusCode === 410) {
        caducadas.push(s.id)
      } else {
        // Se devuelve el motivo real: sin esto el fallo es invisible
        // y no hay forma de saber por qué no llega nada.
        const motivo = `${e?.statusCode || ''} ${e?.body || e?.message || e}`.trim()
        console.error('Push fallido:', motivo)
        errores.push(motivo.slice(0, 300))
      }
    }
  }))

  if (caducadas.length) {
    await admin.from('push_subscriptions').delete().in('id', caducadas)
  }
  return {
    enviados,
    limpiadas: caducadas.length,
    suscripciones: subs.length,
    ...(errores.length ? { errores } : {}),
  }
}

// ── Envío email ─────────────────────────────────────────────────
// Cada tipo de aviso tiene su propia identidad en el correo: color,
// icono y antetítulo. Así la familia reconoce de un vistazo de qué va
// antes de leerlo.
const ESTILO_EVENTO: Record<string, { color: string; suave: string; etiqueta: string; icono: string }> = {
  sesion_registrada: {
    color: '#c9973a', suave: '#2e2409', etiqueta: 'Pendiente de confirmar',
    icono: '<path d="M3 9h18M7 3v4M17 3v4"/><rect x="3" y="5" width="18" height="16" rx="2"/><path d="m9 14 2 2 4-4"/>',
  },
  informe_publicado: {
    color: '#6eaef0', suave: '#0f2240', etiqueta: 'Informe del periodo',
    icono: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M8 13h8M8 17h5"/>',
  },
  test_asignado: {
    color: '#9b7ef0', suave: '#1a0f35', etiqueta: 'Nuevo test',
    icono: '<path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>',
  },
  tarea_asignada: {
    color: '#f0a14a', suave: '#2e1c07', etiqueta: 'Nueva tarea',
    icono: '<rect x="4" y="4" width="16" height="17" rx="2"/><path d="M9 2h6v4H9z"/><path d="M8 12h8M8 16h5"/>',
  },
  tarea_corregida: {
    color: '#34d399', suave: '#0d2d1e', etiqueta: 'Tarea corregida',
    icono: '<path d="M22 11.1V12a10 10 0 1 1-5.9-9.1"/><path d="M22 4 12 14.01l-3-3"/>',
  },
  material_asignado: {
    color: '#6eaef0', suave: '#0f2240', etiqueta: 'Material nuevo',
    icono: '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>',
  },
  bono_actualizado: {
    color: '#f0c674', suave: '#2e2409', etiqueta: 'Tus horas',
    icono: '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/>',
  },
  aviso_admin: {
    color: '#6eaef0', suave: '#0f2240', etiqueta: 'Aviso de Nexo',
    icono: '<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>',
  },
  test_entregado: {
    color: '#34d399', suave: '#0d2d1e', etiqueta: 'Test completado',
    icono: '<path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>',
  },
  tarea_entregada: {
    color: '#34d399', suave: '#0d2d1e', etiqueta: 'Entrega recibida',
    icono: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/><path d="M12 15V3"/>',
  },
  profesor_asignado: {
    color: '#9b7ef0', suave: '#1a0f35', etiqueta: 'Tu profesor',
    icono: '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  },
  prueba: {
    color: '#6eaef0', suave: '#0f2240', etiqueta: 'Prueba',
    icono: '<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>',
  },
}

// Antetítulos en inglés, para cuando la familia usa ese idioma.
const ETIQUETA_EN: Record<string,string> = {
  "sesion_registrada": "Waiting for confirmation",
  "informe_publicado": "Progress report",
  "test_asignado": "New quiz",
  "tarea_asignada": "New assignment",
  "tarea_corregida": "Assignment marked",
  "material_asignado": "New materials",
  "bono_actualizado": "Your hours",
  "aviso_admin": "Notice from Nexo",
  "test_entregado": "Quiz completed",
  "tarea_entregada": "Work received",
  "profesor_asignado": "Your tutor",
  "prueba": "Test"
}

const ESTILO_POR_DEFECTO = ESTILO_EVENTO.aviso_admin

function plantillaEmailPorEvento(
  evento: string, titulo: string, cuerpo: string, url: string, cta: string,
  nombre: string, idioma = 'es',
) {
  const e = ESTILO_EVENTO[evento] || ESTILO_POR_DEFECTO
  const etiqueta = idioma === 'en' ? (ETIQUETA_EN[evento] || e.etiqueta) : e.etiqueta
  const saludo = nombre
    ? (idioma === 'en'
        ? `Hi <b style="color:#fff">${nombre}</b>,`
        : `Hola, <b style="color:#fff">${nombre}</b>.`)
    : ''

  return `<!DOCTYPE html><html lang="${idioma}"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${titulo}</title></head>
<body style="margin:0;padding:0;background:#060d20;font-family:'Helvetica Neue',Arial,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#060d20;padding:40px 20px"><tr><td align="center">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px">

  <tr><td align="center" style="padding-bottom:30px">
    <span style="color:#fff;font-size:21px;font-weight:700;letter-spacing:3px">NEXO</span>
    <span style="color:#6eaef0;font-size:10px;letter-spacing:4px;text-transform:uppercase;display:block;margin-top:3px">Académico</span>
  </td></tr>

  <tr><td style="background:#0a1530;border:1px solid #1a2a4a;border-top:3px solid ${e.color};border-radius:14px;padding:34px">

    <table cellpadding="0" cellspacing="0" style="margin-bottom:18px"><tr>
      <td width="44" style="vertical-align:middle">
        <div style="width:44px;height:44px;border-radius:11px;background:${e.suave};text-align:center;line-height:44px">
          <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="${e.color}" stroke-width="1.9"
               stroke-linecap="round" stroke-linejoin="round" style="vertical-align:middle">${e.icono}</svg>
        </div>
      </td>
      <td style="padding-left:13px;vertical-align:middle">
        <div style="color:${e.color};font-size:10.5px;letter-spacing:.14em;text-transform:uppercase;font-weight:700">${etiqueta}</div>
      </td>
    </tr></table>

    <h1 style="color:#fff;font-size:20px;font-weight:700;margin:0 0 12px;line-height:1.3">${titulo}</h1>
    ${saludo ? `<p style="color:#a8c8f0;font-size:14px;margin:0 0 8px">${saludo}</p>` : ''}
    <p style="color:#a8c8f0;font-size:14px;margin:0 0 26px;line-height:1.6">${cuerpo}</p>

    <a href="${url}" style="display:block;background:${e.color};color:#04071b;text-decoration:none;padding:14px;border-radius:9px;font-size:14px;font-weight:700;text-align:center">${cta}</a>
  </td></tr>

  <tr><td align="center" style="padding-top:22px">
    <p style="color:#4a6080;font-size:11px;margin:0;line-height:1.8">
      Nexo Académico · Valencia · 699 52 93 99<br>
      <a href="https://nexoacademico.com" style="color:#6eaef0;text-decoration:none">nexoacademico.com</a>
    </p>
  </td></tr>

</table></td></tr></table></body></html>`
}


async function enviarEmail(
  usuarioIds: string[], asunto: string, titulo: string,
  cuerpo: string, url: string, cta: string, evento: string, idioma = "es",
) {
  if (!RESEND_API_KEY || usuarioIds.length === 0) return { enviados: 0 }

  const { data: destinatarios } = await admin
    .from('usuarios').select('email, nombre').in('id', usuarioIds).eq('notif_email', true)

  // Al dar de alta se asigna un correo interno (@nexo.internal) que solo
  // sirve para entrar. No es una dirección real: enviarle rebota, y los
  // rebotes queman la reputación del dominio remitente.
  const validos = (destinatarios || [])
    .filter(u => u.email && !u.email.endsWith('@nexo.internal'))
  if (!validos.length) return { enviados: 0, motivo: 'sin correo real' }

  let enviados = 0

  await Promise.all(validos.map(async (u) => {
    try {
      // El correo se compone por destinatario: cada uno lleva su nombre.
      const html = plantillaEmailPorEvento(evento, titulo, cuerpo, url, cta, u.nombre || '', idioma)
      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from: `Nexo Académico <${FROM_EMAIL}>`, reply_to: REPLY_TO, to: [u.email], subject: asunto, html }),
      })
      if (r.ok) enviados++
      else console.error('Resend:', await r.text())
    } catch (e) { console.error('Email fallido:', e) }
  }))

  return { enviados, destinatarios_con_correo: validos.length }
}

const esc = (s: unknown) => String(s ?? '')
  .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')

// ── Textos en dos idiomas ───────────────────────────────────────
// El texto del aviso se compone antes de saber a quién va dirigido, así
// que M() guarda las dos versiones y se elige la buena al final, cuando
// ya se conoce el idioma del destinatario.
function M(es: string, en: string) {
  return { __dosIdiomas: true, es, en }
}

function resolver(v: any, idioma: string): string {
  if (v && typeof v === 'object' && v.__dosIdiomas) return v[idioma] || v.es
  return v
}

// Idioma de los destinatarios. Si son varios y no coinciden, manda el
// del primero: en la práctica cada aviso va a una sola persona, salvo
// los avisos generales, cuyo texto escribe el admin a mano.
async function idiomaDe(usuarioIds: string[]): Promise<string> {
  if (!usuarioIds.length) return 'es'
  const { data } = await admin
    .from('usuarios').select('idioma').in('id', usuarioIds).limit(1)
  return data?.[0]?.idioma === 'en' ? 'en' : 'es'
}

serve(async (req) => {
  const H = cors(req)
  if (req.method === 'OPTIONS') return new Response('ok', { headers: H })

  // Autodiagnóstico. Va protegido con un fragmento de la clave privada,
  // para que no quede al aire la configuración del proyecto.
  const _clave = new URL(req.url).searchParams.get('diag')
  if (_clave && VAPID_PRIVATE && _clave === VAPID_PRIVATE.slice(0, 10)) {
    const res: Record<string, unknown> = {
      vapid_publica_puesta: !!VAPID_PUBLIC,
      vapid_privada_puesta: !!VAPID_PRIVATE,
      resend_puesta: !!RESEND_API_KEY,
      app_base_url: APP_BASE_URL,
    }
    try {
      // Cifrar contra un endpoint falso obliga a la librería a hacer toda
      // la criptografía; si el runtime no la soporta, revienta aquí.
      await webpush.sendNotification({
        endpoint: 'https://fcm.googleapis.com/fcm/send/DIAGNOSTICO-FALSO',
        keys: {
          p256dh: 'BGJbgWxtkjdHeVVk9F4UtzXh02sGvJG93PzBjNQ1NHEX8y56VVdOyiBIzNp5M6LNz7pFxtm807Y6gDBUD1oU6TI',
          auth: 'Fs4hzFeGxbheE51iXoVo-Q',
        },
      }, JSON.stringify({ t: 'diag' }))
      res.criptografia = 'OK (envío aceptado)'
    } catch (e: any) {
      // Un 4xx del servidor push significa que la criptografía funcionó
      // y solo falló el destinatario falso: eso es lo que buscamos.
      if (e?.statusCode) res.criptografia = `OK (la librería firmó; el destino falso devolvió ${e.statusCode})`
      else res.criptografia = `FALLA EN ESTE RUNTIME: ${e?.message || e}`
    }
    // Recuento agregado de dispositivos. Solo números y tipo de aparato:
    // ningún dato que identifique a nadie.
    const { data: subs } = await admin
      .from('push_subscriptions').select('endpoint, user_agent, usuario_id')
    const { data: apagados } = await admin
      .from('usuarios').select('id').eq('notif_push', false)

    res.dispositivos = (subs || []).length
    res.usuarios_distintos = new Set((subs || []).map(s => s.usuario_id)).size
    res.usuarios_con_avisos_apagados = (apagados || []).length
    // El rol es la pieza clave: un aviso de material va al alumno, así que
    // si en el móvil hay iniciada la sesión de admin, no llega nada.
    const { data: perfiles } = await admin
      .from('usuarios').select('id, rol, nombre, apellidos')
      .in('id', [...new Set((subs || []).map(s => s.usuario_id))])
    const rolDe = Object.fromEntries((perfiles || []).map(u =>
      [u.id, `${u.rol} ${u.nombre || ''} ${u.apellidos || ''}`.trim()]))

    res.tipo_de_aparato = (subs || []).map(s => {
      const ua = s.user_agent || ''
      const movil = /Android|iPhone|iPad|Mobile/i.test(ua) ? 'móvil' : 'escritorio'
      const nav = /Edg\//.test(ua) ? 'Edge' : /Chrome/.test(ua) ? 'Chrome'
                : /Firefox/.test(ua) ? 'Firefox' : /Safari/.test(ua) ? 'Safari' : 'otro'
      const serv = s.endpoint.includes('fcm.googleapis') ? 'Google'
                 : s.endpoint.includes('mozilla') ? 'Mozilla'
                 : s.endpoint.includes('push.apple') ? 'Apple' : 'otro'
      return `${movil} · ${nav} · vía ${serv} · sesión de ${rolDe[s.usuario_id] || '?'}`
    })

    // Cuántos alumnos podrían recibir avisos, de todos los que hay
    const { data: todosAlumnos } = await admin
      .from('usuarios').select('id').eq('rol', 'alumno').eq('activo', true)
    const conDispositivo = new Set((subs || []).map(s => s.usuario_id))
    res.alumnos_totales = (todosAlumnos || []).length
    res.alumnos_con_avisos = (todosAlumnos || []).filter(a => conDispositivo.has(a.id)).length

    // Envío real de prueba a todos los dispositivos. Va protegido por un
    // fragmento de la clave privada: solo lo dispara quien tiene acceso
    // a los secrets del proyecto.
    const clave = new URL(req.url).searchParams.get('enviar')
    if (clave && VAPID_PRIVATE && clave === VAPID_PRIVATE.slice(0, 10)) {
      const usuarios = [...new Set((subs || []).map(s => s.usuario_id))]
      res.envio_de_prueba = await enviarPush(usuarios, {
        titulo: 'Prueba de Nexo Académico',
        cuerpo: 'Si ves esto, los avisos funcionan.',
        url: APP_BASE_URL,
        tag: 'nexo-diag',
      })
    }

    // Estado de los correos: quién tiene dirección real y quién no.
    const { data: todos } = await admin
      .from('usuarios').select('rol, email, notif_email').eq('activo', true)
    const reales = (todos || []).filter(u => u.email && !u.email.endsWith('@nexo.internal'))
    res.remitente = FROM_EMAIL
    res.usuarios_con_correo_real = reales.length
    res.usuarios_con_correo_interno = (todos || []).length - reales.length
    res.usuarios_con_email_apagado = (todos || []).filter(u => !u.notif_email).length

    // Envío real de prueba, para ver qué responde Resend palabra por palabra.
    const destino = new URL(req.url).searchParams.get('email')
    if (destino && RESEND_API_KEY) {
      try {
        const r = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            from: `Nexo Académico <${FROM_EMAIL}>`,
            reply_to: REPLY_TO,
            to: [destino],
            subject: 'Prueba de correo — Nexo Académico',
            html: plantillaEmailPorEvento('prueba', 'Los correos funcionan',
              'Si estás leyendo esto, el envío de correos está bien configurado.',
              APP_BASE_URL, 'Abrir Nexo', ''),
          }),
        })
        res.prueba_email = { estado: r.status, respuesta: (await r.text()).slice(0, 400) }
      } catch (e: any) {
        res.prueba_email = { error: e?.message || String(e) }
      }
    }

    return new Response(JSON.stringify(res, null, 2),
      { headers: { ...H, 'Content-Type': 'application/json' } })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Sin autorización' }), { status: 401, headers: H })
    }

    const caller = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user } } = await caller.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Token inválido' }), { status: 401, headers: H })
    }

    const { data: perfil } = await admin
      .from('usuarios').select('rol, nombre, apellidos').eq('id', user.id).single()
    const rol = perfil?.rol
    const quien = `${perfil?.nombre || ''} ${perfil?.apellidos || ''}`.trim() || 'Alguien'

    const { evento, id } = await req.json()
    if (!evento) {
      return new Response(JSON.stringify({ error: 'Falta el evento' }), { status: 400, headers: H })
    }
    // 'prueba' es el único evento sin recurso: se envía a uno mismo.
    if (!id && evento !== 'prueba') {
      return new Response(JSON.stringify({ error: 'Falta el id' }), { status: 400, headers: H })
    }

    let destinatarios: string[] = []
    let titulo = '', cuerpo = '', url = APP_BASE_URL, cta = 'Abrir Nexo', asunto = '', tag = evento
    let importante = false

    // ── PRUEBA → a uno mismo ───────────────────────────────────
    // Sirve para comprobar que el canal funciona, sin depender de
    // que haya un alumno, un material o una sesión de por medio.
    if (evento === 'prueba') {
      destinatarios = [user.id]
      titulo = M('Los avisos funcionan', 'Notifications are working')
      cuerpo = M('Si estás leyendo esto en tu móvil, las notificaciones están bien configuradas.', 'If you are reading this on your phone, notifications are set up correctly.')
      asunto = M('Prueba de avisos — Nexo Académico', 'Notification test — Nexo Académico')
      cta    = M('Abrir Nexo', 'Open Nexo')
      tag    = 'nexo-prueba'

    // ── SESIÓN REGISTRADA → al alumno ──────────────────────────
    } else if (evento === 'sesion_registrada') {
      const { data: ses } = await admin
        .from('sesiones')
        .select('id, asignatura, fecha, profesor_id, alumno:alumnos(usuario_id)')
        .eq('id', id).single()
      if (!ses) return new Response(JSON.stringify({ error: 'Sesión no encontrada' }), { status: 404, headers: H })

      // Solo el profesor de esa sesión, o el admin
      if (rol !== 'admin') {
        const { data: prof } = await admin
          .from('profesores').select('id').eq('usuario_id', user.id).single()
        if (!prof || prof.id !== ses.profesor_id) {
          return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 403, headers: H })
        }
      }

      const uid = (ses.alumno as any)?.usuario_id
      if (uid) destinatarios = [uid]
      titulo = M('Tienes una sesión por confirmar', 'You have a session to confirm')
      cuerpo = M(`${esc(quien)} ha registrado una sesión de ${esc(ses.asignatura)}. Entra y confírmala.`, `${esc(quien)} has logged a ${esc(ses.asignatura)} session. Please go in and confirm it.`)
      asunto = M(`Confirma tu clase de ${ses.asignatura}`, `Confirm your ${ses.asignatura} lesson`)
      url    = `${APP_BASE_URL}/alumno/`
      cta    = M('Confirmar la sesión', 'Confirm the session')
      importante = true

    // ── TEST O TAREA ENTREGADA → al profesor ───────────────────
    } else if (evento === 'test_entregado') {
      const { data: test } = await admin
        .from('tests').select('id, titulo, creado_por').eq('id', id).single()
      if (!test) return new Response(JSON.stringify({ error: 'Test no encontrado' }), { status: 404, headers: H })

      if (test.creado_por) destinatarios = [test.creado_por]
      titulo = M('Test completado', 'Quiz completed')
      cuerpo = M(`${esc(quien)} ha completado el test "${esc(test.titulo)}".`, `${esc(quien)} has completed the quiz "${esc(test.titulo)}".`)
      asunto = M(`${quien} ha completado un test`, `${quien} has completed a quiz`)
      url    = `${APP_BASE_URL}/profesor/`
      cta    = M('Ver el resultado', 'See the result')

    } else if (evento === 'tarea_entregada') {
      const { data: tarea } = await admin
        .from('tareas').select('id, titulo, profesor_id, profesor:profesores(usuario_id)')
        .eq('id', id).single()
      if (!tarea) return new Response(JSON.stringify({ error: 'Tarea no encontrada' }), { status: 404, headers: H })

      const uid = (tarea.profesor as any)?.usuario_id
      if (uid) destinatarios = [uid]
      titulo = M('Tarea entregada', 'Assignment handed in')
      cuerpo = M(`${esc(quien)} ha entregado la tarea "${esc(tarea.titulo)}".`, `${esc(quien)} has handed in "${esc(tarea.titulo)}".`)
      asunto = M(`${quien} ha entregado una tarea`, `${quien} has handed in an assignment`)
      url    = `${APP_BASE_URL}/profesor/`
      cta    = M('Ver la entrega', 'See the work')

    // ── TEST ASIGNADO → al alumno ──────────────────────────────
    } else if (evento === 'test_asignado') {
      const { data: test } = await admin
        .from('tests').select('id, titulo, alumno_id, creado_por, alumno:alumnos(usuario_id)')
        .eq('id', id).single()
      if (!test) return new Response(JSON.stringify({ error: 'Test no encontrado' }), { status: 404, headers: H })
      if (rol !== 'admin' && test.creado_por !== user.id) {
        return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 403, headers: H })
      }
      const uid = (test.alumno as any)?.usuario_id
      if (uid) destinatarios = [uid]
      titulo = M('Tienes un test nuevo', 'You have a new quiz')
      cuerpo = M(`${esc(quien)} te ha asignado el test "${esc(test.titulo)}".`, `${esc(quien)} has set you the quiz "${esc(test.titulo)}".`)
      asunto = M(`Nuevo test: ${test.titulo}`, `New quiz: ${test.titulo}`)
      url    = `${APP_BASE_URL}/alumno/`
      cta    = M('Hacer el test', 'Take the quiz')

    // ── TAREA ASIGNADA → al alumno ─────────────────────────────
    } else if (evento === 'tarea_asignada') {
      const { data: tarea } = await admin
        .from('tareas').select('id, titulo, fecha_limite, profesor_id, alumno:alumnos(usuario_id)')
        .eq('id', id).single()
      if (!tarea) return new Response(JSON.stringify({ error: 'Tarea no encontrada' }), { status: 404, headers: H })
      if (rol !== 'admin') {
        const { data: prof } = await admin
          .from('profesores').select('id').eq('usuario_id', user.id).single()
        if (!prof || prof.id !== tarea.profesor_id) {
          return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 403, headers: H })
        }
      }
      const uid = (tarea.alumno as any)?.usuario_id
      if (uid) destinatarios = [uid]
      const plazo = tarea.fecha_limite
        ? ` Entrega antes del ${new Date(tarea.fecha_limite + 'T00:00:00').toLocaleDateString('es-ES', { day: 'numeric', month: 'long' })}.`
        : ''
      const plazoEn = tarea.fecha_limite
        ? ` Due by ${new Date(tarea.fecha_limite + 'T00:00:00').toLocaleDateString('en-GB', { day: 'numeric', month: 'long' })}.`
        : ''
      titulo = M('Tienes una tarea nueva', 'You have a new assignment')
      cuerpo = M(`${esc(quien)} te ha puesto "${esc(tarea.titulo)}".${plazo}`, `${esc(quien)} has set you "${esc(tarea.titulo)}".${plazoEn}`)
      asunto = M(`Nueva tarea: ${tarea.titulo}`, `New assignment: ${tarea.titulo}`)
      url    = `${APP_BASE_URL}/alumno/`
      cta    = M('Ver la tarea', 'See the assignment')

    // ── TAREA CORREGIDA → al alumno ────────────────────────────
    } else if (evento === 'tarea_corregida') {
      const { data: tarea } = await admin
        .from('tareas').select('id, titulo, nota, profesor_id, alumno:alumnos(usuario_id)')
        .eq('id', id).single()
      if (!tarea) return new Response(JSON.stringify({ error: 'Tarea no encontrada' }), { status: 404, headers: H })
      if (rol !== 'admin') {
        const { data: prof } = await admin
          .from('profesores').select('id').eq('usuario_id', user.id).single()
        if (!prof || prof.id !== tarea.profesor_id) {
          return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 403, headers: H })
        }
      }
      const uid = (tarea.alumno as any)?.usuario_id
      if (uid) destinatarios = [uid]
      const nota   = tarea.nota != null ? ` Nota: ${tarea.nota}.` : ''
      const notaEn = tarea.nota != null ? ` Grade: ${tarea.nota}.` : ''
      titulo = M('Tu tarea ya está corregida', 'Your assignment has been marked')
      cuerpo = M(`${esc(quien)} ha corregido "${esc(tarea.titulo)}".${nota}`, `${esc(quien)} has marked "${esc(tarea.titulo)}".${notaEn}`)
      asunto = M(`Tarea corregida: ${tarea.titulo}`, `Assignment marked: ${tarea.titulo}`)
      url    = `${APP_BASE_URL}/alumno/`
      cta    = M('Ver la corrección', 'See the feedback')

    // ── BONO NUEVO → al alumno ─────────────────────────────────
    } else if (evento === 'bono_actualizado') {
      if (rol !== 'admin') {
        return new Response(JSON.stringify({ error: 'Solo el administrador' }), { status: 403, headers: H })
      }
      const { data: bono } = await admin
        .from('bonos').select('id, horas_contratadas, estado, alumno:alumnos(usuario_id)')
        .eq('id', id).single()
      if (!bono) return new Response(JSON.stringify({ error: 'Bono no encontrado' }), { status: 404, headers: H })

      const uid = (bono.alumno as any)?.usuario_id
      if (uid) destinatarios = [uid]
      titulo = bono.estado === 'activo'
        ? M('Tu bono ya está activo', 'Your hour pack is now active')
        : M('Tienes un bono nuevo', 'You have a new hour pack')
      cuerpo = bono.estado === 'activo'
        ? `Se han añadido ${bono.horas_contratadas}h a tu bono. Ya puedes usarlas.`
        : `Se ha registrado un bono de ${bono.horas_contratadas}h. Se activará cuando termines el actual.`
      asunto = M('Tu bono de Nexo Académico', 'Your Nexo Académico hour pack')
      url    = `${APP_BASE_URL}/alumno/`
      cta    = M('Ver mis horas', 'See my hours')

    // ── PROFESOR ASIGNADO → al alumno ──────────────────────────
    } else if (evento === 'profesor_asignado') {
      if (rol !== 'admin') {
        return new Response(JSON.stringify({ error: 'Solo el administrador' }), { status: 403, headers: H })
      }
      const { data: rel } = await admin
        .from('alumno_profesor')
        .select('id, alumno:alumnos(usuario_id), profesor:profesores(usuario:usuarios(nombre, apellidos)), asignaturas(nombre)')
        .eq('id', id).single()
      if (!rel) return new Response(JSON.stringify({ error: 'Asignación no encontrada' }), { status: 404, headers: H })

      const uid = (rel.alumno as any)?.usuario_id
      if (uid) destinatarios = [uid]
      const pu   = (rel.profesor as any)?.usuario
      const prof = pu ? `${pu.nombre || ''} ${pu.apellidos || ''}`.trim() : 'un profesor'
      const asig = (rel as any).asignaturas?.nombre
      titulo = M('Ya tienes profesor asignado', 'You have been assigned a tutor')
      cuerpo = asig
        ? `${esc(prof)} será tu profesor de ${esc(asig)}.`
        : `${esc(prof)} será tu profesor.`
      asunto = M('Tu profesor en Nexo Académico', 'Your tutor at Nexo Académico')
      url    = `${APP_BASE_URL}/alumno/`
      cta    = M('Ver mi profesor', 'See my tutor')

    // ── MATERIAL ASIGNADO → a los alumnos que lo reciben ───────
    } else if (evento === 'material_asignado') {
      const { data: mat } = await admin
        .from('material').select('id, titulo, subido_por').eq('id', id).single()
      if (!mat) return new Response(JSON.stringify({ error: 'Material no encontrado' }), { status: 404, headers: H })

      // Solo quien lo subió, o el admin
      if (rol !== 'admin' && mat.subido_por !== user.id) {
        return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 403, headers: H })
      }

      const { data: asignaciones } = await admin
        .from('material_alumno')
        .select('alumno:alumnos(usuario_id)')
        .eq('material_id', id)

      destinatarios = (asignaciones || [])
        .map((a: any) => a.alumno?.usuario_id)
        .filter(Boolean)

      titulo = M('Nuevo material disponible', 'New materials available')
      cuerpo = M(`${esc(quien)} ha subido "${esc(mat.titulo)}" a tu material.`, `${esc(quien)} has uploaded "${esc(mat.titulo)}" to your materials.`)
      asunto = M(`Nuevo material: ${mat.titulo}`, `New materials: ${mat.titulo}`)
      url    = `${APP_BASE_URL}/alumno/`
      cta    = M('Ver el material', 'See the materials')

    // ── AVISO DEL ADMIN → por rol o a una persona ──────────────
    } else if (evento === 'aviso_admin') {
      if (rol !== 'admin') {
        return new Response(JSON.stringify({ error: 'Solo el administrador' }), { status: 403, headers: H })
      }
      const { data: aviso } = await admin
        .from('avisos').select('id, titulo, contenido, destinatario_id, destinatario_rol')
        .eq('id', id).single()
      if (!aviso) return new Response(JSON.stringify({ error: 'Aviso no encontrado' }), { status: 404, headers: H })

      if (aviso.destinatario_id) {
        destinatarios = [aviso.destinatario_id]
      } else {
        const q = admin.from('usuarios').select('id').eq('activo', true)
        const { data: us } = aviso.destinatario_rol && aviso.destinatario_rol !== 'todos'
          ? await q.eq('rol', aviso.destinatario_rol)
          : await q.in('rol', ['alumno', 'profesor'])
        destinatarios = (us || []).map(u => u.id)
      }

      titulo = aviso.titulo || 'Aviso de Nexo Académico'
      cuerpo = esc(aviso.contenido || '').slice(0, 300)
      asunto = titulo
      cta    = M('Leer el aviso', 'Read the notice')

    // ── INFORME PUBLICADO → al alumno ──────────────────────────
    } else if (evento === 'informe_publicado') {
      if (rol !== 'admin') {
        return new Response(JSON.stringify({ error: 'Solo el administrador' }), { status: 403, headers: H })
      }
      const { data: inf } = await admin
        .from('informes').select('id, titulo, alumno:alumnos(usuario_id)')
        .eq('id', id).single()
      if (!inf) return new Response(JSON.stringify({ error: 'Informe no encontrado' }), { status: 404, headers: H })

      // Se avisa cada vez que se publica, aunque ya se hubiera avisado
      // antes: es preferible repetir a que el alumno no se entere.
      const uid = (inf.alumno as any)?.usuario_id
      if (uid) destinatarios = [uid]
      titulo = M('Tu informe ya está disponible', 'Your report is ready')
      cuerpo = M(`Ya puedes descargar "${esc(inf.titulo)}" desde tu panel.`, `You can now download "${esc(inf.titulo)}" from your dashboard.`)
      asunto = M('Tu informe de Nexo Académico ya está disponible', 'Your Nexo Académico report is ready')
      url    = `${APP_BASE_URL}/alumno/`
      cta    = M('Descargar el informe', 'Download the report')

    } else {
      return new Response(JSON.stringify({ error: 'Evento desconocido' }), { status: 400, headers: H })
    }

    if (!destinatarios.length) {
      return new Response(JSON.stringify({ ok: true, aviso: 'Sin destinatarios' }),
        { headers: { ...H, 'Content-Type': 'application/json' } })
    }

    // Ya se sabe a quién va: se eligen las versiones del idioma correcto.
    const idiomaDest = await idiomaDe(destinatarios)
    const tituloF = resolver(titulo, idiomaDest)
    const cuerpoF = resolver(cuerpo, idiomaDest)
    const asuntoF = resolver(asunto, idiomaDest)
    const ctaF    = resolver(cta,    idiomaDest)

    const [push, email] = await Promise.all([
      enviarPush(destinatarios, { titulo: tituloF, cuerpo: cuerpoF, url, tag, importante }),
      enviarEmail(destinatarios, asuntoF, tituloF, cuerpoF, url, ctaF, evento, idiomaDest),
    ])

    return new Response(JSON.stringify({ ok: true, push, email }),
      { headers: { ...H, 'Content-Type': 'application/json' } })

  } catch (err: any) {
    console.error('notificar error:', err)
    return new Response(JSON.stringify({ error: err?.message || 'Error desconocido' }),
      { status: 500, headers: H })
  }
})
