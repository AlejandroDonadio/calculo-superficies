/* Service worker: la app funciona sin conexión después de la primera visita.
   Estrategia red-primero: si hay internet se sirve la última versión publicada
   y se actualiza la copia local; sin internet se usa la copia guardada. */
var CACHE = 'calc-superficies-v91';
var ASSETS = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './icon-180.png', './logo.svg'];

self.addEventListener('install', function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(ASSETS); }));
  self.skipWaiting();
});

self.addEventListener('activate', function (e) {
  e.waitUntil(caches.keys().then(function (keys) {
    return Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }));
  self.clients.claim();
});

self.addEventListener('fetch', function (e) {
  if (e.request.method !== 'GET') return;
  /* version.txt nunca se guarda: es el que avisa si hay una versión nueva publicada */
  if (e.request.url.indexOf('version.txt') >= 0) return;
  e.respondWith(
    fetch(e.request).then(function (r) {
      var copy = r.clone();
      if (r.ok && e.request.url.indexOf(self.location.origin) === 0) {
        caches.open(CACHE).then(function (c) { c.put(e.request, copy); });
      }
      return r;
    }).catch(function () {
      return caches.match(e.request).then(function (m) { return m || caches.match('./index.html'); });
    })
  );
});
