import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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
    return new Response(JSON.stringify({ error: 'Solo el administrador puede generar informes' }), { status: 403, headers: corsHeaders })
  }

  try {
    const { alumno_id, tipo, fecha_inicio, fecha_fin } = await req.json()

    if (!alumno_id || !tipo || !fecha_inicio || !fecha_fin)
      throw new Error('Faltan campos: alumno_id, tipo, fecha_inicio, fecha_fin')
    if (fecha_fin < fecha_inicio)
      throw new Error('fecha_fin debe ser posterior a fecha_inicio')

    const ANTHROPIC_KEY = Deno.env.get('ANTHROPIC_API_KEY')
    if (!ANTHROPIC_KEY) throw new Error('ANTHROPIC_API_KEY no configurada')

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 1. Datos del alumno
    const { data: alumno, error: alumnoErr } = await admin
      .from('alumnos')
      .select('id, nivel, usuario:usuarios(nombre, apellidos)')
      .eq('id', alumno_id)
      .single()
    if (alumnoErr) throw new Error('Alumno no encontrado: ' + alumnoErr.message)

    // 2. Sesiones confirmadas en el rango
    const { data: sesiones, error: sesErr } = await admin
      .from('sesiones')
      .select(`
        id, asignatura, fecha, duracion_minutos,
        contenido_trabajado, estado_alumno_inicio, momento_bloqueo,
        resolvio_solo, necesito_ayuda, falta_base,
        nota_estimada, comparacion_anterior, arranque_proxima, tarea_casa,
        valoracion_comprension, valoracion_aplicacion, valoracion_concentracion,
        valoracion_motivacion, valoracion_autonomia,
        profesor:profesores(usuario:usuarios(nombre, apellidos))
      `)
      .eq('alumno_id', alumno_id)
      .eq('estado', 'confirmada')
      .gte('fecha', fecha_inicio)
      .lte('fecha', fecha_fin)
      .order('fecha', { ascending: true })
    if (sesErr) throw new Error('Error al obtener sesiones: ' + sesErr.message)
    if (!sesiones || sesiones.length === 0)
      throw new Error('No hay sesiones confirmadas en el periodo seleccionado')

    // 3. Agregar datos por asignatura (cálculos en JS, nunca en la IA)
    const asigMap: Record<string, any> = {}
    for (const s of sesiones) {
      const asig = s.asignatura || 'Sin asignatura'
      if (!asigMap[asig]) asigMap[asig] = { nombre: asig, profesor: null, sesiones: [] }
      if (s.profesor?.usuario && !asigMap[asig].profesor) {
        const u = s.profesor.usuario as any
        asigMap[asig].profesor = `${u.nombre} ${u.apellidos || ''}`.trim()
      }
      asigMap[asig].sesiones.push(s)
    }

    const avg = (arr: number[]) =>
      arr.length ? Math.round((arr.reduce((a, b) => a + b, 0) / arr.length) * 10) / 10 : null

    const mode = (arr: string[]) => {
      if (!arr.length) return null
      const freq: Record<string, number> = {}
      arr.forEach(v => { freq[v] = (freq[v] || 0) + 1 })
      return Object.keys(freq).sort((a, b) => freq[b] - freq[a])[0]
    }

    const asignaturas_agregadas = Object.values(asigMap).map((a: any) => {
      const sesas = a.sesiones
      const n = sesas.length
      const horas = Math.round(sesas.reduce((acc: number, s: any) => acc + (s.duracion_minutos || 60), 0) / 60 * 10) / 10

      const valField = (f: string) => avg(sesas.map((s: any) => s[f]).filter((v: any) => v != null))

      // Tendencia autonomía: primera vs segunda mitad
      let tendencia_autonomia = null
      if (n >= 2) {
        const mid = Math.floor(n / 2)
        const p1 = avg(sesas.slice(0, mid).map((s: any) => s.valoracion_autonomia).filter((v: any) => v != null))
        const p2 = avg(sesas.slice(mid).map((s: any) => s.valoracion_autonomia).filter((v: any) => v != null))
        if (p1 != null && p2 != null) {
          const diff = p2 - p1
          tendencia_autonomia = diff > 0.5 ? 'mejora' : diff < -0.5 ? 'empeora' : 'estable'
        }
      }

      const nota_media = avg(sesas.map((s: any) => s.nota_estimada).filter((v: any) => v != null))
      const temas_trabajados = [...new Set(
        sesas.map((s: any) => s.contenido_trabajado).filter((v: any) => v && v.trim())
      )]
      const estado_dominante = mode(sesas.map((s: any) => s.estado_alumno_inicio).filter(Boolean))
      const bloqueo_dominante = mode(sesas.map((s: any) => s.momento_bloqueo).filter(Boolean))

      return {
        nombre: a.nombre,
        profesor: a.profesor,
        num_sesiones: n,
        horas_totales: horas,
        temas_trabajados,
        valoraciones: {
          comprension:    valField('valoracion_comprension'),
          aplicacion:     valField('valoracion_aplicacion'),
          concentracion:  valField('valoracion_concentracion'),
          motivacion:     valField('valoracion_motivacion'),
          autonomia:      valField('valoracion_autonomia'),
        },
        tendencia_autonomia,
        nota_media,
        estado_dominante,
        bloqueo_dominante,
        narrativas: sesas
          .filter((s: any) => s.resolvio_solo || s.necesito_ayuda || s.falta_base || s.comparacion_anterior)
          .map((s: any) => ({
            fecha: s.fecha,
            resolvio_solo: s.resolvio_solo,
            necesito_ayuda: s.necesito_ayuda,
            falta_base: s.falta_base,
            comparacion_anterior: s.comparacion_anterior,
            arranque_proxima: s.arranque_proxima,
            tarea_casa: s.tarea_casa,
          })),
      }
    })

    // KPIs globales
    const total_sesiones = sesiones.length
    const total_horas = Math.round(sesiones.reduce((a, s) => a + (s.duracion_minutos || 60), 0) / 60 * 10) / 10
    const asignaturas_distintas = Object.keys(asigMap).length
    const profesores_distintos = [...new Set(asignaturas_agregadas.map(a => a.profesor).filter(Boolean))]
    const horas_por_asig = Object.fromEntries(asignaturas_agregadas.map(a => [a.nombre, a.horas_totales]))

    const u = alumno.usuario as any
    const alumnoNombre = u ? `${u.nombre} ${u.apellidos || ''}`.trim() : 'Alumno'

    const inputData = {
      alumno: { nombre: alumnoNombre, nivel: alumno.nivel },
      periodo: { tipo, fecha_inicio, fecha_fin },
      global: { total_sesiones, total_horas, asignaturas_distintas, profesores_distintos, horas_por_asig },
      asignaturas: asignaturas_agregadas,
    }

    // 4. Llamada a Claude
    const systemPrompt = `Eres un asistente que redacta el contenido narrativo de informes de seguimiento académico para Nexo Académico, una agencia de clases particulares en Valencia. No diseñas el informe ni generas gráficos: solo escribes texto a partir de datos que ya te llegan calculados.

DATOS DE ENTRADA
Recibirás un JSON con: datos del alumno, periodo (tipo, fecha_inicio, fecha_fin), y por cada asignatura trabajada: profesor, temas vistos, horas dedicadas, valoraciones numéricas 1-10 de comprensión/aplicación/concentración/motivación/autonomía, tendencia de autonomía (mejora/estable/empeora), nota media estimada, estado emocional dominante, patrón de bloqueo dominante, y narrativas de sesiones individuales.

REGLA ABSOLUTA SOBRE DATOS
No inventes ni recalcules ninguna cifra. Usa exactamente los datos que recibas. No inventes nombres de temas, asignaturas o profesores que no estén en el input.

MARCO PEDAGÓGICO (para interpretar, no para citar)
Usa estos marcos para decidir CÓMO interpretar los datos, pero no los menciones por su nombre en el texto del informe:
- Hattie (Visible Learning): qué prácticas priorizar como logro
- Rosenshine (Principles of Instruction): interpretar la progresión de práctica guiada a autónoma
- Ebbinghaus (repetición espaciada): fundamenta el análisis de planificación y frecuencia
- Sweller (carga cognitiva): interpretar atención, ritmo y secuenciación de dificultad
- Dunlosky et al. 2013: fundamenta los objetivos del siguiente periodo

TONO
Español directo, conversacional, sin jerga corporativa. Dirigido a familias sin formación pedagógica. Traduce las métricas a lenguaje humano. Nunca menciones IA, automatización ni modelos de lenguaje.

AJUSTE SEGÚN VOLUMEN DE DATOS
Con pocas sesiones, limita el análisis a observaciones puntuales. No generalices con 1-2 sesiones.

MÚLTIPLES ASIGNATURAS Y PROFESORES
Trata cada asignatura de forma independiente. Nunca mezcles datos de asignaturas distintas.

RECOMENDACIÓN DE HORAS
Por defecto "mantener". "aumentar" solo si hay dificultad creciente clara. "reducir" solo si el rendimiento es consistentemente alto. No recomiendes aumentar por defecto.

PUNTOS DE MEJORA
Ordena por prioridad real según impacto en el aprendizaje.

FORMATO DE SALIDA
Devuelve ÚNICAMENTE un JSON válido con esta estructura exacta. Sin texto antes ni después, sin backticks de markdown, sin comentarios:
{
  "resumen_ejecutivo": "string",
  "cabecera": { "profesores": [{ "nombre": "string", "asignaturas": ["string"] }] },
  "asignaturas": [{
    "nombre": "string", "profesor": "string", "temas_trabajados": ["string"],
    "analisis": "string",
    "horas_recomendacion": { "direccion": "aumentar | mantener | reducir", "motivo": "string" }
  }],
  "puntos_fuertes": ["string"],
  "puntos_mejora": [{ "prioridad": 1, "asignatura": "string", "tema": "string", "descripcion": "string" }],
  "patron_trabajo": "string",
  "analisis_planificacion": "string",
  "logros": ["string"],
  "objetivos_siguiente_periodo": ["string"]
}`

    const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-opus-4-5',
        max_tokens: 4096,
        system: systemPrompt,
        messages: [{
          role: 'user',
          content: `Genera el informe para este alumno:\n\n${JSON.stringify(inputData, null, 2)}`,
        }],
      }),
    })

    if (!claudeRes.ok) {
      const errText = await claudeRes.text()
      throw new Error('Error al contactar con la IA: ' + errText.slice(0, 200))
    }

    const claudeData = await claudeRes.json()
    const rawText = (claudeData.content?.[0]?.text || '').trim()

    let cleaned = rawText.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim()
    const objMatch = cleaned.match(/\{[\s\S]*\}/)
    if (objMatch) cleaned = objMatch[0]

    let iaContent: any
    try {
      iaContent = JSON.parse(cleaned)
    } catch {
      throw new Error('La IA no devolvió un formato JSON válido. Inténtalo de nuevo.')
    }

    // 5. Guardar informe en BD con estado oculto
    const { data: informe, error: infErr } = await admin.from('informes').insert({
      alumno_id,
      tipo,
      titulo: `Informe ${tipo === 'mensual' ? 'mensual' : 'personalizado'} — ${alumnoNombre}`,
      fecha: fecha_inicio,
      fecha_inicio,
      fecha_fin,
      contenido: { ia: iaContent, kpis: inputData },
      estado: 'oculto',
      eliminado: false,
      visible: false,
    }).select().single()

    if (infErr) throw new Error('Error al guardar el informe: ' + infErr.message)

    return new Response(
      JSON.stringify({ success: true, informe_id: informe.id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )

  } catch (err: any) {
    console.error('generar-informe error:', err)
    return new Response(
      JSON.stringify({ error: err?.message || 'Error desconocido' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
