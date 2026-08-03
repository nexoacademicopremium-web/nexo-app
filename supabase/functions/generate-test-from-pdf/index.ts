import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const formData = await req.formData()
    const pdfFile          = formData.get('pdf') as File
    const titulo           = formData.get('titulo') as string
    const asignatura       = formData.get('asignatura') as string
    const nivel            = formData.get('nivel') as string
    const bloque_tema      = formData.get('bloque_tema') as string
    const alumno_id        = formData.get('alumno_id') as string
    const alumno_usuario_id = formData.get('alumno_usuario_id') as string
    const profesor_usuario_id = formData.get('profesor_usuario_id') as string

    if (!pdfFile) throw new Error('No se recibió el archivo PDF')
    if (!titulo || !asignatura || !alumno_id) throw new Error('Faltan campos obligatorios')

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

    // Service-role Supabase client for DB + Storage writes
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

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

    // Insert test record
    const { data: test, error: testErr } = await admin.from('tests').insert({
      titulo,
      asignatura,
      nivel: nivel || null,
      bloque_tema: bloque_tema || null,
      alumno_id,
      creado_por: profesor_usuario_id,
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
        creado_por: profesor_usuario_id,
        visible: true,
      })
    }

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
