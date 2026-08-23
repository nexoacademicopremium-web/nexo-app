import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.nexoacademico.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const FROM_EMAIL     = Deno.env.get("FROM_EMAIL") || "clases@nexoacademico.com"

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response(JSON.stringify({ error: 'Sin autorización' }), { status: 401, headers: corsHeaders })

  const callerClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )
  const { data: { user: caller } } = await callerClient.auth.getUser()
  if (!caller) return new Response(JSON.stringify({ error: 'Token inválido' }), { status: 401, headers: corsHeaders })

  const { data: callerProfile } = await callerClient
    .from('usuarios')
    .select('rol')
    .eq('id', caller.id)
    .single()

  if (callerProfile?.rol !== 'admin') {
    return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 403, headers: corsHeaders })
  }

  try {
    const { session_id } = await req.json()
    if (!session_id) return new Response(JSON.stringify({ error: 'Falta session_id' }), { status: 400, headers: corsHeaders })

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: sesion } = await adminClient
      .from('sesiones')
      .select(`
        id, asignatura, fecha, hora_inicio, duracion_minutos,
        alumno:alumnos(usuario:usuarios(nombre, apellidos)),
        profesor:profesores(usuario:usuarios(nombre, apellidos, email))
      `)
      .eq('id', session_id)
      .single()

    if (!sesion) return new Response(JSON.stringify({ error: 'Sesión no encontrada' }), { status: 404, headers: corsHeaders })

    const profUser   = sesion.profesor?.usuario
    const alumnoUser = sesion.alumno?.usuario

    if (!profUser?.email) {
      return new Response(JSON.stringify({ ok: true, skipped: 'profesor sin email' }), { headers: corsHeaders })
    }

    const fechaDate = new Date(sesion.fecha + 'T00:00:00')
    const fechaStr  = fechaDate.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })

    const html = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>Sesión rechazada — Nexo Académico</title></head>
<body style="margin:0;padding:0;background:#060d20;font-family:'Helvetica Neue',Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#060d20;padding:40px 20px">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px">

        <tr><td align="center" style="padding-bottom:32px">
          <span style="color:#fff;font-size:22px;font-weight:700;letter-spacing:2px">NEXO</span>
          <span style="color:#6eaef0;font-size:11px;letter-spacing:3px;text-transform:uppercase;display:block;margin-top:2px">Académico</span>
        </td></tr>

        <tr><td style="background:#0a1530;border:1px solid #1a2a4a;border-radius:14px;padding:36px">
          <p style="color:#c0392b;font-size:12px;text-transform:uppercase;letter-spacing:1px;margin:0 0 8px">Sesión rechazada</p>
          <h1 style="color:#fff;font-size:22px;font-weight:700;margin:0 0 12px">Tu alumno ha marcado que no asistió</h1>
          <p style="color:#a8c8f0;font-size:14px;margin:0 0 28px;line-height:1.6">
            Hola, <b>${profUser.nombre}</b>. El alumno <b>${alumnoUser?.nombre || ''} ${alumnoUser?.apellidos || ''}</b> ha indicado que no asistió a la sesión de <b>${sesion.asignatura}</b> del <b>${fechaStr}</b>.
          </p>
          <p style="color:#a8c8f0;font-size:14px;margin:0 0 8px;line-height:1.6">
            Las horas <b>no han sido descontadas</b> del bono. Si crees que hay un error, contacta con Manu.
          </p>
        </td></tr>

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

    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: `Nexo Académico <${FROM_EMAIL}>`,
        to:   [profUser.email],
        subject: `Sesión rechazada — ${alumnoUser?.nombre} el ${fechaStr}`,
        html,
      }),
    })

    return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error(err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders })
  }
})
