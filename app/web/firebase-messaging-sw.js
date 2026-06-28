/* Firebase Cloud Messaging service worker (web background push).
 *
 * firebase_messaging registers this file automatically when getToken() runs on
 * web. It shows the OS notification when a push arrives and the PWA tab is
 * backgrounded or closed.
 *
 * SETUP: replace the firebaseConfig values below with your project's web config
 * (Firebase console → Project settings → your web app → SDK config, or copy
 * from the generated lib/firebase_options.dart web block). Until then web push
 * stays inactive and the rest of the app is unaffected.
 */
importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: 'REPLACE_ME',
  appId: 'REPLACE_ME',
  messagingSenderId: 'REPLACE_ME',
  projectId: 'REPLACE_ME',
  authDomain: 'REPLACE_ME.firebaseapp.com',
};

// Only initialize once real values are present, so a placeholder SW never
// throws on every page load.
if (firebaseConfig.apiKey !== 'REPLACE_ME') {
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const name = (payload.data && payload.data.name) || 'A contact';
    self.registration.showNotification('🆘 ' + name + ' needs help', {
      body: name + ' flagged "Need help" in your network',
      icon: '/icons/Icon-192.png',
      tag: 'help-alert',
    });
  });
}
