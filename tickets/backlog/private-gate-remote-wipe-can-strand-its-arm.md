---
id: private-gate-remote-wipe-can-strand-its-arm
status: backlog
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-13
source: "review adversarial de `groups-only-private-restart-skips-the-wipe-alert`, lente de camino (F2)"
---

# El borrado de iCloud de la puerta privada puede quedarse consumado con su arm puesto y la persona mirando un spinner

## El síntoma

Elijo «Es mi primera vez → privado», la puerta encuentra datos en mi iCloud, confirmo dos veces, y la
pantalla se queda en «Borrando lo que había en iCloud…» para siempre. Los datos sí se borraron.

## Lo medido (2026-09-13)

`WelcomePrivateICloudGateView.wipe()` —el camino de iCloud, **no** el del teléfono— lleva un
`guard !Task.isCancelled else { return }` **después** de `await performWipe()`. Ese borrado, cuando
además se lleva las filas locales (`includingLocalRows: true`, que es el caso del Welcome), llama a
`DataWipeService.wipeAllUserData`, que borra `hasCompletedOnboarding`. Esa escritura dispara el
`onChange` de `ContentView`, y con él una re-entrega de SwiftUI que puede cancelar la `.task(id: phase)`
**con el borrado ya committeado**.

Cuando eso pasa: el arm (`icloudCorpusWipeArmed`) se queda puesto, `onProceed()` no corre nunca y la fase
se queda en `.wiping`. Se auto-cura en dos arranques —`presentNextOnboardingScreen` reabre la puerta, que
re-mide, ve la zona vacía y sale— pero la sesión en curso es un callejón visual sobre datos que ya no
están.

**Es el gemelo del defecto que el 2026-09-13 se corrigió en `wipeDevice`**, donde el guard se quitó por
exactamente este motivo («un borrado consumado tiene que terminar su trabajo»). La asimetría quedó
porque el camino de iCloud tiene una diferencia real: su borrado **sí** puede tardar y ser cancelado
legítimamente mientras habla con CloudKit, así que quitar el guard a secas movería el problema en vez de
cerrarlo.

**Mitigado en parte, no cerrado:** el guard `!showWelcomeFlow` que se añadió al `onChange` de
`hasCompletedOnboarding` evita que ese camino monte un segundo cover, que era el disparador más probable
de la cancelación. Queda el resto.

## Por dónde va

El corte natural es distinguir «cancelado ANTES de tocar nada» de «cancelado DESPUÉS de borrar»: el
primero vuelve, el segundo termina. `performWipe` ya devuelve un veredicto; lo que falta es que el
llamador sepa si llegó a escribir.

## Cómo se prueba

- Unit: source-scan del orden dentro de `wipe()`, con el mutante que reintroduce el guard.
- Device-QA: el único sitio donde el borrado de la zona tarda de verdad.
