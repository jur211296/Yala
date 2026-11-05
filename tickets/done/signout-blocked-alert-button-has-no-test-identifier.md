---
id: signout-blocked-alert-button-has-no-test-identifier
status: done
priority: very-low
area: "sesión, qa"
created: 2026-09-14
source: "review adversarial de `cloud-signout-collapses-every-groups-transient-into-permanent`, lente de UI"
updated: 2026-11-05
---

# El botón del aviso de cierre bloqueado no se puede pulsar desde un XCUITest

## Lo medido (2026-09-14)

`Yala/App/Views/Profile/ProfileView.swift`, `signOutBlockedButtons`:

```swift
Button(L10n.Common.ok, role: .cancel) { CloudSessionSignOut.shared.acknowledgeBlocked() }
```

Sin `accessibilityIdentifier`, y es el **único** de la cadena de cierre que no lo lleva: sus cuatro
vecinos del mismo fichero sí (`signout_no_copy_confirm`, `signout_no_copy_cancel`,
`signout_export_discard`, `signout_export_wait`). Ese botón es el de **dos** alerts —el del bloqueo y el
de «un momento más»—, o sea los cuatro motivos que hoy muestra el cierre.

`grep -rn "showSignOutBlockedAlert\|signOutPendingTitle" YalaUITests/` da **cero**: hoy no hay ningún
XCUITest sobre estos avisos, así que no rompe nada. Lo que impide es escribirlo — casar por texto
localizado es lo que la casa no hace.

## Por qué es `low`

El área `session-sign-out` está clasificada `agentic` en `qa/coverage-index.json`, así que el contrato no
exige XCUITest aquí. Es deuda de testabilidad, no un defecto que vea nadie.

## Lo que se espera

Un identificador por alert (el `ViewBuilder` es compartido, así que o se parametriza o se duplican los
dos botones), y de paso comprobar si algún recorrido de `/qa` quiere ejercitarlos.

## Medido en 2.1 (triage 2026-10-08)

- `ProfileView.signOutBlockedButtons` sigue siendo `Button(L10n.Common.ok, role: .cancel) { … acknowledgeBlocked() }` sin identificador, y `YalaUITests/` sigue sin tocar `showSignOutBlockedAlert` ni `signOutPendingTitle`.
- Antes de arreglarlo, medir: dos comentarios nuevos del mismo fichero (los avisos de App Attest, 2026-09-15 y 2026-09-28) dicen que «SwiftUI no los propaga a los botones de un `.alert`», y sin embargo `signout_export_discard` se pone dentro de un `.alert`. Una de las dos cosas es falsa.

Triage 2026-10-08: abierto · low → very-low · sigue sin identificador, pero es deuda de testabilidad en un área agentic que nadie ve usando la app.

## Resuelto (2026-11-05, lote T4)

- Un identificador por aviso: `signout_blocked_ok` («No pudimos cerrar tu sesión») y `signout_pending_ok` («un momento más»). `signOutBlockedButtons` pasa a función con el identificador como parámetro.
- **Medido: el identificador SÍ llega al árbol dentro del `.alert`.** `SessionExitsPerCellUITests#test_privateCell_C_signOutWithTheMigrationNotAtRest_stopsBeforeAnythingAndSaysSo` ahora cierra el aviso con `app.alerts.buttons["signout_blocked_ok"]`, y pasa. El comentario de `ProfileView` que decía lo contrario quedó corregido.
- Lo que no se midió: el de `signout_pending_ok` (su aviso solo lo pone el cierre solo-grupos tras 45 s de reintentos, sin seam). Es el mismo `ViewBuilder`.
