// Service worker для фоновых web-push через Firebase Cloud Messaging.
// Показывает уведомление, когда вкладка приложения не активна.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCGw4XlMGVnFxe8qU4TATe3aK_a7vBDRlk',
  appId: '1:653897955390:web:bb74e728b3f14f8d73f96f',
  messagingSenderId: '653897955390',
  projectId: 'panorama-kg',
  authDomain: 'panorama-kg.firebaseapp.com',
  storageBucket: 'panorama-kg.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'Panorama', {
    body: n.body || '',
    icon: '/icons/Icon-192.png',
  });
});
