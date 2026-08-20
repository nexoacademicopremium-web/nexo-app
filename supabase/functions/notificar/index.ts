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
    res.tipo_de_aparato = (subs || []).map(s => {
      const ua = s.user_agent || ''
      const movil = /Android|iPhone|iPad|Mobile/i.test(ua) ? 'móvil' : 'escritorio'
      const nav = /Edg\//.test(ua) ? 'Edge' : /Chrome/.test(ua) ? 'Chrome'
                : /Firefox/.test(ua) ? 'Firefox' : /Safari/.test(ua) ? 'Safari' : 'otro'
      const serv = s.endpoint.includes('fcm.googleapis') ? 'Google'
                 : s.endpoint.includes('mozilla') ? 'Mozilla'
                 : s.endpoint.includes('push.apple') ? 'Apple' : 'otro'
      return `${movil} · ${nav} · vía ${serv}`
    })

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
      titulo = 'Los avisos funcionan'
      cuerpo = 'Si estás leyendo esto en tu móvil, las notificaciones están bien configuradas.'
      asunto = 'Prueba de avisos — Nexo Académico'
      cta    = 'Abrir Nexo'
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
      titulo = 'Tienes un test nuevo'
      cuerpo = `${esc(quien)} te ha asignado el test "${esc(test.titulo)}".`
      asunto = `Nuevo test: ${test.titulo}`
      url    = `${APP_BASE_URL}/alumno/`
      cta    = 'Hacer el test'

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
      titulo = 'Tienes una tarea nueva'
      cuerpo = `${esc(quien)} te ha puesto "${esc(tarea.titulo)}".${plazo}`
      asunto = `Nueva tarea: ${tarea.titulo}`
      url    = `${APP_BASE_URL}/alumno/`
      cta    = 'Ver la tarea'

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
      const nota = tarea.nota != null ? ` Nota: ${tarea.nota}.` : ''
      titulo = 'Tu tarea ya está corregida'
      cuerpo = `${esc(quien)} ha corregido "${esc(tarea.titulo)}".${nota}`
      asunto = `Tarea corregida: ${tarea.titulo}`
      url    = `${APP_BASE_URL}/alumno/`
      cta    = 'Ver la corrección'

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
      titulo = bono.estado === 'activo' ? 'Tu bono ya está activo' : 'Tienes un bono nuevo'
      cuerpo = bono.estado === 'activo'
        ? `Se han añadido ${bono.horas_contratadas}h a tu bono. Ya puedes usarlas.`
        : `Se ha registrado un bono de ${bono.horas_contratadas}h. Se activará cuando termines el actual.`
      asunto = 'Tu bono de Nexo Académico'
      url    = `${APP_BASE_URL}/alumno/`
      cta    = 'Ver mis horas'

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
      titulo = 'Ya tienes profesor asignado'
      cuerpo = asig
        ? `${esc(prof)} será tu profesor de ${esc(asig)}.`
        : `${esc(prof)} será tu profesor.`
      asunto = 'Tu profesor en Nexo Académico'
      url    = `${APP_BASE_URL}/alumno/`
      cta    = 'Ver mi profesor'

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
        .from('informes').select('id, titulo, notificado_at, alumno:alumnos(usuario_id)')
        .eq('id', id).single()
      if (!inf) return new Response(JSON.stringify({ error: 'Informe no encontrado' }), { status: 404, headers: H })

      // Ocultar y volver a publicar no debe avisar otra vez.
      if (inf.notificado_at) {
        return new Response(JSON.stringify({ ok: true, repetido: true }),
          { headers: { ...H, 'Content-Type': 'application/json' } })
      }
      await admin.from('informes')
        .update({ notificado_at: new Date().toISOString() }).eq('id', id)

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
