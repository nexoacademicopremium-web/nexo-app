import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Orígenes desde los que se sirve la app. Se refleja el Origin cuando está
// en la lista; si no, se responde con el dominio de producción.
const ORIGENES = [
  'https://app.nexoacademico.com',
  'https://nexoacademico.com',
  'http://localhost:3000',
  'http://localhost:5173',
  'http://127.0.0.1:5500',
]

function cors(req: Request) {
  const origin = req.headers.get('Origin') || ''
  const permitido = ORIGENES.includes(origin) || origin.endsWith('.netlify.app')
  return {
    'Access-Control-Allow-Origin': permitido ? origin : 'https://app.nexoacademico.com',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Vary': 'Origin',
  }
}

// ¿La petición trae la sesión de un administrador?
// Solo se usa para dejar que el admin revise informes aún sin publicar.
async function esAdmin(req: Request): Promise<boolean> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return false
  try {
    const caller = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user } } = await caller.auth.getUser()
    if (!user) return false
    const { data: perfil } = await caller
      .from('usuarios').select('rol').eq('id', user.id).single()
    return perfil?.rol === 'admin'
  } catch {
    return false
  }
}

serve(async (req) => {
  const H = cors(req)
  if (req.method === 'OPTIONS') return new Response('ok', { headers: H })

  const url      = new URL(req.url)
  const id       = url.searchParams.get('id')
  const token    = url.searchParams.get('t')
  const wantsPdf = url.searchParams.get('pdf') === '1'

  if (!id || !token) {
    return new Response('Enlace inválido', { status: 400, headers: H })
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
    return new Response('Informe no encontrado', { status: 404, headers: H })
  }

  // Comparación en tiempo constante para no filtrar el token carácter a carácter
  const a = new TextEncoder().encode(String(informe.token ?? ''))
  const b = new TextEncoder().encode(token)
  let diff = a.length ^ b.length
  for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0)
  if (diff !== 0) {
    return new Response('Acceso denegado', { status: 403, headers: H })
  }

  if (informe.token_expira && new Date(informe.token_expira) < new Date()) {
    return new Response('Este enlace ha caducado. Pide uno nuevo a Nexo Académico.', { status: 403, headers: H })
  }

  if (informe.eliminado) {
    return new Response('Informe no disponible', { status: 403, headers: H })
  }

  // El informe oculto solo lo abre el admin, para revisarlo antes de publicar.
  if (informe.estado !== 'visible' && !(await esAdmin(req))) {
    return new Response('Este informe todavía no está publicado.', { status: 403, headers: H })
  }

  // ── Descarga del PDF ────────────────────────────────────────────
  // Se sirve el binario desde aquí en vez de redirigir al bucket: un
  // redirect pierde las cabeceras CORS y el navegador lo bloquea.
  if (wantsPdf) {
    if (!informe.pdf_path) {
      return new Response('Este informe no tiene PDF disponible', { status: 404, headers: H })
    }
    const { data: fichero, error: dlErr } = await admin.storage
      .from('nexo-files')
      .download(informe.pdf_path)

    if (dlErr || !fichero) {
      console.error('Descarga del PDF fallida:', dlErr?.message)
      return new Response('No se ha podido preparar la descarga', { status: 500, headers: H })
    }

    const nombre = `${(informe.titulo || 'Informe').replace(/[^\p{L}\p{N} .\-]/gu, '')}.pdf`
    return new Response(fichero, {
      headers: {
        ...H,
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${nombre}"`,
        'Cache-Control': 'private, no-store',
        'X-Robots-Tag': 'noindex, nofollow',
      },
    })
  }

  if (!informe.html_cache) {
    return new Response('Informe sin contenido publicado', { status: 404, headers: H })
  }

  return new Response(informe.html_cache, {
    headers: {
      ...H,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'private, no-store',
      'X-Robots-Tag': 'noindex, nofollow',
    },
  })
})
