import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.nexoacademico.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// El nombre de usuario acaba formando parte de un correo interno, y
// un correo no admite acentos ni espacios. Un apellido tan corriente
// como Álvarez dejaba el alta en "invalid format", porque la inicial
// se colaba con tilde.
function limpiarParaEmail(txt: string): string {
  return txt
    .normalize('NFD')             // separa la letra de su tilde
    .replace(/[\u0300-\u036f]/g, '')   // y se queda solo con la letra
    .replace(/[^A-Za-z0-9._-]/g, '')    // fuera lo que no vale en un correo
}

function generarUsername(rol: string, nombre: string, apellidos: string, year: number): string {
  const prefix = rol === 'alumno' ? 'ALU' : 'PRO'
  const partes = `${nombre} ${apellidos}`.trim().split(/\s+/).filter(Boolean)
  const iniciales = partes.slice(0, 3)
    .map(p => limpiarParaEmail(p[0]).toUpperCase())
    .join('')
    .padEnd(3, 'X')
  return `${prefix}${year}${iniciales}`
}

function generarPassword(): string {
  const upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  const lower   = 'abcdefghjkmnpqrstuvwxyz'
  const digits  = '23456789'
  const symbols = '!@#$%&*'
  const all     = upper + lower + digits + symbols

  const arr = new Uint8Array(16)
  crypto.getRandomValues(arr)

  const chars: string[] = [
    upper[arr[0] % upper.length],
    lower[arr[1] % lower.length],
    digits[arr[2] % digits.length],
    symbols[arr[3] % symbols.length],
  ]
  for (let i = 4; i < 12; i++) chars.push(all[arr[i] % all.length])

  // Fisher-Yates shuffle using remaining random bytes
  for (let i = chars.length - 1; i > 0; i--) {
    const j = arr[i % 16] % (i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]]
  }
  return chars.join('')
}

async function generarUsernameUnico(
  adminClient: ReturnType<typeof createClient>,
  rol: string, nombre: string, apellidos: string, year: number
): Promise<string> {
  const base = generarUsername(rol, nombre, apellidos, year)
  const { data } = await adminClient
    .from('admin_credenciales')
    .select('username')
    .ilike('username', `${base}%`)
  const existing = new Set((data || []).map((r: { username: string }) => r.username))
  if (!existing.has(base)) return base
  for (let i = 2; i <= 99; i++) {
    const candidate = `${base}${i}`
    if (!existing.has(candidate)) return candidate
  }
  return `${base}${Date.now()}`
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // Verify caller is admin
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
      return new Response(JSON.stringify({ error: 'Solo el administrador puede crear usuarios' }), { status: 403, headers: corsHeaders })
    }

    const {
      nombre, apellidos, rol,
      username: usernameParam,
      password: passwordParam,
      email: emailParam,
    } = await req.json()
    if (!nombre || !apellidos || !rol) {
      return new Response(JSON.stringify({ error: 'Faltan campos obligatorios (nombre, apellidos, rol)' }), { status: 400, headers: corsHeaders })
    }
    if (!['alumno', 'profesor'].includes(rol)) {
      return new Response(JSON.stringify({ error: 'Rol inválido' }), { status: 400, headers: corsHeaders })
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const year = new Date().getFullYear()
    const escrito  = usernameParam?.trim() ? limpiarParaEmail(usernameParam.trim()) : ''
    const username = escrito || await generarUsernameUnico(adminClient, rol, nombre, apellidos, year)
    const password = passwordParam?.trim()?.length >= 6
      ? passwordParam.trim()
      : generarPassword()
    // Hay dos correos y no son lo mismo:
    //   emailAcceso   — interno, va con el nombre de usuario. Es con lo
    //                   que se entra, y por eso nunca puede faltar.
    //   emailContacto — el de verdad, el de la familia o el profesor.
    //                   Es opcional y es a donde llegan los avisos.
    const emailAcceso = `${username}@nexo.internal`

    // Red de seguridad: si aun así el correo no sale válido, se avisa
    // de qué pasa en vez de soltar el "invalid format" de Supabase,
    // que no le dice nada a nadie.
    if (!/^[A-Za-z0-9._-]+@nexo\.internal$/.test(emailAcceso)) {
      return new Response(JSON.stringify({
        error: 'El nombre de usuario solo puede llevar letras sin tilde, números, puntos y guiones.',
      }), { status: 400, headers: corsHeaders })
    }

    const emailContacto = typeof emailParam === 'string' ? emailParam.trim() : ''
    if (emailContacto && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(emailContacto)) {
      return new Response(JSON.stringify({
        error: 'El email no tiene un formato válido.',
      }), { status: 400, headers: corsHeaders })
    }

    const { data: newAuthUser, error: createErr } = await adminClient.auth.admin.createUser({
      email: emailAcceso,
      password,
      email_confirm: true,
    })
    if (createErr || !newAuthUser?.user) {
      return new Response(JSON.stringify({ error: createErr?.message || 'Error al crear usuario en auth' }), { status: 500, headers: corsHeaders })
    }

    const userId = newAuthUser.user.id

    const { error: dbErr } = await adminClient.from('usuarios').insert({
      id:       userId,
      email:    emailContacto || emailAcceso,
      nombre,
      apellidos,
      rol,
      activo: true,
    })
    if (dbErr) {
      await adminClient.auth.admin.deleteUser(userId)
      return new Response(JSON.stringify({ error: dbErr.message }), { status: 500, headers: corsHeaders })
    }

    const { error: credErr } = await adminClient.from('admin_credenciales').insert({
      usuario_id: userId,
      username,
    })
    if (credErr) {
      // Non-fatal: user is created, just credentials won't be stored
      console.warn('Warning: admin_credenciales insert failed:', credErr.message)
    }

    return new Response(
      JSON.stringify({ user_id: userId, username, password }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders })
  }
})
