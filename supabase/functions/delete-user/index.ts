import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.nexoacademico.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  // Sin esto la respuesta viaja como texto suelto y el panel no sabe
  // leerla: daba 'no se recibió confirmación' aunque el borrado fuera bien.
  'Content-Type': 'application/json',
}

// Borra del todo a un alumno o a un profesor.
//
// Un DELETE a secas no vale. Hay dos grupos de tablas que lo impiden:
//
//   Lo que cuelga de la persona (sus sesiones, informes, agenda...)
//   apunta a su ficha sin borrado en cascada, así que la base de datos
//   rechaza el borrado mientras quede una fila. Se limpia aquí.
//
//   Y lo que solo lleva su firma — quién subió un material, quién creó
//   un test — apunta a su usuario. Eso NO se borra: el material sigue
//   sirviendo a los alumnos aunque el profesor se vaya. Se le quita la
//   firma y se queda.
//
// Al final se borra la cuenta de acceso, que sí arrastra en cascada la
// ficha de usuario, las credenciales y los avisos del dispositivo.

const json = (cuerpo: unknown, status = 200) =>
  new Response(JSON.stringify(cuerpo), { status, headers: corsHeaders })

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Sin autorización' }, 401)

    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user: caller } } = await callerClient.auth.getUser()
    if (!caller) return json({ error: 'Token inválido' }, 401)

    const { data: perfil } = await callerClient
      .from('usuarios').select('rol').eq('id', caller.id).single()
    if (perfil?.rol !== 'admin') {
      return json({ error: 'Solo el administrador puede eliminar usuarios' }, 403)
    }

    const cuerpo = await req.json()
    // alumno_id se sigue admitiendo: es como lo llamaba la primera versión.
    const tipo = cuerpo.tipo === 'profesor' ? 'profesor' : 'alumno'
    const id   = cuerpo.id || cuerpo.alumno_id
    if (!id) return json({ error: 'Falta la persona a eliminar' }, 400)

    // El panel manda esta palabra para que una llamada suelta a la
    // función no baste para borrar a nadie.
    if (cuerpo.confirmacion !== 'ELIMINAR') return json({ error: 'Falta la confirmación' }, 400)

    const db = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const tablaFicha = tipo === 'alumno' ? 'alumnos' : 'profesores'
    const { data: ficha, error: errFicha } = await db
      .from(tablaFicha).select('id, usuario_id').eq('id', id).single()
    if (errFicha || !ficha) return json({ error: `Ese ${tipo} ya no existe` }, 404)

    const usuarioId = ficha.usuario_id as string | null
    const hecho: Record<string, number> = {}

    if (tipo === 'alumno') {
      // Las clases de la agenda del profesor se quedan, pero sin alumno:
      // la clase existió y a él le sigue cuadrando su historial.
      const { error, count } = await db.from('calendario_profesor')
        .update({ alumno_id: null }, { count: 'exact' }).eq('alumno_id', id)
      if (error) throw new Error('agenda del profesor: ' + error.message)
      hecho.agenda_profesor_desvinculada = count ?? 0

      for (const [tabla, etiqueta] of [
        ['calendario_alumno', 'agenda'],
        ['resultados_test',   'tests hechos'],
        ['informes',          'informes'],
        ['sesiones',          'sesiones'],
      ] as [string, string][]) {
        const { error, count } = await db.from(tabla)
          .delete({ count: 'exact' }).eq('alumno_id', id)
        if (error) throw new Error(etiqueta + ': ' + error.message)
        hecho[tabla] = count ?? 0
      }

    } else {
      // Las sesiones de un profesor son el historial de sus alumnos: no
      // se tocan. Si las tiene, se para y se explica por qué.
      const { count: nSesiones } = await db.from('sesiones')
        .select('id', { count: 'exact', head: true }).eq('profesor_id', id)
      if (nSesiones && nSesiones > 0) {
        return json({
          error: `Tiene ${nSesiones} sesión/es registradas, que son el historial de sus alumnos. `
               + 'Bórralas primero desde Sesiones, o desactívalo en vez de eliminarlo.',
        }, 409)
      }

      const { error, count } = await db.from('calendario_profesor')
        .delete({ count: 'exact' }).eq('profesor_id', id)
      if (error) throw new Error('agenda: ' + error.message)
      hecho.calendario_profesor = count ?? 0
    }

    if (usuarioId) {
      // Un aviso dirigido a alguien que ya no está no le sirve a nadie.
      const { error: eAv, count: nAv } = await db.from('avisos')
        .delete({ count: 'exact' }).eq('destinatario_id', usuarioId)
      if (eAv) throw new Error('avisos: ' + eAv.message)
      hecho.avisos = nAv ?? 0

      // Lo que solo lleva su firma se queda, sin firma. Es lo que
      // bloqueaba el borrado con "material_subido_por_fkey": el material
      // que había subido no se puede tirar, sirve a los alumnos.
      for (const [tabla, columna] of [
        ['material',        'subido_por'],
        ['informes',        'subido_por'],
        ['material_alumno', 'asignado_por'],
        ['tests',           'creado_por'],
        ['avisos',          'creado_por'],
      ] as [string, string][]) {
        const { error, count } = await db.from(tabla)
          .update({ [columna]: null }, { count: 'exact' }).eq(columna, usuarioId)
        if (error) throw new Error(`${tabla}.${columna}: ${error.message}`)
        if (count) hecho[`${tabla}_sin_firma`] = count
      }
    }

    const { error: eFicha } = await db.from(tablaFicha).delete().eq('id', id)
    if (eFicha) throw new Error(`ficha del ${tipo}: ` + eFicha.message)

    if (usuarioId) {
      const { error: eAuth } = await db.auth.admin.deleteUser(usuarioId)
      // Si la cuenta ya no estaba, no es un fallo: lo que importa es que
      // no quede nada de la persona.
      if (eAuth && !/not found|no rows/i.test(eAuth.message)) {
        throw new Error('cuenta de acceso: ' + eAuth.message)
      }
    }

    return json({ ok: true, tipo, hecho })

  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Error desconocido'
    console.error('Borrado fallido:', msg)
    return json({ error: 'No se pudo eliminar del todo — ' + msg }, 500)
  }
})
