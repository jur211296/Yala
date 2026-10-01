---
id: scheduled-payment-skip-uitests-fail-at-the-end-of-the-month
status: backlog
priority: medium
area: "testing, planificación"
created: 2026-09-29
updated: 2026-09-30
source: "gate de sheet-size-follows-the-device-not-the-window, 2026-09-29"
---

# Los XCUITest de saltar un pago programado fallan a fin de mes

## Qué pasa

Los dos casos de `ScheduledPaymentSkipUITests` caen en la línea 30: «No se montó la lista de pagos programados». El
test abre Planificación → Pagos planificados y toca la primera fila del período por defecto, «Este mes».

**La app está bien, el test depende de la fecha.** Reproducido a mano el 29-sep con `-uitest-seed minimal`: «Este mes»
dice «Aún no tienes pagos planificados», y «Próximo mes» enseña los pagos (Gimnasio en 4 días, Alquiler en 6,
Teléfono en 16, Spotify en 19, Netflix en 21). La semilla los pone a días vista, así que cerca de fin de mes ninguno
cae en el mes en curso.

## Lo medido (2026-09-29)

- `YalaLane-Adapt-iPhone-ProMax`, iOS 27.0, por UDID y en cola, centinela limpio.
- **`2.1` en `435bd8eb`, sin cambios: 2 de 2 en rojo.** El árbol de `sheet-size-follows-the-device-not-the-window`: 2 de
  2 en rojo, mismo mensaje.
- No se midió desde qué día del mes falla.
- **Re-medido el 2026-09-30** en el gate de `ipad-keyboard-shortcuts-pointer-context-menus-and-drop`: 2 de 2 en rojo en
  `2.1` (`6e3fdacc2`, worktree limpio) y en la rama, mismo mensaje. Los otros 182 casos de la suite, en verde.

## Qué hacer

Que el test no dependa del día: sembrar un pago que caiga dentro del mes en curso, o que el test pase a «Próximo mes»
si el actual está vacío. Revisar si otros XCUITest de Planificación leen «Este mes» con la misma semilla.
