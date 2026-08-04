import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const url = new URL(req.url)
  const id  = url.searchParams.get('id')

  if (!id) {
    return new Response('Informe no encontrado', { status: 404 })
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const { data: informe, error } = await admin
    .from('informes')
    .select('html_cache, estado, eliminado')
    .eq('id', id)
    .single()

  if (error || !informe) {
    return new Response('Informe no encontrado', { status: 404 })
  }

  if (informe.eliminado || informe.estado !== 'visible') {
    return new Response('Informe no disponible', { status: 403 })
  }

  if (!informe.html_cache) {
    return new Response('Informe sin contenido publicado', { status: 404 })
  }

  return new Response(informe.html_cache, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  })
})
