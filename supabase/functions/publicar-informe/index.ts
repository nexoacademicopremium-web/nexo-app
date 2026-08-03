import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { informe_id } = await req.json()
    if (!informe_id) throw new Error('informe_id requerido')

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: informe, error: infErr } = await admin
      .from('informes')
      .select('*, alumno:alumnos(nivel, usuario:usuarios(nombre, apellidos))')
      .eq('id', informe_id)
      .single()
    if (infErr) throw new Error('Informe no encontrado: ' + infErr.message)

    const { ia, kpis } = informe.contenido || {}
    if (!ia || !kpis) throw new Error('El informe no tiene contenido generado')

    const u = informe.alumno?.usuario as any
    const alumnoNombre = u ? `${u.nombre} ${u.apellidos || ''}`.trim() : 'Alumno'

    const html = generarHtml(informe, ia, kpis, alumnoNombre)

    const htmlBytes = new TextEncoder().encode(html)
    const storagePath = `informes/${informe.alumno_id}/${informe_id}.html`

    const { error: storageErr } = await admin.storage
      .from('nexo-files')
      .upload(storagePath, htmlBytes, { contentType: 'text/html; charset=utf-8', upsert: true })
    if (storageErr) throw new Error('Error al subir el informe: ' + storageErr.message)

    const { data: { publicUrl } } = admin.storage.from('nexo-files').getPublicUrl(storagePath)

    const { error: updErr } = await admin.from('informes').update({
      estado: 'visible',
      visible: true,
      pdf_url: publicUrl,
      archivo_url: publicUrl,
      published_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq('id', informe_id)
    if (updErr) throw new Error('Error al publicar: ' + updErr.message)

    return new Response(
      JSON.stringify({ success: true, pdf_url: publicUrl }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )

  } catch (err: any) {
    console.error('publicar-informe error:', err)
    return new Response(
      JSON.stringify({ error: err?.message || 'Error desconocido' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})

const MESES = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre']

function fmtFecha(d: string) {
  const dt = new Date(d)
  return `${dt.getUTCDate()} de ${MESES[dt.getUTCMonth()]} de ${dt.getUTCFullYear()}`
}

function stars(v: number | null) {
  if (v == null) return '—'
  const full = Math.min(5, Math.round(v / 2))
  return '★'.repeat(full) + '☆'.repeat(5 - full) + ` (${v}/10)`
}

function escHtml(s: string) {
  return (s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
}

function generarHtml(informe: any, ia: any, kpis: any, alumnoNombre: string): string {
  const global = kpis.global || {}
  const tipoLabel = informe.tipo === 'mensual' ? 'Informe mensual' : 'Informe personalizado'
  const periodoLabel = informe.tipo === 'mensual'
    ? `${tipoLabel} — ${new Date(informe.fecha_inicio).toLocaleDateString('es-ES', { month: 'long', year: 'numeric', timeZone: 'UTC' })}`
    : `${tipoLabel}: ${fmtFecha(informe.fecha_inicio)} – ${fmtFecha(informe.fecha_fin)}`

  const asigHtml = (ia.asignaturas || []).map((asig: any) => {
    const kpiAsig = (kpis.asignaturas || []).find((a: any) => a.nombre === asig.nombre) || {}
    const valors = kpiAsig.valoraciones || {}
    const temasHtml = (asig.temas_trabajados || []).map((t: string) => `<li>${escHtml(t)}</li>`).join('')
    const recDir = asig.horas_recomendacion?.direccion || 'mantener'
    return `
    <div class="asig-block">
      <div class="asig-header">
        <span class="asig-nombre">${escHtml(asig.nombre)}</span>
        <span class="asig-prof">Prof. ${escHtml(asig.profesor || '—')}</span>
        <span class="asig-badge">${kpiAsig.horas_totales || '—'} h · ${kpiAsig.num_sesiones || '—'} sesiones</span>
      </div>
      <p class="asig-analisis">${escHtml(asig.analisis || '')}</p>
      ${temasHtml ? `<div class="temas-sec"><strong>Temas trabajados:</strong><ul>${temasHtml}</ul></div>` : ''}
      <div class="kpi-row">
        ${['comprension','aplicacion','concentracion','motivacion','autonomia'].map(f =>
          valors[f] != null ? `<div class="kpi-chip"><span class="kpi-lbl">${f.charAt(0).toUpperCase()+f.slice(1)}</span><span class="kpi-stars">${stars(valors[f])}</span></div>` : ''
        ).join('')}
        ${kpiAsig.nota_media != null ? `<div class="kpi-chip nota"><span class="kpi-lbl">Nota estimada</span><span class="kpi-nota">${kpiAsig.nota_media}/10</span></div>` : ''}
        ${kpiAsig.tendencia_autonomia ? `<div class="kpi-chip tend-${kpiAsig.tendencia_autonomia}"><span class="kpi-lbl">Tendencia</span><span>${kpiAsig.tendencia_autonomia}</span></div>` : ''}
      </div>
      <div class="rec rec-${recDir}">
        <strong>Recomendación de horas: ${recDir}</strong> — ${escHtml(asig.horas_recomendacion?.motivo || '')}
      </div>
    </div>`
  }).join('')

  const pFuertes = (ia.puntos_fuertes || []).map((p: string) => `<li>${escHtml(p)}</li>`).join('')
  const pMejora  = (ia.puntos_mejora || []).sort((a: any, b: any) => a.prioridad - b.prioridad).map((p: any) =>
    `<div class="mejora-item"><strong>${escHtml(p.asignatura)} — ${escHtml(p.tema)}</strong><p>${escHtml(p.descripcion)}</p></div>`
  ).join('')
  const logrosHtml    = (ia.logros || []).map((l: string) => `<li>${escHtml(l)}</li>`).join('')
  const objetivosHtml = (ia.objetivos_siguiente_periodo || []).map((o: string) => `<li>${escHtml(o)}</li>`).join('')
  const profHtml = (ia.cabecera?.profesores || []).map((p: any) =>
    `<tr><td>${escHtml(p.nombre)}</td><td>${(p.asignaturas || []).map((a: string) => escHtml(a)).join(', ')}</td></tr>`
  ).join('')

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escHtml(tipoLabel)} — ${escHtml(alumnoNombre)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Lora:ital,wght@0,400;0,500;1,400&display=swap" rel="stylesheet">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Lora',Georgia,serif;background:#f5f3ee;color:#1a1a2e;line-height:1.65;font-size:15px}
.page{max-width:820px;margin:0 auto;background:#fff;box-shadow:0 0 60px rgba(0,0,0,.1)}
.header{background:linear-gradient(135deg,#0d1b3e 0%,#1a3a6b 100%);color:#fff;padding:52px 52px 40px;position:relative}
.header::after{content:'';position:absolute;bottom:0;left:0;right:0;height:4px;background:linear-gradient(90deg,#c9a84c,#e8d5a3,#c9a84c)}
.logo{font-family:'Playfair Display',serif;font-size:13px;letter-spacing:3px;color:#c9a84c;text-transform:uppercase;margin-bottom:32px}
.h-name{font-family:'Playfair Display',serif;font-size:34px;font-weight:700;margin-bottom:8px}
.h-sub{color:#a8c4e0;font-size:14px;margin-bottom:24px}
.h-meta{display:flex;gap:28px;flex-wrap:wrap;font-size:13px;color:#c9a84c;border-top:1px solid rgba(255,255,255,.12);padding-top:18px}
.body{padding:44px 52px}
.section{margin-bottom:44px}
.sec-title{font-family:'Playfair Display',serif;font-size:20px;color:#0d1b3e;border-bottom:2px solid #c9a84c;padding-bottom:10px;margin-bottom:22px}
.resumen{background:#f0f4ff;border-left:4px solid #1a3a6b;padding:22px 26px;border-radius:0 10px 10px 0;line-height:1.75;color:#1a1a2e}
.kpi-global{display:grid;grid-template-columns:repeat(auto-fill,minmax(130px,1fr));gap:12px;margin-bottom:26px}
.kpi-box{background:#0d1b3e;color:#fff;border-radius:12px;padding:18px;text-align:center}
.kpi-box .num{font-family:'Playfair Display',serif;font-size:30px;color:#c9a84c;font-weight:700;display:block}
.kpi-box .lbl{font-size:11px;color:#a8c4e0;margin-top:5px;text-transform:uppercase;letter-spacing:.6px;display:block}
table.ptable{width:100%;border-collapse:collapse;font-size:13px}
table.ptable th{background:#f0f4ff;color:#0d1b3e;text-align:left;padding:11px 15px;border-bottom:1px solid #d0daf0;font-family:'Playfair Display',serif;font-weight:400}
table.ptable td{padding:11px 15px;border-bottom:1px solid #eee}
.asig-block{border:1px solid #e0e8f0;border-radius:14px;padding:28px;margin-bottom:26px;background:#fafcff}
.asig-header{display:flex;align-items:baseline;gap:14px;flex-wrap:wrap;margin-bottom:18px}
.asig-nombre{font-family:'Playfair Display',serif;font-size:20px;color:#0d1b3e;font-weight:700}
.asig-prof{color:#555;font-size:13px}
.asig-badge{margin-left:auto;background:#0d1b3e;color:#c9a84c;font-size:12px;font-weight:600;padding:5px 14px;border-radius:20px;white-space:nowrap}
.asig-analisis{line-height:1.75;margin-bottom:18px;color:#333}
.temas-sec{font-size:13px;color:#555;margin-bottom:18px}
.temas-sec ul{margin-top:7px;padding-left:22px}
.kpi-row{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:14px}
.kpi-chip{background:#f0f4ff;padding:8px 14px;border-radius:10px;font-size:12px;display:flex;flex-direction:column;gap:2px}
.kpi-lbl{font-size:10px;text-transform:uppercase;letter-spacing:.4px;color:#666}
.kpi-stars{color:#0d1b3e}
.kpi-nota{font-family:'Playfair Display',serif;font-size:22px;color:#c9a84c;font-weight:700}
.kpi-chip.tend-mejora{background:#d4edda;color:#155724}
.kpi-chip.tend-estable{background:#e2e3e5;color:#383d41}
.kpi-chip.tend-empeora{background:#f8d7da;color:#721c24}
.rec{font-size:13px;padding:12px 16px;border-radius:10px;margin-top:10px}
.rec-mantener{background:#e0f0ff;color:#0c4a6e}
.rec-aumentar{background:#fef3c7;color:#92400e}
.rec-reducir{background:#d4edda;color:#155724}
.lista{padding-left:22px}
.lista li{margin-bottom:10px;line-height:1.65}
.mejora-item{margin-bottom:14px;padding:16px 20px;border-left:3px solid #c9a84c;background:#fffbf0;border-radius:0 10px 10px 0}
.mejora-item strong{display:block;color:#0d1b3e;margin-bottom:5px;font-family:'Playfair Display',serif;font-weight:700;font-size:14px}
.mejora-item p{color:#333;font-size:14px;line-height:1.65}
.footer{background:#0d1b3e;color:#a8c4e0;text-align:center;padding:28px;font-size:13px}
.footer strong{color:#c9a84c}
.print-btn{position:fixed;bottom:28px;right:28px;background:#0d1b3e;color:#c9a84c;border:none;padding:14px 26px;border-radius:30px;font-size:14px;cursor:pointer;box-shadow:0 6px 24px rgba(0,0,0,.3);z-index:1000;font-family:'Lora',serif;font-weight:500;letter-spacing:.3px}
.print-btn:hover{background:#1a3a6b}
@media print{.print-btn{display:none}.page{box-shadow:none}body{background:#fff}}
@media(max-width:600px){.body,.header{padding-left:24px;padding-right:24px}.asig-badge{margin-left:0}}
</style>
</head>
<body>
<button class="print-btn" onclick="window.print()">🖨 Guardar como PDF</button>
<div class="page">
  <div class="header">
    <div class="logo">Nexo Académico · Valencia</div>
    <div class="h-name">${escHtml(alumnoNombre)}</div>
    <div class="h-sub">${escHtml(periodoLabel)}</div>
    <div class="h-meta">
      <span>📅 ${fmtFecha(informe.fecha_inicio)} – ${fmtFecha(informe.fecha_fin)}</span>
      <span>📚 ${global.asignaturas_distintas || '—'} asignatura${(global.asignaturas_distintas || 0) !== 1 ? 's' : ''}</span>
      <span>⏱ ${global.total_horas || '—'} h · ${global.total_sesiones || '—'} sesiones</span>
    </div>
  </div>

  <div class="body">
    <div class="section">
      <div class="sec-title">Resumen ejecutivo</div>
      <div class="resumen">${escHtml(ia.resumen_ejecutivo || '')}</div>
    </div>

    <div class="section">
      <div class="sec-title">Datos globales del periodo</div>
      <div class="kpi-global">
        <div class="kpi-box"><span class="num">${global.total_sesiones ?? '—'}</span><span class="lbl">Sesiones</span></div>
        <div class="kpi-box"><span class="num">${global.total_horas ?? '—'}</span><span class="lbl">Horas</span></div>
        <div class="kpi-box"><span class="num">${global.asignaturas_distintas ?? '—'}</span><span class="lbl">Asignaturas</span></div>
        <div class="kpi-box"><span class="num">${(global.profesores_distintos || []).length}</span><span class="lbl">Profesores</span></div>
      </div>
      ${profHtml ? `<table class="ptable"><thead><tr><th>Profesor/a</th><th>Asignaturas</th></tr></thead><tbody>${profHtml}</tbody></table>` : ''}
    </div>

    ${asigHtml ? `<div class="section"><div class="sec-title">Seguimiento por asignatura</div>${asigHtml}</div>` : ''}

    ${pFuertes ? `<div class="section"><div class="sec-title">Puntos fuertes</div><ul class="lista">${pFuertes}</ul></div>` : ''}

    ${pMejora ? `<div class="section"><div class="sec-title">Áreas de mejora</div>${pMejora}</div>` : ''}

    ${ia.patron_trabajo ? `<div class="section"><div class="sec-title">Patrón de trabajo</div><p style="line-height:1.75">${escHtml(ia.patron_trabajo)}</p></div>` : ''}

    ${ia.analisis_planificacion ? `<div class="section"><div class="sec-title">Análisis de planificación</div><p style="line-height:1.75">${escHtml(ia.analisis_planificacion)}</p></div>` : ''}

    ${logrosHtml ? `<div class="section"><div class="sec-title">Logros del periodo</div><ul class="lista">${logrosHtml}</ul></div>` : ''}

    ${objetivosHtml ? `<div class="section"><div class="sec-title">Objetivos del siguiente periodo</div><ul class="lista">${objetivosHtml}</ul></div>` : ''}
  </div>

  <div class="footer">
    Informe elaborado por <strong>Nexo Académico</strong> · Valencia<br>
    ${new Date().toLocaleDateString('es-ES', { day:'numeric', month:'long', year:'numeric' })}
  </div>
</div>
</body>
</html>`
}
