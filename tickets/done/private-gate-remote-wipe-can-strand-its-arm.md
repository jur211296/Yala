---
id: private-gate-remote-wipe-can-strand-its-arm
status: done
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-13
updated: 2026-09-28
source: "review adversarial de `groups-only-private-restart-skips-the-wipe-alert`, lente de camino (F2)"
qa-status: not-replicable
qa-date: 2026-09-28
qa-notes: barrido 2026-09-28 sin device-QA - pide abrir una invitacion mientras borra; carrera cubierta por PrivateGateCancelledWipeTests
---

# El borrado de iCloud de la puerta privada puede quedarse consumado con su arm puesto y la persona mirando un spinner

## El síntoma

Elijo «Es mi primera vez → privado», la puerta encuentra datos en mi iCloud, confirmo dos veces, y la
pantalla se queda en «Borrando lo que había en iCloud…» para siempre. Los datos sí se borraron.

## Lo medido (2026-09-13)

`WelcomePrivateICloudGateView.wipe()` —el camino de iCloud, **no** el del teléfono— lleva un
`guard !Task.isCancelled else { return }` **después** de `await performWipe()`. Ese borrado, cuando
además se lleva las filas locales (el scope `.handover`, que es el caso del Welcome (hasta el 2026-09-14, `includingLocalRows: true`)), llama a
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

## Hecho (2026-09-27)

**Qué cambia para quien usa la app.** Si la pantalla de «Es mi primera vez → privado» se cierra por debajo mientras
borra tus datos de iCloud, el borrado ya no se queda a medias por dentro. Si ya se hizo, termina: limpia lo que quedaba
de quien usó el teléfono antes y no deja pendiente un borrado que la app repetiría a ciegas. Si no llegó a tocar nada,
se cancela limpio. Y la app ya no te saca de la pantalla que la sustituyó, por ejemplo una invitación de grupo.

- **La cancelación solo manda si el borrado no llegó a escribir.** `WelcomePrivateICloudGateLogic.gateWipeSettles`:
  sin cancelación, el veredicto de siempre; éxito, termina (todo `nil` cruzó la zona, fijado con un test); fallo con la
  zona ya ida (`isICloudCorpusWipeZoneDone`), fase de fallo; fallo sin tocar nada, vuelve **desarmado**.
- **Termina lo durable, no la navegación** (medio de la review). Cancelada, la puerta ya no está montada: una
  invitación que sustituye el paso del Welcome la desmonta, y un `onProceed()` ahí relanzaba o bajaba el cover encima
  de ella. La cancelación se lee una vez y decide las dos cosas.
- **La cancelación limpia desarma** (bajo de la review, llevado al arreglo). Un arm sin nada que proteger lo reanudaba
  a ciegas `runLateICloudMirrorCheck` (`.handover`, purga de Grupos incluida) si la persona terminaba el onboarding por
  otro camino. El arm existe para un kill, no para un abandono.

**Premisa corregida.** El ticket decía «spinner eterno». Medido: la `.task(id: phase)` solo se cancela al desmontarse la
puerta (en `.wiping` no hay «volver» y solo `wipe()` cambia la fase), así que no quedaba una pantalla colgada; quedaban
el arm y las preferencias residuales sin aplicar.

**Verificado.** `PrivateGateCancelledWipeTests` (tabla entera) + `wipe_cancellationOnlyWinsBeforeAnythingWasWritten` y
`corpusWipe_returnsNilOnlyAfterTheZone` (source-scan). 26/26 mutantes muertos en tres tandas. Review adversarial de
tres lentes: un medio (la navegación, arreglado), bajos llevados al arreglo o a ticket.

**Fuera, con ticket.** `private-gate-device-wipe-navigates-after-its-gate-unmounted` (el gemelo `wipeDevice` navega
igual), `late-icloud-notice-wipe-cancelled-after-it-committed-skips-its-exit` (el mismo `guard` en el aviso tardío) y una
nota en `private-gate-wipe-failure-copy-claims-icloud-is-intact` (salir de `.wipeFailed` olvida que la zona ya se fue).

**Por qué `qa`.** CloudKit no existe en el simulador y la cancelación a mitad no se provoca en un XCUITest.

### Guion de device-QA (opcional, iPhone con una cuenta de iCloud con datos de Yala)

1. Borra Yala e instálala desde TestFlight. En el Welcome toca «Empezar» → «Es mi primera vez» → «Privado».
2. La puerta encuentra datos en iCloud: confirma «Borrar» dos veces.
3. Mientras sale «Borrando lo que había en iCloud…», abre un enlace de invitación de grupo desde Mensajes o Notas.
4. **Esperado:** la invitación se queda en pantalla; la app no relanza ni salta al onboarding por su cuenta.
5. Termina o cancela la invitación, cierra Yala del todo y ábrela. **Esperado:** no vuelve a borrar nada sola; si
   vuelves a «Privado», la puerta mide otra vez y ve iCloud vacío.

## Barrido de `qa` · 2026-09-28 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido semanal (encargo `2026-09-28-barrido-qa-in-qa-semanal`), con el criterio del 2026-09-23 (#224). Pide abrir una invitación de grupo justo mientras se borra iCloud: una carrera difícil de acertar a mano. Lo cubre `PrivateGateCancelledWipeTests` (26/26 mutantes).
