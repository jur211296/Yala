---
id: app-closed-by-ios-for-memory-yala-ios-b
status: qa
priority: high
area: stability
created: 2026-11-12
updated: 2026-11-12
source: card tablero-yala-se-cierra-por-exceso-de-memoria-wat-iq0m · Sentry YALA-IOS-B
---

# Yala se cierra por exceso de memoria (Sentry YALA-IOS-B)

## Qué se midió (2026-11-12)

- **De los 17 eventos, 16 son de Yala Dev 2.2 (7) en el iPhone 14 de QA**, del 5 al 10-nov: cierres de las
  herramientas (`devicectl --terminate-existing`), que Sentry da por memoria agotada. El PR 875 ya apagó ese aviso fuera
  de producción.
- **El único de producción (2.2 (9), iPhone17,2, iOS 27.2.1) es, con alta probabilidad, el iPhone de revisión de
  Apple**: empezó a las 01:23:17 UTC del 11-nov, 5 min después de enviar la 2.2 a revisión (01:17:53 UTC); kernel
  `DEVELOPMENT_ARM64` (los de la calle son `RELEASE_ARM64`), `en_US`, recién instalado, 2 min 20 s de sesión, y la app
  volvió a abrirse 2 s después del último rastro. Ninguno de los 17 trae un aviso de memoria baja.
- La 2.2 (9) lleva 17 sesiones de 8 usuarios en producción: ese es su único cierre.
- En el simulador (iPhone 16 Pro Max, iOS 27.2): instalación nueva en inglés, 2,5 min en la bienvenida, plana en
  ~38 MB; con el perfil `pesado`, diez vueltas por las pestañas, sube a ~190 MB en la primera pasada y se queda ahí.
- **Lo único que creció de verdad:** fotos elegidas para leer, pintadas a tamaño completo. Diez de 48 MP subían la app
  de 65 MB a 1.929 MB; reducidas al entrar, a 67 MB.

## Qué se cambió

- Las fotos que se leen (Fotos, compartir/soltar, Archivo, cámara, «Desde un recibo» de Grupos) y la foto de perfil
  recién elegida entran reducidas (`PhotoIntake`).
- Sentry trae contexto en el próximo cierre: contexto `memory` (memoria propia, la que queda, pico, pestaña), rastro
  por escalón de memoria, evento «Aviso de memoria baja» (como mucho uno cada 10 min), pestaña como rastro y etiqueta,
  y el estado de los rastros de ciclo de vida, que antes la limpieza borraba.

## Para cerrar

1. Que salga una build de producción con este cambio (2.3).
2. Mirar YALA-IOS-B y «Aviso de memoria baja» en Sentry tras unos días de uso: si vuelve un cierre, ahora trae
   memoria, pestaña y escalones.
3. Resolver YALA-IOS-B en Sentry «en la release» que trae el cambio, no antes.

Opcional en el iPhone 14 (no bloquea): en «Leer foto», elegir diez fotos de la cámara y leerlas; la app no se cierra.
