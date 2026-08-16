import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.nexoacademico.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return new Response(JSON.stringify({ error: 'Sin autorización' }), { status: 401, headers: corsHeaders })

    // Verify caller is admin
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
      return new Response(JSON.stringify({ error: 'Solo el administrador puede cambiar contraseñas' }), { status: 403, headers: corsHeaders })
    }

    const { user_id, password } = await req.json()
    if (!user_id || !password) {
      return new Response(JSON.stringify({ error: 'Faltan user_id o password' }), { status: 400, headers: corsHeaders })
    }
    if (password.length < 6) {
      return new Response(JSON.stringify({ error: 'La contraseña debe tener al menos 6 caracteres' }), { status: 400, headers: corsHeaders })
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { error } = await adminClient.auth.admin.updateUserById(user_id, { password })
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders })
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders })
  }
})
