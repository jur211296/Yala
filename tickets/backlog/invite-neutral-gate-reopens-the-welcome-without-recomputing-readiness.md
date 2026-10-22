---
id: invite-neutral-gate-reopens-the-welcome-without-recomputing-readiness
status: backlog
priority: low
area: "groups, routing"
created: 2026-10-01
updated: 2026-10-08
source: "review adversarial de `superseding-intent-can-strand-the-sign-out-coordinator`, lente de router"
---

# La puerta del invitado reabre el Welcome sin que la matriz de readiness lo vea

## Lo visto (inferido, sin medir)

`.presentGroupsInviteNeutralGate` supersede la cadena del Welcome. Si el Welcome estaba arriba, `drainContentViewIntents`
lo derriba (`showWelcomeFlow = false`), recomputa (`markReady(.contentView)`) y, en la misma vuelta, el handler del
intent lo reabre (`showWelcomeFlow = true`). El valor acaba igual que empezó, así que el `onChange(showWelcomeFlow)` de
`readinessGateObservers` no se dispara: `.contentView` queda `ready` con el Welcome encima, y el siguiente intent en
cola puede presentarse sobre él (regla 3 de Presentaciones).

El re-peek de `signOutPhaseChanged` (2026-10-01) hace este camino algo más frecuente: también derriba la cadena al salir
de un bloqueo del cierre de sesión.

## Qué falta medir

Si de verdad no se recomputa: un XCUITest con un intent encolado detrás de `.presentGroupsInviteNeutralGate`.

## Por dónde va

Llamar a `updateContentViewReadiness()` tras el handler de `.presentGroupsInviteNeutralGate`, o no derribar la cadena
para un intent que la va a reabrir.

## Medido en 2.1 (triage 2026-10-08)

- El handler de `.presentGroupsInviteNeutralGate` (`ContentView`, dentro del `switch` de intents) sigue igual: escribe `welcomeFlowInitialStep` y `showWelcomeFlow = true`, sin llamar a `updateContentViewReadiness()`. Ningún commit posterior al 2026-10-01 tocó ese intent salvo el de varias ventanas de iPad (`133437905`).

Triage 2026-10-08: abierto · low → low · El handler de `.presentGroupsInviteNeutralGate` en `ContentView` sigue reabriendo el Welcome (`showWelcomeFlow = true`) sin recomputar la readiness; sigue inferido, sin XCUITest que lo mida.
