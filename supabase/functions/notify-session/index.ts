import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.nexoacademico.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const APP_BASE_URL   = Deno.env.get('APP_BASE_URL') || 'https://app.nexoacademico.com'
const FROM_EMAIL     = Deno.env.get("FROM_EMAIL") || "clases@nexoacademico.com"
const REPLY_TO       = Deno.env.get("REPLY_TO")   || "nexoacademicopremium@gmail.com"

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // Only professors (or admin via internal calls) trigger this
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return new Response(JSON.stringify({ error: 'Sin autorización' }), { status: 401, headers: corsHeaders })

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user: caller } } = await supabase.auth.getUser()
    if (!caller) return new Response(JSON.stringify({ error: 'Token inválido' }), { status: 401, headers: corsHeaders })

    const { data: callerProfile } = await supabase
      .from('usuarios')
      .select('rol')
      .eq('id', caller.id)
      .single()

    const { session_id } = await req.json()
    if (!session_id) return new Response(JSON.stringify({ error: 'Falta session_id' }), { status: 400, headers: corsHeaders })

    // Fetch session with all needed joins
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: sesion, error: sesErr } = await adminClient
      .from('sesiones')
      .select(`
        id, asignatura, fecha, hora_inicio, duracion_minutos, contenido_trabajado, confirmation_token, profesor_id,
        alumno:alumnos(
          usuario:usuarios(nombre, apellidos, email)
        ),
        profesor:profesores(
          usuario:usuarios(nombre, apellidos)
        )
      `)
      .eq('id', session_id)
      .single()

    if (sesErr || !sesion) {
      return new Response(JSON.stringify({ error: 'Sesión no encontrada' }), { status: 404, headers: corsHeaders })
    }

    if (callerProfile?.rol !== 'admin') {
      const { data: profData } = await adminClient
        .from('profesores')
        .select('id')
        .eq('usuario_id', caller.id)
        .single()
      if (!profData || profData.id !== sesion.profesor_id) {
        return new Response(JSON.stringify({ error: 'No autorizado para notificar esta sesión' }), { status: 403, headers: corsHeaders })
      }
    }

    const alumnoUser  = sesion.alumno?.usuario
    const profesorUser = sesion.profesor?.usuario

    // El correo interno (@nexo.internal) es solo la credencial de acceso.
    // Que un alumno no tenga correo real es lo habitual y deliberado: no es
    // un error, simplemente no hay email que enviar. El aviso le llega al
    // móvil, que es el canal principal. Enviar ahí rebotaría y quemaría la
    // reputación del dominio remitente.
    if (!alumnoUser?.email || alumnoUser.email.endsWith('@nexo.internal')) {
      return new Response(JSON.stringify({ ok: true, email_omitido: 'sin correo real' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const token     = sesion.confirmation_token
    const fechaDate = new Date(sesion.fecha + 'T00:00:00')
    const fechaStr  = fechaDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
    const horaStr   = sesion.hora_inicio ? sesion.hora_inicio.substring(0, 5) + 'h' : ''

    const urlConfirmar = `${APP_BASE_URL}/confirmar.html?id=${session_id}&token=${token}&action=confirmar`
    const urlRechazar  = `${APP_BASE_URL}/confirmar.html?id=${session_id}&token=${token}&action=rechazar`
    const urlVer       = `${APP_BASE_URL}/confirmar.html?id=${session_id}&token=${token}`

    const html = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Confirma tu clase — Nexo Académico</title></head>
<body style="margin:0;padding:0;background:#060d20;font-family:'Helvetica Neue',Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#060d20;padding:40px 20px">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px">

        <!-- Header -->
        <tr><td align="center" style="padding-bottom:32px">
          <span style="color:#fff;font-size:22px;font-weight:700;letter-spacing:2px">NEXO</span>
          <span style="color:#6eaef0;font-size:11px;letter-spacing:3px;text-transform:uppercase;display:block;margin-top:2px">Académico</span>
        </td></tr>

        <!-- Card -->
        <tr><td style="background:#0a1530;border:1px solid #1a2a4a;border-radius:14px;padding:36px">
          <p style="color:#6eaef0;font-size:12px;text-transform:uppercase;letter-spacing:1px;margin:0 0 8px">Nueva sesión registrada</p>
          <h1 style="color:#fff;font-size:22px;font-weight:700;margin:0 0 12px">¿Asististe a tu clase?</h1>
          <p style="color:#a8c8f0;font-size:14px;margin:0 0 28px;line-height:1.6">
            Hola, <b>${alumnoUser.nombre}</b>. Tu profesor <b>${profesorUser?.nombre || ''} ${profesorUser?.apellidos || ''}</b> ha registrado la siguiente sesión. Confírmala para actualizar tu registro.
          </p>

          <!-- Detail box -->
          <table width="100%" cellpadding="0" cellspacing="0" style="background:#04071b;border:1px solid #1a2a4a;border-radius:10px;margin-bottom:28px">
            <tr><td style="padding:14px 18px;border-bottom:1px solid #0f1f35">
              <span style="color:#4a6080;font-size:12px">Asignatura</span>
              <span style="color:#fff;font-size:13px;font-weight:600;float:right">${sesion.asignatura}</span>
            </td></tr>
            <tr><td style="padding:14px 18px;border-bottom:1px solid #0f1f35">
              <span style="color:#4a6080;font-size:12px">Fecha</span>
              <span style="color:#fff;font-size:13px;font-weight:600;float:right;text-transform:capitalize">${fechaStr}</span>
            </td></tr>
            ${horaStr ? `<tr><td style="padding:14px 18px;border-bottom:1px solid #0f1f35">
              <span style="color:#4a6080;font-size:12px">Hora</span>
              <span style="color:#fff;font-size:13px;font-weight:600;float:right">${horaStr}</span>
            </td></tr>` : ''}
            <tr><td style="padding:14px 18px${sesion.contenido_trabajado ? ';border-bottom:1px solid #0f1f35' : ''}">
              <span style="color:#4a6080;font-size:12px">Duración</span>
              <span style="color:#fff;font-size:13px;font-weight:600;float:right">${sesion.duracion_minutos} minutos</span>
            </td></tr>
            ${sesion.contenido_trabajado ? `<tr><td style="padding:14px 18px">
              <span style="color:#4a6080;font-size:12px">Contenido</span>
              <span style="color:#a8c8f0;font-size:13px;display:block;margin-top:4px">${sesion.contenido_trabajado}</span>
            </td></tr>` : ''}
          </table>

          <!-- CTA Buttons -->
          <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px">
            <tr>
              <td width="48%" align="center">
                <a href="${urlConfirmar}" style="display:block;background:#1a7f5e;color:#fff;text-decoration:none;padding:14px;border-radius:8px;font-size:14px;font-weight:700;text-align:center">
                  ✓ Sí, asistí
                </a>
              </td>
              <td width="4%"></td>
              <td width="48%" align="center">
                <a href="${urlRechazar}" style="display:block;background:#2d0d0d;color:#c0392b;border:1px solid #c0392b;text-decoration:none;padding:14px;border-radius:8px;font-size:14px;font-weight:700;text-align:center">
                  ✕ No asistí
                </a>
              </td>
            </tr>
          </table>

          <p style="color:#4a6080;font-size:12px;text-align:center;margin:0">
            O <a href="${urlVer}" style="color:#6eaef0">ver los detalles completos</a> antes de decidir.
          </p>
        </td></tr>

        <!-- Footer -->
        <tr><td align="center" style="padding-top:24px">
          <p style="color:#4a6080;font-size:11px;margin:0;line-height:1.8">
            Nexo Académico · Valencia<br>
            <a href="https://nexoacademico.com" style="color:#6eaef0;text-decoration:none">nexoacademico.com</a>
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>
    `.trim()

    // Send via Resend
    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: `Nexo Académico <${FROM_EMAIL}>`,
        reply_to: REPLY_TO,
        to:   [alumnoUser.email],
        subject: `Confirma tu clase de ${sesion.asignatura} — ${fechaStr}`,
        html,
      }),
    })

    if (!resendRes.ok) {
      const err = await resendRes.text()
      console.error('Resend error:', err)
      return new Response(JSON.stringify({ error: 'Error al enviar email' }), { status: 500, headers: corsHeaders })
    }

    return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error(err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders })
  }
})
