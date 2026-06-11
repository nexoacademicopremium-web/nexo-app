import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    // Parse body
    const { email, password, nombre, apellidos, rol } = await req.json()
    if (!email || !password || !nombre || !apellidos || !rol) {
      return new Response(JSON.stringify({ error: 'Faltan campos obligatorios' }), { status: 400, headers: corsHeaders })
    }
    if (!['alumno', 'profesor', 'admin'].includes(rol)) {
      return new Response(JSON.stringify({ error: 'Rol inválido' }), { status: 400, headers: corsHeaders })
    }

    // Use service role to create auth user
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: newAuthUser, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    })
    if (createErr || !newAuthUser?.user) {
      return new Response(JSON.stringify({ error: createErr?.message || 'Error al crear usuario en auth' }), { status: 500, headers: corsHeaders })
    }

    // Insert into usuarios table
    const { error: dbErr } = await adminClient.from('usuarios').insert({
      id:       newAuthUser.user.id,
      email,
      nombre,
      apellidos,
      rol,
      activo:   true,
    })
    if (dbErr) {
      // Rollback: delete auth user
      await adminClient.auth.admin.deleteUser(newAuthUser.user.id)
      return new Response(JSON.stringify({ error: dbErr.message }), { status: 500, headers: corsHeaders })
    }

    return new Response(
      JSON.stringify({ user_id: newAuthUser.user.id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders })
  }
})
