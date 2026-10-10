---
id: share-image-reading-does-not-always-start
status: qa
priority: high
area: image
created: 2026-10-10
updated: 2026-10-10
source: reporte de Jürgen 2026-10-10 10:48 (card tablero-al-compartir-una-imagen-a-yala-la-lectur-nxle)
---

# Al compartir una imagen a Yala, la lectura no siempre arranca hasta reiniciar la app

## Reporte

Al mandar una foto con la hoja de compartir, a veces no arranca la lectura y hay que cerrar Yala del todo y reabrirla.

## Qué se midió (simulador, iPhone 17 Pro, iOS 27.0, `SharedImageEntryUITests`)

En 2.1, con la foto en `PendingImages/` y `yala://shared-image` abierto por el sistema:

| Caso | 2.1 | Con el arreglo |
|---|---|---|
| App cerrada (la URL llega antes de que termine el arranque) | **Rojo**: el enlace decidía con estado sin cargar; en el test, pidió el consentimiento de IA que ya estaba dado. En un iPhone con Pro por App Store, la puerta Pro lee `isProUser = false` y borraría la foto (inferido) | Verde |
| App delante | Verde | Verde |
| App en segundo plano, una y dos veces | Verde | Verde |
| Bandeja abierta: espera y arranca al cerrarla | Verde | Verde |
| Aviso de arranque delante: espera y arranca al contestarlo | Verde | Verde |
| Detalle de un registro abierto en otra pestaña | Verde (ir al Panel lo cierra) | Verde |
| Hoja del Panel que ningún flag publica (el «?» de un widget): espera y arranca al cerrarla | Verde | Verde |

## Qué cambió

- Los enlaces que deciden con estado del arranque (`shared-image`, `image-entry`, `voice-entry`, `new-transaction`,
  `activate-full`) esperan a que el arranque termine (`EntryReadinessLogic`); la acción del Centro de Control, igual.
- `.presentSharedImage` se aplaza guardando la ruta de la foto, en vez de perderse.
- Lo aplazado sale también al completar el onboarding.
- `docs/entry-points.md`: todas las entradas, cómo llegan, si se aplazan y en qué orden se presentan.

## Device-QA para Jürgen (iPhone, build de TestFlight con este cambio)

Montaje: una foto de un recibo en Fotos. Yala con sesión iniciada, Pro y el consentimiento de IA aceptado.

1. **En frío.** Cierra Yala del todo (deslizar hacia arriba en el selector de apps). En Fotos, abre el recibo →
   Compartir → Yala. Espera: Yala se abre y en unos segundos sale «Leyendo tu foto…» y luego «Esto leí».
2. **En segundo plano.** Con Yala abierta en el Panel, ve al inicio. En Fotos → Compartir → Yala. Espera: lo mismo que
   el paso 1, sin ver el arranque.
3. **Con la Bandeja abierta.** Abre la Bandeja (icono arriba a la izquierda del Panel). Ve al inicio y comparte la foto
   como en el paso 2. Espera: Yala vuelve con la Bandeja abierta. Ciérrala con la X: la lectura arranca sola.
4. Repite el paso 2 tres veces seguidas, guardando o cerrando lo leído entre una y otra. Las tres tienen que leerse.

Si alguno no arranca: anota el paso y la hora, y en Console.app filtra `subsystem: com.yala` con `category: SharedImage`
(`SHARED-IMAGE CHECK`, `ENTRY AWAITS BOOTSTRAP`).

## Lo que se probó y no entró

Una comprobación extra en el Panel (preguntar a UIKit si la ventana tiene algo presentado antes de abrir la lectura).
Con ella apagada, el caso del «?» de un widget seguía pasando: el mutante sobrevivió, así que no aportaba y se retiró.

## Queda para decidir

`shared-photo-waits-silently-behind-an-open-panel-sheet`: en el paso 3 la lectura espera sin decir nada. Si eso explica
el reporte, la opción B de ese ticket lo resuelve.
