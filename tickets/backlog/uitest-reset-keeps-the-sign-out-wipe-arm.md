---
id: uitest-reset-keeps-the-sign-out-wipe-arm
status: backlog
priority: very-low
area: "qa, sesiones"
created: 2026-09-26
updated: 2026-10-08
source: "review adversarial de `sign-out-exits-do-not-verify-the-cloud-session-closed` (2026-09-26)"
---

# Un XCUITest de cierre de sesión que falla deja el borrado armado en el simulador

## El problema, en lenguaje de QA

`SessionExitsPerCellUITests.test_privateCell_C_signOutWithASurvivingSession_stopsAndSaysSo` confirma un cierre de sesión
real. Con el arreglo se para antes del arm; si alguna regresión lo deja llegar al arm, `cloudSync.signOutWipeArmed` queda escrito
en el simulador y **`-uitest-reset` no lo limpia**. Lo leen varios sitios en la misma corrida (`NotificationService`,
`InboundCaptureDrain`, `WidgetDataCache`, el bootstrap…), así que otras suites salen rojas sin relación aparente, y el siguiente
arranque MANUAL del simulador borra el store.

## Lo medido (2026-09-26)

- El ejecutor del borrado no corre bajo `-uitest`; el arm sí se escribe (`armSignOutWipe` no tiene guard de test). Tres
  docblocks de `UITestHooks` lo avisan, y por eso los demás tests de salida no confirman.
- Cazado por la review adversarial de `sign-out-exits-do-not-verify-the-cloud-session-closed`.

## Qué habría que decidir

Si `-uitest-reset` debe retirar también los arms de `cloudSync.*` del cierre de sesión bajo `isUITesting`. Cambia una
propiedad que hoy está documentada como «sobrevive a propósito».

## Medido en 2.1 (triage 2026-10-08)

- `UITestHooks.swift:279` sigue documentando que `-uitest-reset` no limpia las claves `cloudSync.*`, y `armSignOutWipe` no tiene guard de test.

Triage 2026-10-08: abierto · very-low → very-low · solo muerde si una regresión deja llegar al arm en un XCUITest.
