---
id: notification-delegate-assigned-after-launch
status: backlog
priority: medium
area: notifications
created: 2026-10-10
updated: 2026-10-10
source: auditoría de puntos de entrada del encargo 2026-10-10-share-image-reading-does-not-always-start
---

# El delegado de notificaciones se asigna después de que la app termine de lanzarse

## Qué pasa (inferido del código, sin reproducir)

El delegado de `UNUserNotificationCenter` lo pone `NotificationService.init`, y el primer acceso a
`NotificationService.shared` es el paso 1 de `AppBootstrapper.bootstrap`, que corre en el `.task` de `ContentView`:
después de `application(_:didFinishLaunchingWithOptions:)`. Apple pide asignar el delegado antes de que el lanzamiento
termine. Con la app cerrada, tocar una notificación puede abrir Yala sin llevar a ningún sitio.

## Qué haría falta

Medirlo en un iPhone (la app cerrada del todo, tocar una notificación de pago planificado y ver si aterriza en Pagos
planificados). Si se pierde, tocar `NotificationService.shared` en `YalaAppDelegate.didFinishLaunching` y comprobar que
su `init` no depende de nada del arranque. El intent que produce (`.navigate`) ya se aplaza y se conserva si llega pronto.

Ver `docs/entry-points.md`.
