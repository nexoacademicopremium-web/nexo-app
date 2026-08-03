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

    const htmlBlob = new Blob([html], { type: 'text/html; charset=utf-8' })
    const storagePath = `informes/${informe.alumno_id}/${informe_id}.html`

    const { error: storageErr } = await admin.storage
      .from('nexo-files')
      .upload(storagePath, htmlBlob, { contentType: 'text/html; charset=utf-8', upsert: true })
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
  const asigs  = kpis.asignaturas || []
  const tipoLabel = informe.tipo === 'mensual' ? 'Informe mensual' : 'Informe personalizado'
  const mesLabel = informe.tipo === 'mensual'
    ? new Date(informe.fecha_inicio).toLocaleDateString('es-ES', { month: 'long', year: 'numeric', timeZone: 'UTC' })
    : `${fmtFecha(informe.fecha_inicio)} – ${fmtFecha(informe.fecha_fin)}`

  const avgVal = (field: string) => {
    const vals = asigs.map((a: any) => a.valoraciones?.[field]).filter((v: any) => v != null)
    return vals.length ? Math.round(vals.reduce((s: number, v: number) => s + v, 0) / vals.length * 10) / 10 : null
  }
  const avgNota = (() => {
    const vals = asigs.map((a: any) => a.nota_media).filter((v: any) => v != null)
    return vals.length ? Math.round(vals.reduce((s: number, v: number) => s + v, 0) / vals.length * 10) / 10 : null
  })()
  const comprAvg = avgVal('comprension')
  const aplicAvg = avgVal('aplicacion')
  const motivAvg = avgVal('motivacion')
  const autAvg   = avgVal('autonomia')
  const concAvg  = avgVal('concentracion')

  const notaColor = (n: number | null) =>
    n == null ? 'var(--azul-cla)' : n >= 7 ? 'var(--teal-light)' : n >= 5 ? 'var(--amber)' : 'var(--red)'

  const asigCards = asigs.map((a: any) => {
    const nota = a.nota_media
    const col  = notaColor(nota)
    const tend = a.tendencia_autonomia
    const tagStyle = tend === 'mejora'
      ? 'background:rgba(79,201,154,0.12);color:var(--teal-light);border:1px solid rgba(79,201,154,0.2)'
      : tend === 'empeora'
        ? 'background:rgba(248,113,113,0.12);color:var(--red);border:1px solid rgba(248,113,113,0.2)'
        : 'background:rgba(245,158,11,0.12);color:var(--amber);border:1px solid rgba(245,158,11,0.2)'
    const tagLabel = tend === 'mejora' ? 'Progresa' : tend === 'empeora' ? 'Alerta' : 'Estable'
    return `<div class="sem-card">
      <div class="sem-label">${escHtml(a.nombre)}</div>
      <span class="sem-tag" style="${tagStyle}">${tagLabel}</span>
      <div class="sem-nota" style="color:${col}">${nota != null ? nota.toFixed(1) : '—'}</div>
      <div class="sem-desc">${a.num_sesiones || '—'} ses. · ${a.horas_totales || '—'} h${a.profesor ? ' · Prof. ' + escHtml(a.profesor) : ''}</div>
    </div>`
  }).join('')

  const metricRows = [
    { label: 'Motivación',    val: motivAvg, col: 'var(--teal-light)' },
    { label: 'Comprensión',   val: comprAvg, col: 'var(--teal-light)' },
    { label: 'Concentración', val: concAvg,  col: 'var(--azul-cla)'   },
    { label: 'Autonomía',     val: autAvg,   col: 'var(--amber)'       },
    { label: 'Aplicación',    val: aplicAvg, col: 'var(--red)'         },
  ].filter(m => m.val != null).map(m => `<div class="metric-row">
    <div class="metric-label"><span>${m.label}</span><span style="color:${m.col}">${(m.val as number).toFixed(1)}</span></div>
    <div class="metric-track"><div class="metric-fill" style="background:${m.col}" data-w="${Math.round((m.val as number) * 10)}"></div></div>
  </div>`).join('')

  const fortalezas = (ia.puntos_fuertes || []).map((p: string) =>
    `<div class="item-card green"><div class="item-title">✓ ${escHtml(p)}</div></div>`
  ).join('')

  const criticos = (ia.puntos_mejora || [])
    .sort((a: any, b: any) => a.prioridad - b.prioridad)
    .map((p: any, i: number) => {
      const badge = i === 0 ? '<span class="badge-crit">Crítico</span>' : '<span class="badge-high">Alto</span>'
      return `<div class="item-card ${i === 0 ? 'red' : 'amber'}">
        <div class="item-title">${escHtml(p.asignatura)} — ${escHtml(p.tema)} ${badge}</div>
        <div class="item-desc">${escHtml(p.descripcion)}</div>
      </div>`
    }).join('')

  const objetivosRows = (ia.objetivos_siguiente_periodo || []).map((o: string, i: number) =>
    `<tr><td><span class="sem-pill">Obj. ${i + 1}</span></td><td>${escHtml(o)}</td></tr>`
  ).join('')

  const profList = (ia.cabecera?.profesores || []).map((p: any) =>
    `<strong>${escHtml(p.nombre)}</strong> <span style="opacity:.6;font-size:12px">(${(p.asignaturas || []).map((a: string) => escHtml(a)).join(', ')})</span>`
  ).join(' · ')

  const radarData   = JSON.stringify([motivAvg ?? 0, comprAvg ?? 0, concAvg ?? 0, autAvg ?? 0, aplicAvg ?? 0])
  const barLabels   = JSON.stringify(asigs.map((a: any) => a.nombre))
  const barData     = JSON.stringify(asigs.map((a: any) => a.nota_media ?? 0))
  const barApproval = JSON.stringify(asigs.map((_: any) => 5))
  const kpiNotaTarget  = avgNota  != null ? Math.round(avgNota  * 10) : null
  const kpiComprTarget = comprAvg != null ? Math.round(comprAvg * 10) : null

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${escHtml(tipoLabel)} — ${escHtml(alumnoNombre)}</title>
<link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display:ital@0;1&family=DM+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"><\/script>
<style>
:root{--navy:#04071b;--azul:#154ca9;--azul-cla:#6eaef0;--teal-light:#4fc99a;--amber:#f59e0b;--red:#f87171;--white:#ffffff;--muted:rgba(255,255,255,0.45);--border:rgba(110,174,240,0.12);--card:rgba(110,174,240,0.05)}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{background:var(--navy);color:var(--white);font-family:'DM Sans',sans-serif;min-height:100vh}
body::before{content:'';position:fixed;inset:0;z-index:0;background:radial-gradient(ellipse 60% 40% at 8% 12%,rgba(21,76,169,.20) 0%,transparent 55%),radial-gradient(ellipse 50% 50% at 92% 85%,rgba(26,148,112,.10) 0%,transparent 55%);pointer-events:none}
.wrap{position:relative;z-index:1;max-width:900px;margin:0 auto;padding:0 24px 80px}
@keyframes fadeUp{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}
.fade{animation:fadeUp .55s cubic-bezier(.16,1,.3,1) both}
.d1{animation-delay:.05s}.d2{animation-delay:.13s}.d3{animation-delay:.21s}.d4{animation-delay:.29s}.d5{animation-delay:.37s}.d6{animation-delay:.45s}.d7{animation-delay:.53s}.d8{animation-delay:.61s}
header{display:flex;align-items:center;justify-content:space-between;padding:32px 0 36px;border-bottom:1px solid var(--border);margin-bottom:48px;animation:fadeUp .5s ease both}
.logo-text{font-family:'DM Serif Display',serif;font-size:20px;letter-spacing:-.3px}
.logo-text em{color:var(--azul-cla);font-style:normal}
.header-meta{text-align:right}
.header-meta .periodo{font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:var(--azul-cla)}
.header-meta .doc-type{font-size:11px;color:var(--muted);margin-top:3px}
.hero{margin-bottom:52px}
.hero-sup{font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:var(--teal-light);margin-bottom:10px}
.hero h1{font-family:'DM Serif Display',serif;font-size:clamp(34px,5vw,52px);line-height:1.05;letter-spacing:-.5px;margin-bottom:6px}
.hero-sub{font-size:15px;color:var(--muted)}
.kpi-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:48px}
@media(max-width:640px){.kpi-grid{grid-template-columns:repeat(2,1fr)}}
.kpi-card{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:22px 18px;transition:transform .2s,border-color .2s,box-shadow .2s;cursor:default}
.kpi-card:hover{transform:translateY(-3px);border-color:rgba(110,174,240,.28);box-shadow:0 16px 48px rgba(0,0,0,.25)}
.kpi-label{font-size:10px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:var(--muted);margin-bottom:12px}
.kpi-val{font-family:'DM Serif Display',serif;font-size:38px;line-height:1;margin-bottom:6px}
.kpi-delta{font-size:11px;font-weight:700;color:var(--teal-light)}
.section-title{font-family:'DM Serif Display',serif;font-size:22px;margin-bottom:22px;display:flex;align-items:center;gap:12px}
.section-title::after{content:'';flex:1;height:1px;background:var(--border)}
.chart-card{background:var(--card);border:1px solid var(--border);border-radius:18px;padding:28px;margin-bottom:24px}
.chart-header{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:24px}
.chart-title{font-family:'DM Serif Display',serif;font-size:18px}
.chart-sub{font-size:12px;color:var(--muted);margin-top:3px}
.chart-tag{font-size:10px;font-weight:700;letter-spacing:1px;text-transform:uppercase;padding:5px 12px;border-radius:20px}
.tag-up{color:var(--teal-light);background:rgba(79,201,154,.1);border:1px solid rgba(79,201,154,.2)}
.tag-warn{color:var(--amber);background:rgba(245,158,11,.1);border:1px solid rgba(245,158,11,.2)}
.tag-crit{color:var(--red);background:rgba(248,113,113,.1);border:1px solid rgba(248,113,113,.2)}
.chart-wrap{position:relative;height:220px}
.two-col{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-bottom:24px}
@media(max-width:640px){.two-col{grid-template-columns:1fr}}
.semanas-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:12px;margin-bottom:24px}
.sem-card{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:18px 16px;transition:transform .2s,border-color .2s}
.sem-card:hover{transform:translateY(-2px);border-color:rgba(110,174,240,.25)}
.sem-label{font-size:10px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:var(--muted);margin-bottom:4px}
.sem-tag{display:inline-block;font-size:9px;font-weight:700;letter-spacing:1px;text-transform:uppercase;padding:2px 8px;border-radius:10px;margin-bottom:10px}
.sem-nota{font-family:'DM Serif Display',serif;font-size:30px;margin-bottom:8px}
.sem-desc{font-size:11px;color:var(--muted);line-height:1.5}
.metric-row{margin-bottom:16px}
.metric-label{display:flex;justify-content:space-between;font-size:13px;margin-bottom:7px}
.metric-label span:last-child{font-weight:700}
.metric-track{height:7px;background:rgba(255,255,255,.07);border-radius:99px;overflow:hidden}
.metric-fill{height:100%;border-radius:99px;width:0;transition:width 1.1s cubic-bezier(.16,1,.3,1)}
.items-grid{display:flex;flex-direction:column;gap:12px}
.item-card{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:20px 22px;border-left:3px solid transparent;transition:background .2s}
.item-card:hover{background:rgba(110,174,240,.07)}
.item-card.green{border-left-color:var(--teal-light)}.item-card.amber{border-left-color:var(--amber)}.item-card.red{border-left-color:var(--red)}
.item-title{font-weight:700;font-size:14px;margin-bottom:5px;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.item-desc{font-size:13px;color:var(--muted);line-height:1.55}
.badge-crit{font-size:9px;font-weight:700;letter-spacing:1px;text-transform:uppercase;padding:2px 8px;border-radius:10px;background:rgba(248,113,113,.15);color:var(--red);border:1px solid rgba(248,113,113,.25)}
.badge-high{font-size:9px;font-weight:700;letter-spacing:1px;text-transform:uppercase;padding:2px 8px;border-radius:10px;background:rgba(245,158,11,.12);color:var(--amber);border:1px solid rgba(245,158,11,.2)}
.plan-table{width:100%;border-collapse:collapse}
.plan-table th{font-size:10px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:var(--muted);padding:0 16px 12px;text-align:left;border-bottom:1px solid var(--border)}
.plan-table td{padding:13px 16px;font-size:13px;border-bottom:1px solid rgba(255,255,255,.04);vertical-align:top}
.plan-table tr:last-child td{border-bottom:none}
.plan-table tr:hover td{background:rgba(255,255,255,.015)}
.sem-pill{display:inline-block;font-size:10px;font-weight:700;padding:3px 10px;border-radius:20px;background:rgba(110,174,240,.1);color:var(--azul-cla);border:1px solid rgba(110,174,240,.2);white-space:nowrap}
.mensaje-card{background:linear-gradient(135deg,rgba(21,76,169,.12),rgba(26,148,112,.08));border:1px solid rgba(110,174,240,.2);border-radius:18px;padding:32px;margin-bottom:24px}
.mensaje-card p{font-size:15px;line-height:1.7;color:rgba(255,255,255,.85)}
.mensaje-firma{margin-top:16px;font-size:13px;font-weight:600;color:var(--azul-cla)}
footer{margin-top:60px;padding-top:28px;border-top:1px solid var(--border);display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px}
.footer-logo{font-family:'DM Serif Display',serif;font-size:15px;opacity:.4}
.footer-meta{font-size:11px;color:var(--muted);text-align:right}
@media print{body,body::before{background:none}body{color:#111}:root{--white:#111;--muted:#555;--border:#ccc;--card:#f5f5f5}.wrap{padding-bottom:20px}}
</style>
</head>
<body>
<div class="wrap">

<header>
  <div class="logo-text">Nexo <em>Académico</em></div>
  <div class="header-meta">
    <div class="periodo">${escHtml(mesLabel)}</div>
    <div class="doc-type">${escHtml(tipoLabel)}</div>
  </div>
</header>

<div class="hero fade d1">
  <div class="hero-sup">Informe de progreso</div>
  <h1>${escHtml(alumnoNombre)}</h1>
  <div class="hero-sub">${profList || 'Nexo Académico · Valencia'}</div>
</div>

<div class="kpi-grid fade d2">
  <div class="kpi-card">
    <div class="kpi-label">Nota media</div>
    <div class="kpi-val" style="color:var(--amber)"${kpiNotaTarget != null ? ` data-target="${kpiNotaTarget}"` : ''}>${avgNota != null ? avgNota.toFixed(1) : '—'}</div>
    <div class="kpi-delta">Estimada · periodo completo</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">Comprensión</div>
    <div class="kpi-val" style="color:var(--teal-light)"${kpiComprTarget != null ? ` data-target="${kpiComprTarget}"` : ''}>${comprAvg != null ? comprAvg.toFixed(1) : '—'}</div>
    <div class="kpi-delta">Media del periodo</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">Sesiones</div>
    <div class="kpi-val" style="color:var(--azul-cla)">${global.total_sesiones ?? '—'}</div>
    <div class="kpi-delta">${global.total_horas ?? '—'} horas totales</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">Asignaturas</div>
    <div class="kpi-val" style="color:var(--teal-light)">${global.asignaturas_distintas ?? '—'}</div>
    <div class="kpi-delta">${(global.profesores_distintos || []).length} profesor${(global.profesores_distintos || []).length !== 1 ? 'es' : ''}</div>
  </div>
</div>

${asigCards ? `<div class="fade d3">
  <div class="section-title">Seguimiento por asignatura</div>
  <div class="semanas-grid">${asigCards}</div>
</div>` : ''}

<div class="two-col fade d4">
  <div class="chart-card" style="margin-bottom:0">
    <div class="chart-header" style="margin-bottom:20px">
      <div><div class="chart-title">Métricas detalladas</div><div class="chart-sub">Media del periodo · escala 1–10</div></div>
    </div>
    ${metricRows || '<p style="color:var(--muted);font-size:13px">Sin datos de valoraciones</p>'}
  </div>
  <div class="chart-card" style="margin-bottom:0">
    <div class="chart-header" style="margin-bottom:20px">
      <div><div class="chart-title">Perfil de aprendizaje</div><div class="chart-sub">Radar de competencias</div></div>
    </div>
    <div class="chart-wrap" style="height:200px"><canvas id="chartRadar"></canvas></div>
  </div>
</div>

${asigs.length > 1 ? `<div class="chart-card fade d4">
  <div class="chart-header">
    <div><div class="chart-title">Nota estimada por asignatura</div><div class="chart-sub">Escala 0–10 · línea = aprobado (5.0)</div></div>
  </div>
  <div class="chart-wrap"><canvas id="chartBar"></canvas></div>
</div>` : ''}

<div style="margin-bottom:48px"></div>

${fortalezas ? `<div class="fade d5">
  <div class="section-title">Lo que está funcionando</div>
  <div class="items-grid">${fortalezas}</div>
</div><div style="margin-bottom:48px"></div>` : ''}

${criticos ? `<div class="fade d6">
  <div class="section-title">Puntos de mejora</div>
  <div class="items-grid">${criticos}</div>
</div><div style="margin-bottom:48px"></div>` : ''}

${objetivosRows ? `<div class="fade d7">
  <div class="section-title">Objetivos del siguiente periodo</div>
  <div class="chart-card">
    <table class="plan-table">
      <thead><tr><th></th><th>Objetivo</th></tr></thead>
      <tbody>${objetivosRows}</tbody>
    </table>
  </div>
</div>` : ''}

${ia.resumen_ejecutivo ? `<div class="mensaje-card fade d8">
  <p>${escHtml(ia.resumen_ejecutivo)}</p>
  <div class="mensaje-firma">— Nexo Académico · Valencia</div>
</div>` : ''}

<footer>
  <div class="footer-logo">Nexo Académico</div>
  <div class="footer-meta">
    nexoacademico.es · nexoacademicopremium@gmail.com · 611 49 25 92<br>
    ${new Date().toLocaleDateString('es-ES', { day: 'numeric', month: 'long', year: 'numeric' })}
  </div>
</footer>
</div>

<script>
document.querySelectorAll('[data-target]').forEach(function(el) {
  var raw = parseInt(el.dataset.target, 10), val = raw / 10, start = performance.now();
  (function tick(now) {
    var p = Math.min((now - start) / 1100, 1), e = 1 - Math.pow(1 - p, 3);
    el.textContent = (val * e).toFixed(1);
    if (p < 1) requestAnimationFrame(tick);
  })(performance.now());
});
setTimeout(function() {
  document.querySelectorAll('.metric-fill[data-w]').forEach(function(el) { el.style.width = el.dataset.w + '%'; });
}, 400);
Chart.defaults.color = 'rgba(255,255,255,0.42)';
Chart.defaults.font.family = 'DM Sans';
Chart.defaults.font.size = 12;
var grid = 'rgba(255,255,255,0.06)';
new Chart(document.getElementById('chartRadar'), {
  type: 'radar',
  data: {
    labels: ['Motivación','Comprensión','Concentración','Autonomía','Aplicación'],
    datasets: [{ data: ${radarData}, backgroundColor: 'rgba(110,174,240,0.12)', borderColor: '#6eaef0', borderWidth: 2, pointBackgroundColor: '#6eaef0', pointRadius: 4 }]
  },
  options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } },
    scales: { r: { min: 0, max: 10, grid: { color: grid }, angleLines: { color: grid },
      ticks: { stepSize: 2, backdropColor: 'transparent', color: 'rgba(255,255,255,0.3)', font: { size: 10 } },
      pointLabels: { color: 'rgba(255,255,255,0.55)', font: { size: 11 } } } } }
});
${asigs.length > 1 ? `var bc = document.getElementById('chartBar');
if (bc) {
  var bg = bc.getContext('2d').createLinearGradient(0,0,0,220);
  bg.addColorStop(0,'rgba(110,174,240,0.5)'); bg.addColorStop(1,'rgba(110,174,240,0.1)');
  new Chart(bc, { type: 'bar',
    data: { labels: ${barLabels}, datasets: [
      { label: 'Nota media', data: ${barData}, backgroundColor: bg, borderColor: '#6eaef0', borderWidth: 1.5, borderRadius: 8 },
      { label: 'Aprobado', data: ${barApproval}, type: 'line', borderColor: 'rgba(248,113,113,0.5)', borderWidth: 1.5, borderDash: [6,4], pointRadius: 0, fill: false }
    ]},
    options: { responsive: true, maintainAspectRatio: false,
      plugins: { legend: { position: 'bottom', labels: { usePointStyle: true, padding: 16 } } },
      scales: { x: { grid: { color: grid }, border: { display: false } },
                y: { grid: { color: grid }, border: { display: false }, min: 0, max: 10, ticks: { stepSize: 2 } } } }
  });
}` : ''}
<\/script>
</body>
</html>`
}
