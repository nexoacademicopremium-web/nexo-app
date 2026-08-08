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

  if (!callerProfile || !['admin', 'profesor'].includes(callerProfile.rol)) {
    return new Response(JSON.stringify({ error: 'No autorizado' }), { status: 403, headers: corsHeaders })
  }

  // Service client needed for rate-limit check and authorized writes
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Rate limit: 15 calls per user per day
  const dayStart = new Date()
  dayStart.setUTCHours(0, 0, 0, 0)
  const { count: usageCount } = await admin
    .from('claude_usage_log')
    .select('id', { count: 'exact', head: true })
    .eq('usuario_id', caller.id)
    .eq('funcion', 'generate-test-from-pdf')
    .gte('created_at', dayStart.toISOString())
  if ((usageCount ?? 0) >= 15) {
    return new Response(
      JSON.stringify({ error: 'Límite diario de generación de tests alcanzado (15/día). Inténtalo mañana.' }),
      { status: 429, headers: corsHeaders },
    )
  }

  try {
    const formData = await req.formData()
    const pdfFile          = formData.get('pdf') as File
    const titulo           = formData.get('titulo') as string
    const asignatura       = formData.get('asignatura') as string
    const nivel            = formData.get('nivel') as string
    const bloque_tema      = formData.get('bloque_tema') as string
    const alumno_id        = formData.get('alumno_id') as string
    const alumno_usuario_id = formData.get('alumno_usuario_id') as string

    if (!pdfFile) throw new Error('No se recibió el archivo PDF')
    if (!titulo || !asignatura || !alumno_id) throw new Error('Faltan campos obligatorios')

    // PDF size limit: 10 MB
    const MAX_PDF_BYTES = 10 * 1024 * 1024
    if (pdfFile.size > MAX_PDF_BYTES) {
      throw new Error(`El PDF es demasiado grande (${(pdfFile.size / 1024 / 1024).toFixed(1)} MB). Máximo permitido: 10 MB.`)
    }

    // Validate that the alumno belongs to this profesor (unless admin)
    if (callerProfile.rol === 'profesor') {
      const { data: prof } = await admin
        .from('profesores')
        .select('id')
        .eq('usuario_id', caller.id)
        .single()
      if (!prof) throw new Error('Profesor no encontrado')
      const { count: asignado } = await admin
        .from('alumno_profesor')
        .select('id', { count: 'exact', head: true })
        .eq('profesor_id', prof.id)
        .eq('alumno_id', alumno_id)
      if (!asignado || asignado === 0) {
        return new Response(
          JSON.stringify({ error: 'No puedes asignar tests a alumnos que no son tuyos' }),
          { status: 403, headers: corsHeaders },
        )
      }
    }

    const ANTHROPIC_KEY = Deno.env.get('ANTHROPIC_API_KEY')
    if (!ANTHROPIC_KEY) throw new Error('ANTHROPIC_API_KEY no configurada en Edge Function secrets')

    // Convert PDF to base64 (safe loop to avoid stack overflow on large files)
    const pdfBuffer = await pdfFile.arrayBuffer()
    const bytes = new Uint8Array(pdfBuffer)
    let binary = ''
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    const pdfBase64 = btoa(binary)

    // Call Claude to generate the test
    const prompt = `Eres un generador de tests para una academia de refuerzo escolar española.

Asignatura: ${asignatura}
Nivel: ${nivel}
${bloque_tema ? `Tema: ${bloque_tema}` : ''}

Se te proporciona un PDF. Tu tarea es:
1. Si el PDF ya contiene un test, cuestionario o ejercicios con preguntas de tipo test, extrae EXACTAMENTE esas preguntas (respetando las opciones dadas)
2. Si el PDF es teoría, apuntes o ejercicios sin formato test, genera un test de 10-15 preguntas (máximo 20) sobre los conceptos principales

Devuelve ÚNICAMENTE un JSON válido (sin markdown, sin bloques de código, sin texto adicional antes o después), con este formato exacto:
[
  {
    "enunciado": "Texto de la pregunta",
    "opcion_a": "Primera opción",
    "opcion_b": "Segunda opción",
    "opcion_c": "Tercera opción",
    "opcion_d": "Cuarta opción",
    "respuesta_correcta": "a"
  }
]

Reglas:
- Todo el texto en español
- Exactamente 4 opciones por pregunta (a, b, c, d)
- Solo UNA opción correcta; respuesta_correcta debe ser "a", "b", "c" o "d"
- Máximo 20 preguntas en total
- Las opciones incorrectas deben ser plausibles y educativas`

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
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'document',
                source: { type: 'base64', media_type: 'application/pdf', data: pdfBase64 },
              },
              { type: 'text', text: prompt },
            ],
          },
        ],
      }),
    })

    if (!claudeRes.ok) {
      const errText = await claudeRes.text()
      throw new Error('Error al contactar con la IA: ' + errText.slice(0, 200))
    }

    const claudeData = await claudeRes.json()
    const rawText = (claudeData.content?.[0]?.text || '').trim()

    // Parse JSON — strip markdown fences, then extract the first [...] array found
    let cleaned = rawText.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim()
    // If there's extra text before/after the JSON array, extract just the array
    const arrMatch = cleaned.match(/\[[\s\S]*\]/)
    if (arrMatch) cleaned = arrMatch[0]
    let questions: any[]
    try {
      questions = JSON.parse(cleaned)
    } catch {
      console.error('Raw Claude response:', rawText.slice(0, 500))
      throw new Error('La IA no devolvió un formato JSON válido. Inténtalo de nuevo.')
    }

    if (!Array.isArray(questions) || questions.length === 0) {
      throw new Error('La IA no generó preguntas. Verifica que el PDF tenga contenido legible.')
    }

    // Clamp to 20 questions and validate fields
    const qs = questions.slice(0, 20).filter(q =>
      q.enunciado && q.opcion_a && q.opcion_b && q.opcion_c && q.opcion_d &&
      ['a', 'b', 'c', 'd'].includes(q.respuesta_correcta)
    )
    if (qs.length === 0) throw new Error('Las preguntas generadas no tienen el formato correcto.')

    // admin client already created above for rate-limit check

    // Upload PDF to Storage
    const storagePath = `tests-pdf/${Date.now()}-${alumno_id.slice(0, 8)}.pdf`
    const { data: storageData, error: storageErr } = await admin.storage
      .from('nexo-files')
      .upload(storagePath, pdfFile, { contentType: 'application/pdf', upsert: false })

    let pdfPublicUrl = ''
    if (!storageErr && storageData) {
      const { data: { publicUrl } } = admin.storage.from('nexo-files').getPublicUrl(storageData.path)
      pdfPublicUrl = publicUrl
    }

    // Insert test record — creado_por from verified JWT, not from client body
    const { data: test, error: testErr } = await admin.from('tests').insert({
      titulo,
      asignatura,
      nivel: nivel || null,
      bloque_tema: bloque_tema || null,
      alumno_id,
      creado_por: caller.id,
      visible: true,
      generado_ia: true,
      puede_repetir: false,
      pdf_url: pdfPublicUrl || null,
    }).select().single()

    if (testErr) throw new Error('Error al crear el test: ' + testErr.message)

    // Insert questions
    const preguntasRows = qs.map((q: any, idx: number) => ({
      test_id: test.id,
      enunciado: q.enunciado,
      opcion_a: q.opcion_a,
      opcion_b: q.opcion_b,
      opcion_c: q.opcion_c,
      opcion_d: q.opcion_d,
      respuesta_correcta: q.respuesta_correcta,
      orden: idx,
    }))

    const { error: pregErr } = await admin.from('preguntas_test').insert(preguntasRows)
    if (pregErr) throw new Error('Error al guardar las preguntas: ' + pregErr.message)

    // Notify alumno via avisos
    if (alumno_usuario_id) {
      await admin.from('avisos').insert({
        destinatario_id: alumno_usuario_id,
        destinatario_rol: 'alumno',
        titulo: `Nuevo test de ${asignatura}`,
        contenido: `Tu profesor te ha asignado el test "${titulo}". Entra en Estudiar → Tests para realizarlo.`,
        creado_por: caller.id,  // from verified JWT, not client body
        visible: true,
      })
    }

    // Log successful Claude usage for rate limiting
    await admin.from('claude_usage_log').insert({
      usuario_id: caller.id,
      funcion: 'generate-test-from-pdf',
    })

    return new Response(
      JSON.stringify({ success: true, testId: test.id, questionCount: qs.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )

  } catch (err: any) {
    console.error('generate-test-from-pdf error:', err)
    return new Response(
      JSON.stringify({ error: err?.message || 'Error desconocido' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
