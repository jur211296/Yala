---
id: 2026-11-22-pruebas-interfaz-tandas-5-6-rojo
status: done
priority: medium
area: "qa, uitests, ci"
created: 2026-11-22
updated: 2026-11-22
source: "decisión de Jürgen del 22-nov (10:01 Lima): revisar la causa de las tandas 5 y 6 de UI en rojo"
---

# Tandas 5 y 6 de pruebas de interfaz en rojo en la CI de 2.3

Run del 22-nov sobre `b27dcc08` (https://github.com/jur211296/Yala/actions/runs/44991989046). La UI es informativa en la
CI, así que el run salió verde igual.

## Qué fallaba y por qué

| Prueba | Tanda | En el CI | En local (27.2) | Causa |
|---|---|---|---|---|
| `PersonalToGroupConversionUITests` (2 casos) | 5 | 3/3 rojo («El detalle no ofrece Editar») | verde | El toque a la fila llegaba con la lista aún deslizándose tras el `swipeUp`: frenaba la inercia y no abría el detalle |
| `PanelSectionsConfigResetUITests` | 5 | 3/3 rojo (arrastre sin efecto ×2, «Restablecer» ×1) | verde | Arrastre rápido soltado en el acto con la hoja recién abierta; plazo de 5 s en el que el runner hace una sola lectura |
| `FlujoCrearPlanUITests.test_armado…` | 5 | 1/2 (pasó al reintento) | verde | Toque y recuento con la página en movimiento; plazo de 5 s |
| `FirstExpensePracticeAlertUITests` | 6 | superó los 10 min | verde (40 s) | Del runner: XCUITest esperó 60 s por gesto a que acabaran las animaciones (9 veces). Les pasó igual a dos casos de `ExternalEntryForeignSheetUITests` en la misma tanda, que pasaron en 7 min |

No es una regresión: en la nocturna del 21-nov las dos primeras ya fallaban y pasaban al reintento. Ninguna destapa un
bug de la app.

## Arreglo

Solo en las pruebas: tocar con el elemento quieto (`waitForSettledLayout`) y reintentar el toque una vez; arrastre lento
con pausa antes de soltar y un reintento; plazos de espera de 5 → 15 s. La tanda 6 no se toca: su causa es el runner.

## Lo que queda

- La tanda 6 depende de que el runner no se quede sin «animaciones terminadas». Propuesta de encargo: medir en el runner
  qué vista anima sin parar en Nuevo registro (vídeo del `.xcresult` de una nocturna) o lanzar la app de pruebas sin
  animaciones de UIKit.
- La verificación en CI es la nocturna siguiente sobre 2.3: el CI de un PR no corre la UI.
