import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.nexoacademico.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Borra un alumno y todo lo que cuelga de él.
//
// No vale con un DELETE a secas: hay cinco tablas (sesiones, informes,
// resultados de test y las dos agendas) que apuntan al alumno sin
// borrado en cascada, así que la base de datos rechazaría el borrado
// mientras quede una sola fila. Se limpian aquí, en orden, y al final
// se borra la cuenta de acceso, que sí arrastra en cascada la ficha de
// usuario, las credenciales, los avisos y lo demás.
//
// Las entradas de la agenda del profesor no se borran: se les quita el
// alumno. La clase estuvo ahí y al profesor le sigue cuadrando su
// historial aunque el alumno se dé de baja.

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Sin autorización' }), { status: 401, headers: corsHeaders })
    }

    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user: caller } } = await callerClient.auth.getUser()
    if (!caller) {
      return new Response(JSON.stringify({ error: 'Token inválido' }), { status: 401, headers: corsHeaders })
    }

    const { data: perfil } = await callerClient
      .from('usuarios').select('rol').eq('id', caller.id).single()
    if (perfil?.rol !== 'admin') {
      return new Response(JSON.stringify({ error: 'Solo el administrador puede eliminar usuarios' }), { status: 403, headers: corsHeaders })
    }

    const { alumno_id: alumnoId, confirmacion } = await req.json()
    if (!alumnoId) {
      return new Response(JSON.stringify({ error: 'Falta el alumno a eliminar' }), { status: 400, headers: corsHeaders })
    }
    // El panel manda esta palabra para que una llamada suelta a la
    // función no baste para borrar a nadie.
    if (confirmacion !== 'ELIMINAR') {
      return new Response(JSON.stringify({ error: 'Falta la confirmación' }), { status: 400, headers: corsHeaders })
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: alumno, error: errAlu } = await adminClient
      .from('alumnos').select('id, usuario_id').eq('id', alumnoId).single()
    if (errAlu || !alumno) {
      return new Response(JSON.stringify({ error: 'Ese alumno ya no existe' }), { status: 404, headers: corsHeaders })
    }

    const borrado: Record<string, number> = {}

    // La agenda del profesor conserva la clase, pero sin alumno.
    const { error: eCalProf, count: nCalProf } = await adminClient
      .from('calendario_profesor')
      .update({ alumno_id: null }, { count: 'exact' })
      .eq('alumno_id', alumnoId)
    if (eCalProf) throw new Error('agenda del profesor: ' + eCalProf.message)
    borrado.agenda_profesor_desvinculada = nCalProf ?? 0

    // El resto sí se va con él.
    const enCadena: [string, string][] = [
      ['calendario_alumno', 'agenda'],
      ['resultados_test',   'tests hechos'],
      ['informes',          'informes'],
      ['sesiones',          'sesiones'],
    ]
    for (const [tabla, etiqueta] of enCadena) {
      const { error, count } = await adminClient
        .from(tabla).delete({ count: 'exact' }).eq('alumno_id', alumnoId)
      if (error) throw new Error(etiqueta + ': ' + error.message)
      borrado[tabla] = count ?? 0
    }

    // Con las dependencias fuera, la ficha ya se deja borrar. Esto
    // arrastra en cascada bonos, tareas, material asignado y la
    // relación con sus profesores.
    const { error: eAlu } = await adminClient.from('alumnos').delete().eq('id', alumnoId)
    if (eAlu) throw new Error('ficha del alumno: ' + eAlu.message)

    // Y por último la cuenta, que arrastra la ficha de usuario.
    if (alumno.usuario_id) {
      const { error: eAuth } = await adminClient.auth.admin.deleteUser(alumno.usuario_id)
      // Si la cuenta ya no estaba, no es un fallo: lo que importa es
      // que no quede nada del alumno.
      if (eAuth && !/not found|no rows/i.test(eAuth.message)) {
        throw new Error('cuenta de acceso: ' + eAuth.message)
      }
    }

    return new Response(JSON.stringify({ ok: true, borrado }), { status: 200, headers: corsHeaders })

  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Error desconocido'
    console.error('Borrado de alumno fallido:', msg)
    return new Response(JSON.stringify({ error: 'No se pudo eliminar del todo — ' + msg }), { status: 500, headers: corsHeaders })
  }
})
