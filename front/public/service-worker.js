/*
 * MindMate Service Worker for Web Push Notifications
 * ==================================================
 * Handles incoming VAPID-encrypted push events, applies security privacy filters
 * (is_sensitive check), and manages deep-link browser tab navigation.
 */

self.addEventListener('push', function(event) {
    if (!event.data) {
        console.warn('MindMate: Push event received with no data payload.');
        return;
    }

    let payload = {};
    try {
        payload = event.data.json();
    } catch (err) {
        console.error('MindMate: Failed to parse incoming push payload JSON:', err);
        return;
    }

    let title = payload.title || 'MindMate Alert';
    let body = payload.body || 'You have a new update.';
    const isSensitive = payload.is_sensitive || false;
    const deepLinkUrl = payload.url || '/';

    // Privacy screening: Mask notification details if flagged as sensitive (e.g. psychiatric reports, daily tasks)
    if (isSensitive) {
        title = 'Secure Notification';
        body = 'You have a new secure message.';
    }

    const options = {
        body: body,
        icon: '/logo.png', // Fallback profile icon
        badge: '/badge.png', // Mobile notification drawer icon
        vibrate: [100, 50, 100],
        data: {
            url: deepLinkUrl
        },
        actions: [
            { action: 'open', title: 'Open MindMate' }
        ]
    };

    event.waitUntil(
        self.registration.showNotification(title, options)
    );
});

self.addEventListener('notificationclick', function(event) {
    event.notification.close();

    const targetUrl = event.notification.data && event.notification.data.url 
        ? event.notification.data.url 
        : '/';

    // Focus existing window or open a new browser tab for deep-linking
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
            // Check if application is already open in a tab
            for (let i = 0; i < windowClients.length; i++) {
                const client = windowClients[i];
                if (client.url.includes(targetUrl) && 'focus' in client) {
                    return client.focus();
                }
            }
            // If not already open, navigate new window
            if (clients.openWindow) {
                return clients.openWindow(targetUrl);
            }
        })
    );
});
