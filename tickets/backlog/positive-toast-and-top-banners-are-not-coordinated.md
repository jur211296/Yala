---
id: positive-toast-and-top-banners-are-not-coordinated
status: backlog
priority: low
area: notifications
created: 2026-10-30
updated: 2026-10-30
source: inventario del ticket notices-come-out-one-after-another-by-priority (sesión S27f, leído en el código, sin medir en simulador)
---
# El toast verde y los avisos de arriba no se coordinan, y el toast caduca debajo de una hoja

Qué ve la persona: «Datos vaciados desde otro dispositivo» o «De vuelta a Yala completo» pueden no verse nunca si hay una hoja abierta (el toast vive en la capa raíz de `ContentView` y se va a los 3-6 s), y el toast, la pastilla de sincronización y «Descargando tus datos…» van los tres arriba sin orden entre ellos.

Leído: `showPositiveToast` (`ContentView`), `PositiveToastLayout.topInset`, `SyncStatusBannerHost` con `padding(.top, 48)`, `CloudHydrationBanner` en el overlay de la `TabView`.

Hecho cuando: el toast espera a que la ventana esté libre (o se enseña en su propia `UIWindow`) y los tres avisos de arriba tienen un orden.
