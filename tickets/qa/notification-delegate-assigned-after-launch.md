---
id: notification-delegate-assigned-after-launch
status: qa
priority: medium
area: notifications
created: 2026-10-10
updated: 2026-10-11
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

## Hecho (2026-10-11)

El delegado lo asigna ahora `YalaAppDelegate.application(_:didFinishLaunchingWithOptions:)`, con
`NotificationService.installAsCenterDelegate()`, antes de que termine el lanzamiento. Es el único escritor: el `init`
del servicio ya no lo asigna y el paso 1 del arranque se retiró. El cuerpo de `didReceive` vive en
`NotificationService.routeTap`, que manda `.navigate(destino)` por `RouterEntryGate`: antes de que acabe el arranque
se aplaza en `DeferredIntentBuffer` y lo drena el paso 20, igual que antes.

Test: `YalaTests/NotificationColdLaunchTapTests` — centro sin delegado, `didFinishLaunching` real, toque con el
arranque sin terminar ⇒ aplazado ⇒ drenado como `.navigate(.scheduledPayments)`. Rojo sin la llamada en el app delegate.

## Device-QA (iPhone, lo corre Jürgen)

No se puede en simulador: el toque en frío pasa por la pantalla de bloqueo / el Centro de notificaciones.

1. Instala el build en el iPhone. Comprueba en **Ajustes de iOS › Yala › Notificaciones** que están permitidas.
2. En Yala, **Planificación › Presupuestos**: crea un presupuesto pequeño (por ejemplo 10) para una categoría.
3. Registra un gasto de 20 en esa categoría. Llega el aviso de presupuesto superado.
4. **Cierra Yala del todo**: desliza hacia arriba desde el borde inferior y quita Yala del selector de apps.
5. Toca el aviso en la pantalla de bloqueo o en el Centro de notificaciones.
6. **Bien:** Yala se abre y, al terminar de cargar, aterriza en Presupuestos. **Mal:** se queda en el Panel.
7. Repite con Yala en segundo plano (sin cerrarla): tiene que llevar al mismo sitio.
8. Borra el presupuesto y el gasto de prueba.

Nota: el aviso de **Probar** de Ajustes no lleva destino, así que no sirve para esto. Un aviso de cuenta
(`deepLink: "accounts"`) tampoco lleva a ningún sitio, por otro hueco ya abierto
(`notification-deeplink-accounts-not-parsed`).
