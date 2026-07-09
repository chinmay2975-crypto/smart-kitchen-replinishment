// Minimal app-shell service worker. This exists to satisfy PWA installability
// (a registered fetch handler is required) — it deliberately does NOT cache
// any /api/ calls, since the app is almost entirely live-data driven and a
// stale cached API response would be a worse experience than no offline
// support at all.
const CACHE_VERSION = 'smart-kitchen-v2'; // bump when shell files change

const APP_SHELL = [
    '/',
    '/index.html',
    '/css/style.css',
    '/js/api.js',
    '/js/auth.js',
    '/js/dashboard.js',
    '/js/devices.js',
    '/js/cart.js',
    '/js/profile.js',
    '/js/app.js',
    '/manifest.json',
];

self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_VERSION).then((cache) => cache.addAll(APP_SHELL))
    );
    self.skipWaiting();
});

self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keys) =>
            Promise.all(
                keys.filter((key) => key !== CACHE_VERSION).map((key) => caches.delete(key))
            )
        )
    );
    self.clients.claim();
});

self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    // Never intercept cross-origin (the API lives on a different origin) or
    // /api/ requests — always go straight to the network, untouched.
    if (url.origin !== self.location.origin || url.pathname.startsWith('/api/')) {
        return;
    }

    if (event.request.method !== 'GET') {
        return;
    }

    event.respondWith(
        fetch(event.request)
            .then((networkResponse) => {
                const responseClone = networkResponse.clone();
                caches.open(CACHE_VERSION).then((cache) => cache.put(event.request, responseClone));
                return networkResponse;
            })
            .catch(() => caches.match(event.request))
    );
});
