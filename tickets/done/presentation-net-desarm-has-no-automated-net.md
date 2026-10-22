---
id: presentation-net-desarm-has-no-automated-net
status: done
priority: medium
area: "testing, sesiones, routing"
created: 2026-09-14
updated: 2026-10-08
source: "review adversarial de `remote-wipe-alert-skips-the-router`, lente de tests"
---

# El desarme que salva la sesión solo está probado a mano

## Qué pasa

`remote-wipe-alert-skips-the-router` cerró un brick: si el aviso de «tus datos fueron eliminados de
iCloud» no llegaba a presentarse, su flag dejaba la matriz de readiness bloqueada y la app no volvía
a enseñar **ningún** aviso hasta que la mataras. La cura es una red que verifica la presentación
contra UIKit (`ModalPresentationProbe`) y, al agotar el cap, **suelta la condición viva**.

Esa cura está **medida**, con control positivo y negativo, pero **a mano**: con dos ediciones
temporales del código de producción y dos lanzamientos en el simulador. Lo que queda en el repo es un
source-scan que fija la FORMA del desarme (`RemoteWipeSignalWiringTests`), no su comportamiento.

## Lo medido (2026-09-14) — la receta, para no re-derivarla

1. En `ShellDataAlertsModifier`, `isPresented: .constant(false)` en el alert del vaciado remoto (la
   presentación nunca monta).
2. Lanzar con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-remote-wipe-notice
   -uitest-trial-offer` y leer el log de readiness.
3. **Con la red**: `blocked by: remoteWipeAlert` → a los ~10 s `blocked by: proTrialOffer`, o sea que
   el intent retenido presentó. **Sin la red** (comentando `armRemoteWipeNoticePresentationNet()`):
   se queda en `remoteWipeAlert` y el paywall no presenta **nunca** (25 s medidos).

## Por qué no se cableó en el PR que lo encontró

Las dos vías obvias tienen su pero, y la decisión fue no meterlas a última hora:

- **Seam en el `isPresented` del alert** (`uiTestX ? .constant(false) : $flag`): mete en producción
  justo el patrón que `.claude/rules/swiftui-ds.md` prohíbe en su regla (1) —un binding de
  presentación con setter no-op—, aunque sea bajo `#if DEBUG`.
- **Seam en la sonda** (`ModalPresentationProbe` ciega): el alert SÍ monta, así que el escenario que
  ejercita no es «no llegó a presentarse» sino «la sonda miente», y su desenlace medido es distinto
  (el alert se queda dibujado, ver la rule). Sirve para otra cosa, no para este criterio.

La tercera vía, que probablemente sea la buena: **un seam en el DRENAJE** que encienda la condición
viva sin encender la red visual — simula exactamente «la presentación no montó» sin tocar el alert.
Cuesta un `#if DEBUG` dentro del tramo que hoy fija un escáner por literal, así que hay que ajustar
ese escáner en el mismo movimiento.

## Una segunda red con el mismo hueco (2026-09-15)

La hoja «Cambiaste de cuenta de iCloud» (`apple-id-close-blocked-has-no-visible-outcome`) estrenó otra red
de la misma familia en `AppleIDCloseNoticeModifier`. Allí la prueba de presentación es el `onAppear` de la
hoja, no la sonda de UIKit. Al agotar el cap suelta la condición viva (`appleIDCloseNotice`), reconoce el
bloqueo del cierre si lo hay y emite `appleIDCloseNoticeNotPresented`. Tampoco tiene XCUITest del desarme:
lo cubren la tabla pura (`AppleIDCloseNoticeLogicTests`) y un escáner que fija la forma del bucle
(`AppleIDCloseNoticeWiringTests`). La tercera vía de arriba vale igual para ella: encender
`appleIDCloseNotice` en el drenaje sin encender `showSheet`.

## Criterios de aceptación

- [x] Un XCUITest ejercita el camino `.retry` → `.exhausted` y afirma las dos consecuencias: la
      condición viva se suelta y el intent retenido detrás presenta.
- [x] El test de la presentación NORMAL sigue corriendo **sin** ese seam (regla `L103` de
      `testing.md`: el seam que fuerza un predicado no puede ser el único camino).
- [x] El escáner del tramo del drenaje sigue fijando el orden, con el seam dentro.

## Cierre (2026-10-08)

**El seam no va solo en el drenaje, va en el único escritor de la red visual de cada aviso.** El `.retry` de la red
vuelve a escribir el flag visual sin condición, así que un seam solo en el drenaje lo dejaría montar en el primer
reintento y la red acabaría en `.satisfied`, nunca en `.exhausted` (inferido del código). Por eso el drenaje y el
reintento pasan por `mountRemoteWipeAlert()` (`ContentView`), y el armado y el reintento de la hoja por
`mountSheet()` (`AppleIDCloseNoticeModifier`), con el `#if DEBUG` dentro. Ni el binding ni la sonda se tocan.

- Seams: `-uitest-remote-wipe-notice-never-mounts` y `-uitest-apple-id-close-never-mounts`, nombrados en
  `launchForUITest`.
- XCUITest: `RemoteWipeNoticeRoutingUITests.test_noticeThatNeverMounts_netExhausts_andReleasesTheRouter` y
  `AppleIDCloseNoticeUITests.test_sheetThatNeverMounts_netExhausts_andReleasesTheRouter`. Afirman que lo retenido
  espera mientras la red reintenta, que presenta al agotarse y que el aviso no se ve nunca.
- Escáneres: el tramo del drenaje fija `… = true mountRemoteWipeAlert() arm…()`, el cuerpo de cada escritor se
  fija entero con su `#if DEBUG`, y el conteo de escritores del aviso pasa de 7 a 6.
- Medido: receta del 14-sep reproducida en las dos redes (sueltan a los ~9,4 s). Cada caso nuevo pasó 7 de 8
  en la sesión, y 3 de 3 seguidos sobre la build final. Con el desarme anulado, los dos caen en la espera de la
  oferta y los escáneres de forma también.
- **Los dos rojos no son del seam**: es el drenaje que no llega tras soltar un bloqueo de la matriz. Sale también
  con la receta original sin seam (1 de 16 en la hoja) y en el aviso de vaciado (1 de 40). Medido, con propuesta
  y con estos casos registrados, en `queued-offer-after-dismiss-flakes-on-a-cold-simulator`.
