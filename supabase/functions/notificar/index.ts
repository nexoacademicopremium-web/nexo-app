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
  const ok = ORIGENES.includes(origin) || origin.endsWith('.netlify.app')
  return {
    'Access-Control-Allow-Origin': ok ? origin : 'https://app.nexoacademico.com',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

const APP_BASE_URL   = Deno.env.get('APP_BASE_URL')   || 'https://app.nexoacademico.com'
const FROM_EMAIL     = Deno.env.get('FROM_EMAIL')     || 'clases@nexoacademico.es'
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

  await Promise.all(subs.map(async (s) => {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        cuerpo,
      )
      enviados++
    } catch (e: any) {
      // 404/410 = el navegador ya no acepta ese endpoint: se limpia.
      if (e?.statusCode === 404 || e?.statusCode === 410) caducadas.push(s.id)
      else console.error('Push fallido:', e?.statusCode, e?.body || e?.message)
    }
  }))

  if (caducadas.length) {
    await admin.from('push_subscriptions').delete().in('id', caducadas)
  }
  return { enviados, limpiadas: caducadas.length }
}

// ── Envío email ─────────────────────────────────────────────────
function plantillaEmail(titulo: string, cuerpo: string, url: string, cta: string) {
  return `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#060d20;font-family:'Helvetica Neue',Arial,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#060d20;padding:40px 20px"><tr><td align="center">
<table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px">
<tr><td align="center" style="padding-bottom:32px">
  <span style="color:#fff;font-size:22px;font-weight:700;letter-spacing:2px">NEXO</span>
  <span style="color:#6eaef0;font-size:11px;letter-spacing:3px;text-transform:uppercase;display:block;margin-top:2px">Académico</span>
</td></tr>
<tr><td style="background:#0a1530;border:1px solid #1a2a4a;border-radius:14px;padding:36px">
  <h1 style="color:#fff;font-size:20px;font-weight:700;margin:0 0 14px">${titulo}</h1>
  <p style="color:#a8c8f0;font-size:14px;margin:0 0 28px;line-height:1.6">${cuerpo}</p>
  <a href="${url}" style="display:block;background:#154ca9;color:#fff;text-decoration:none;padding:14px;border-radius:8px;font-size:14px;font-weight:700;text-align:center">${cta}</a>
</td></tr>
<tr><td align="center" style="padding-top:24px">
  <p style="color:#4a6080;font-size:11px;margin:0;line-height:1.8">Nexo Académico · Valencia<br>
  <a href="https://nexoacademico.com" style="color:#6eaef0;text-decoration:none">nexoacademico.com</a></p>
</td></tr>
</table></td></tr></table></body></html>`
}

async function enviarEmail(usuarioIds: string[], asunto: string, titulo: string, cuerpo: string, url: string, cta: string) {
  if (!RESEND_API_KEY || usuarioIds.length === 0) return { enviados: 0 }

  const { data: destinatarios } = await admin
    .from('usuarios').select('email').in('id', usuarioIds).eq('notif_email', true)

  const correos = (destinatarios || []).map(u => u.email).filter(Boolean)
  if (!correos.length) return { enviados: 0 }

  const html = plantillaEmail(titulo, cuerpo, url, cta)
  let enviados = 0

  await Promise.all(correos.map(async (to) => {
    try {
      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from: `Nexo Académico <${FROM_EMAIL}>`, to: [to], subject: asunto, html }),
      })
      if (r.ok) enviados++
      else console.error('Resend:', await r.text())
    } catch (e) { console.error('Email fallido:', e) }
  }))

  return { enviados }
}

const esc = (s: unknown) => String(s ?? '')
  .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')

