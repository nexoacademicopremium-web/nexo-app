import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Este endpoint es público a propósito (las familias abren el enlace desde el
// correo sin tener sesión), por eso toda la protección recae en el token.
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.nexoacademico.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const url    = new URL(req.url)
  const id     = url.searchParams.get('id')
  const token  = url.searchParams.get('t')
  const wantsPdf = url.searchParams.get('pdf') === '1'

  if (!id || !token) {
    return new Response('Enlace inválido', { status: 400, headers: corsHeaders })
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const { data: informe, error } = await admin
    .from('informes')
    .select('html_cache, estado, eliminado, token, token_expira, pdf_path, titulo')
    .eq('id', id)
    .single()

  if (error || !informe) {
    return new Response('Informe no encontrado', { status: 404, headers: corsHeaders })
  }

  // Comparación en tiempo constante para no filtrar el token carácter a carácter
  const a = new TextEncoder().encode(String(informe.token ?? ''))
  const b = new TextEncoder().encode(token)
  let diff = a.length ^ b.length
  for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0)
  if (diff !== 0) {
    return new Response('Acceso denegado', { status: 403, headers: corsHeaders })
  }

  if (informe.token_expira && new Date(informe.token_expira) < new Date()) {
    return new Response('Este enlace ha caducado. Pide uno nuevo a Nexo Académico.', { status: 403, headers: corsHeaders })
  }

  if (informe.eliminado || informe.estado !== 'visible') {
    return new Response('Informe no disponible', { status: 403, headers: corsHeaders })
  }

  // ── Descarga del PDF: enlace firmado de corta duración ──────────
  if (wantsPdf) {
    if (!informe.pdf_path) {
      return new Response('Este informe no tiene PDF disponible', { status: 404, headers: corsHeaders })
    }
    const { data: signed, error: signErr } = await admin.storage
      .from('nexo-files')
      .createSignedUrl(informe.pdf_path, 120, { download: `${(informe.titulo || 'Informe').replace(/[^\w\s.-]/g, '')}.pdf` })

    if (signErr || !signed?.signedUrl) {
      return new Response('No se ha podido preparar la descarga', { status: 500, headers: corsHeaders })
    }
    return Response.redirect(signed.signedUrl, 302)
  }

  if (!informe.html_cache) {
    return new Response('Informe sin contenido publicado', { status: 404, headers: corsHeaders })
  }

  return new Response(informe.html_cache, {
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'private, no-store',
      'X-Robots-Tag': 'noindex, nofollow',
    },
  })
})
