// Shreeji Client Order Management Portal - Service Worker
const CACHE_NAME = 'shreeji-portal-shell-v1';
const STATIC_ASSETS = [
  './index.html',
  './manifest.webmanifest',
  './assets/icon-192.png',
  './assets/icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch((err) => {
        console.warn('Non-blocking asset cache warning:', err);
      });
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    })
  );
  self.clients.claim();
});

// CRITICAL SECURITY ENFORCEMENT:
// NEVER cache private order API responses, authentication tokens or confidential hospital data.
self.addEventListener('fetch', (event) => {
  const requestUrl = new URL(event.request.url);

  // Exclude API requests, webhook endpoints, ngrok endpoints, or dynamic data queries from cache
  const isApiRequest = requestUrl.pathname.includes('/webhook') ||
                       requestUrl.pathname.includes('/api') ||
                       requestUrl.searchParams.has('token') ||
                       event.request.headers.has('Authorization');

  if (isApiRequest || event.request.method !== 'GET') {
    // Direct network bypass for all confidential API communication
    event.respondWith(fetch(event.request));
    return;
  }

  // Network-first for static shell with cache fallback
  event.respondWith(
    fetch(event.request)
      .then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseToCache = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseToCache));
        }
        return networkResponse;
      })
      .catch(() => caches.match(event.request))
  );
});
