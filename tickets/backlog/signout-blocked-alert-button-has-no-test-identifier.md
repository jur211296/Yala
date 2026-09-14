---
id: signout-blocked-alert-button-has-no-test-identifier
status: backlog
priority: low
area: "sesión, qa"
created: 2026-09-14
source: "review adversarial de `cloud-signout-collapses-every-groups-transient-into-permanent`, lente de UI"
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
