---
id: whats-new-yields-to-a-pending-trial-offer-after-updating
status: qa
priority: medium
area: "onboarding, release"
created: 2026-10-19
updated: 2026-10-19
source: "tablero-al-actualizar-desde-la-2-0-4-mira-lo-nue-n2xn (QA guiado 2026-10-19)"
---

# Al actualizar desde la 2.0.4, «Mira lo nuevo» cede el turno a una oferta de prueba pendiente

## En lenguaje de usuario

Actualizo desde la 2.0.4. En el primer arranque no sale «Mira lo nuevo en Yala» (sale la oferta de prueba de Pro); sale en el segundo. En otro aparato sí salió a la primera.

## Lo medido (2026-10-19)

- La hipótesis de la card (la marca de sesión privada leída en el splash) es falsa: con la marca ausente, `PrivateSessionMark.hasPrivateSession()` vale `true`.
- `runReturningUserPostChecks` decidía `if oferta pendiente … else if novedades`: con la oferta pendiente, Novedades no se encolaba.
- La 2.0.4 deja la oferta pendiente **sin consumirla** cuando el alta fue «Restaurar» con destino directo a la app: `completeOnboardingAsRestoreSkip` pone `needsPostOnboardingTrial = true` y no pasa por el `onChange(showOnboarding)` que la consumía (`git show v2.0.4:Yala/App/ContentView.swift`, l.292-296 y 951-957). El iPhone del QA venía de un onboarding privado con datos de iCloud.
- **Reproducido en simulador** (iPhone 17 Pro, iOS 27.0): build de `v2.0.4` (Yala Dev) con el onboarding hecho, la oferta pendiente (lo que deja «Restaurar»), y la 2.1 encima. Primer arranque: la oferta de prueba, sin Novedades. Segundo arranque: Novedades. Control sin oferta pendiente: Novedades a la primera (el iPad). Capturas en `capturas/`.

## Lo que cambia

Novedades va antes que la oferta pendiente (`WhatsNewLaunchLogic.returningUserSheet`). Sigue saliendo una hoja por arranque: la oferta sale en el siguiente, porque su marca solo se borra al presentarse. Novedades no vuelve: su versión se da por vista al cerrar la hoja. Verificado en el simulador con el mismo escenario.

## Tests

`WhatsNewLaunchLogicTests` (tabla con controles: solo oferta, solo Novedades, Pro, solo Grupos; y el cableado de `runReturningUserPostChecks`). XCUITest `WhatsNewLaunchUITests.test_updateFrom2_0_withATrialOfferPending_showsTheSheetOnTheFirstLaunch` con el seam nuevo `-uitest-pending-trial-offer`.

## De paso: `-uitest-reset` no bajaba la oferta de la memoria

`SessionState` lee `needsPostOnboardingTrial` al construirse, antes de que `-uitest-reset` borre la clave: una oferta que un
test anterior dejó sin presentar tapaba el siguiente test entero. Medido en el gate de este ticket (once XCUITest con la oferta
encima del avatar de Perfil, en orden y no aislados). Ahora el reset la baja también en memoria, salvo con el seam.

## Device-QA (Jürgen, iPhone de QA)

1. Instala la 2.0.4 de la App Store y haz el alta por «Restaurar» desde tu iCloud (la del 19-oct).
2. Sin volver a abrirla, instala el TestFlight 19 encima y ábrelo.
3. Esperado: «Mira lo nuevo en Yala» en el primer arranque. Ciérrala con Continuar, cierra Yala del todo y ábrela: sale la oferta de prueba (si no eres Pro) y Novedades no vuelve.