serve(async (req) => {
  const H = cors(req)
  if (req.method === 'OPTIONS') return new Response('ok', { headers: H })

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
    if (!evento || !id) {
      return new Response(JSON.stringify({ error: 'Faltan evento o id' }), { status: 400, headers: H })
    }

    let destinatarios: string[] = []
    let titulo = '', cuerpo = '', url = APP_BASE_URL, cta = 'Abrir Nexo', asunto = '', tag = evento
    let importante = false

    // ── SESIÓN REGISTRADA → al alumno ──────────────────────────
    if (evento === 'sesion_registrada') {
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
      titulo = 'Tienes una sesión por confirmar'
      cuerpo = `${esc(quien)} ha registrado una sesión de ${esc(ses.asignatura)}. Entra y confírmala.`
      asunto = `Confirma tu clase de ${ses.asignatura}`
      url    = `${APP_BASE_URL}/alumno/`
      cta    = 'Confirmar la sesión'
      importante = true

    // ── TEST O TAREA ENTREGADA → al profesor ───────────────────
    } else if (evento === 'test_entregado') {
      const { data: test } = await admin
        .from('tests').select('id, titulo, creado_por').eq('id', id).single()
      if (!test) return new Response(JSON.stringify({ error: 'Test no encontrado' }), { status: 404, headers: H })

      if (test.creado_por) destinatarios = [test.creado_por]
      titulo = 'Test completado'
      cuerpo = `${esc(quien)} ha completado el test "${esc(test.titulo)}".`
      asunto = `${quien} ha completado un test`
      url    = `${APP_BASE_URL}/profesor/`
      cta    = 'Ver el resultado'

    } else if (evento === 'tarea_entregada') {
      const { data: tarea } = await admin
        .from('tareas').select('id, titulo, profesor_id, profesor:profesores(usuario_id)')
        .eq('id', id).single()
      if (!tarea) return new Response(JSON.stringify({ error: 'Tarea no encontrada' }), { status: 404, headers: H })

      const uid = (tarea.profesor as any)?.usuario_id
      if (uid) destinatarios = [uid]
      titulo = 'Tarea entregada'
      cuerpo = `${esc(quien)} ha entregado la tarea "${esc(tarea.titulo)}".`
      asunto = `${quien} ha entregado una tarea`
      url    = `${APP_BASE_URL}/profesor/`
      cta    = 'Ver la entrega'

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

      titulo = 'Nuevo material disponible'
      cuerpo = `${esc(quien)} ha subido "${esc(mat.titulo)}" a tu material.`
      asunto = `Nuevo material: ${mat.titulo}`
      url    = `${APP_BASE_URL}/alumno/`
      cta    = 'Ver el material'

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
      cta    = 'Leer el aviso'

    // ── INFORME PUBLICADO → al alumno ──────────────────────────
    } else if (evento === 'informe_publicado') {
      if (rol !== 'admin') {
        return new Response(JSON.stringify({ error: 'Solo el administrador' }), { status: 403, headers: H })
      }
      const { data: inf } = await admin
        .from('informes').select('id, titulo, alumno:alumnos(usuario_id)').eq('id', id).single()
      if (!inf) return new Response(JSON.stringify({ error: 'Informe no encontrado' }), { status: 404, headers: H })

      const uid = (inf.alumno as any)?.usuario_id
      if (uid) destinatarios = [uid]
      titulo = 'Tu informe ya está disponible'
      cuerpo = `Ya puedes descargar "${esc(inf.titulo)}" desde tu panel.`
      asunto = 'Tu informe de Nexo Académico ya está disponible'
      url    = `${APP_BASE_URL}/alumno/`
      cta    = 'Descargar el informe'

    } else {
      return new Response(JSON.stringify({ error: 'Evento desconocido' }), { status: 400, headers: H })
    }

    if (!destinatarios.length) {
      return new Response(JSON.stringify({ ok: true, aviso: 'Sin destinatarios' }),
        { headers: { ...H, 'Content-Type': 'application/json' } })
    }

    const [push, email] = await Promise.all([
      enviarPush(destinatarios, { titulo, cuerpo, url, tag, importante }),
      enviarEmail(destinatarios, asunto, titulo, cuerpo, url, cta),
    ])

    return new Response(JSON.stringify({ ok: true, push, email }),
      { headers: { ...H, 'Content-Type': 'application/json' } })

  } catch (err: any) {
    console.error('notificar error:', err)
    return new Response(JSON.stringify({ error: err?.message || 'Error desconocido' }),
      { status: 500, headers: H })
  }
})
