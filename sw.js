// ============================================================
// NEXO ACADÉMICO — Service Worker
// Se encarga de recibir las notificaciones push aunque la web
// esté cerrada. No cachea nada: la app siempre va contra la red.
// ============================================================

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let datos = {};
  try {
    datos = event.data ? event.data.json() : {};
  } catch {
    datos = { titulo: 'Nexo Académico', cuerpo: event.data ? event.data.text() : '' };
  }

  const titulo = datos.titulo || 'Nexo Académico';
  const opciones = {
    body:  datos.cuerpo || '',
    icon:  '/assets/logo/icon-192.png',
    badge: '/assets/logo/icon-192.png',
    tag:   datos.tag || 'nexo-aviso',
    // Con renotify, un aviso nuevo del mismo tipo vuelve a sonar
    // en vez de reemplazar el anterior en silencio.
    renotify: true,
    requireInteraction: datos.importante === true,
    data: { url: datos.url || '/' },
  };

  event.waitUntil(self.registration.showNotification(titulo, opciones));
});

// Al tocar la notificación: si la app ya está abierta, se enfoca esa
// pestaña en vez de abrir otra.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const destino = event.notification.data?.url || '/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((listaClientes) => {
      for (const cliente of listaClientes) {
        if ('focus' in cliente) {
          if ('navigate' in cliente && destino !== '/') cliente.navigate(destino);
          return cliente.focus();
        }
      }
      return self.clients.openWindow(destino);
    })
  );
});
