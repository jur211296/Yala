---
id: groups-gate-can-start-the-neutral-return-while-the-welcome-is-dismissing
status: backlog
priority: low
area: "modo-nube, groups"
created: 2026-10-01
updated: 2026-10-08
source: "review adversarial de `superseding-intent-can-strand-the-sign-out-coordinator`, lente de flujo"
---

# La puerta de Grupos puede arrancar la vuelta al neutro mientras el Welcome se está cerrando

## Lo visto (inferido, sin medir)

Con la puerta en `.checking` el coordinador del cierre está en `.idle`, así que un intent que supersede la cadena del
Welcome puede derribarla (`dismissWelcomeChainForSupersedingIntent`). Durante la animación de cierre del cover la vista
sigue montada y su `.task` aún no está cancelado. Si `refreshIfDue(force: true)` contesta en ese hueco, el guard
`!Task.isCancelled` de `evaluate()` pasa, la fase pasa a `.returningToNeutral` y `signOut` pone `.working`. Al terminar
el cierre del cover, la cancelación deja el coordinador en `.blocked(.transient)` sin dueño: el mismo síntoma que el
ticket padre (Ajustes mudo el resto del proceso).

Lo mismo vale para el toque de «Confirmar» del invitado (`beginNeutralReturn`) si cae en el mismo frame que el drain.

## Qué falta medir

Si SwiftUI relanza un `.task(id:)` en una vista que se está desmontando. Si no lo hace, el ticket se descarta.

## Por dónde va

Que la puerta no arranque la vuelta al neutro si su cover ya no está pedido (`showWelcomeFlow == false`), o que el
derribo no ocurra con la puerta en `.checking`.

## Medido en 2.1 (triage 2026-10-08)

- `ContentView.dismissWelcomeChainForSupersedingIntent` sigue poniendo `showWelcomeFlow = false` sin mirar la fase de la puerta, y `WelcomeGroupsGateView.evaluate()` sigue con solo el guard `!Task.isCancelled` antes de pasar a `.returningToNeutral`. Ningún commit desde el 2026-10-01 toca ese derribo.
- Sigue sin medir lo que decide el ticket: si SwiftUI deja correr el `.task` durante la animación de cierre del cover. No se puede medir sin simulador; queda abierto con la misma pregunta.
- El síntoma (Ajustes mudo) dura hasta relanzar: no es un callejón.

Triage 2026-10-08: abierto · low → low · carrera inferida y sin medir en una ventana de animación; el síntoma se cura al relanzar.
