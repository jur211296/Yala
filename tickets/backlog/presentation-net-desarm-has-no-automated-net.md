---
id: presentation-net-desarm-has-no-automated-net
status: backlog
priority: medium
area: "testing, sesiones, routing"
created: 2026-09-14
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

## Criterios de aceptación

- [ ] Un XCUITest ejercita el camino `.retry` → `.exhausted` y afirma las dos consecuencias: la
      condición viva se suelta y el intent retenido detrás presenta.
- [ ] El test de la presentación NORMAL sigue corriendo **sin** ese seam (regla `L103` de
      `testing.md`: el seam que fuerza un predicado no puede ser el único camino).
- [ ] El escáner del tramo del drenaje sigue fijando el orden, con el seam dentro.
