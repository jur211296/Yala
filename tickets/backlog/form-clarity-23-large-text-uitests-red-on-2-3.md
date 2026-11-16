---
id: form-clarity-23-large-text-uitests-red-on-2-3
status: backlog
priority: medium
area: tests, nuevo registro
created: 2026-11-11
updated: 2026-11-11
source: gate de la sesión «Lote 2.3 · barra sobre el teclado»; medido contra el código de origin/2.3 sin el cambio de la sesión
---

# Dos XCUITest de texto grande de `FormClarity23UITests` están en rojo en 2.3

Medido el 2026-11-11 en el simulador iPhone 17 Pro (iOS 27.2), con la app compilada desde `origin/2.3` (sin los
cambios de la barra sobre el teclado) y otra vez con ellos: los dos casos fallan igual en las dos.

- `test_m1_largeText_theNoticeIsShown`: con el texto al máximo el campo del importe queda por debajo del borde
  (`{{104.7, 822.3}, {241.3, 131.0}}` en una pantalla de 874 pt). `typeAmount` lo toca sin desplazar y el toque no le da
  el foco: «Neither element nor any descendant has keyboard focus».
- `test_v3_largeText_manualEntryIsReachable`: falla en el Panel, antes del formulario. El «+» flotante
  (`fab_new_transaction`) está en x = 423,7, fuera de los 402 pt de ancho, y XCUITest no puede desplazarlo a la vista.

No los cubre el CI: el job `tests` corre solo `YalaTests`, y la nocturna de QA corre sobre la rama 2.2, que no tiene
este fichero. Por eso nadie los vio caer.

## Qué haría falta

1. El primero es del test: desplazar hasta el importe antes de tocarlo (molde: `KeyboardSaveBar23UITests.typeAmount`).
2. El segundo puede ser de producto: con texto grande, ¿el «+» del Panel se sale de la pantalla también para una
   persona? Mirarlo en el simulador a AX5 antes de tocar el test; si se sale, es un bug de layout del Panel.
