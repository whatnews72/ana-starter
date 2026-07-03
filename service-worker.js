self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('push', event => {
  let d = {}; try { d = event.data ? event.data.json() : {}; } catch(e){ d = { body: event.data && event.data.text() }; }
  const title = d.title || '비서 업무 현황판';
  const opts = { body: d.body || '', icon: '/icon-192.png', badge: '/icon-192.png', tag: d.tag || 'ana', data: { url: d.url || '/' }, renotify: true };
  if (typeof d.count === 'number' && self.navigator && self.navigator.setAppBadge) {
    try { d.count ? self.navigator.setAppBadge(d.count) : self.navigator.clearAppBadge(); } catch (e) {}
  }
  event.waitUntil(self.registration.showNotification(title, opts));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(clients.matchAll({ type:'window', includeUncontrolled:true }).then(cl => {
    for (const c of cl) { if ('focus' in c) return c.focus(); }
    if (clients.openWindow) return clients.openWindow(url);
  }));
});
