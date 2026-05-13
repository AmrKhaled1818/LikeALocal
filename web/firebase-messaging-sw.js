importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyADU7RGANoFHDs7sq7E9F5j0J6jKn-9s10",
  authDomain: "likealocal-73fbf.firebaseapp.com",
  projectId: "likealocal-73fbf",
  storageBucket: "likealocal-73fbf.firebasestorage.app",
  messagingSenderId: "677586201088",
  appId: "1:677586201088:web:5531700898cbfb1afa06e5",
  measurementId: "G-EL3KW84Y1D"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  const notificationTitle = payload.notification?.title ?? 'LikeALocal';
  const notificationOptions = {
    body: payload.notification?.body ?? '',
    icon: '/icons/Icon-192.png'
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});
