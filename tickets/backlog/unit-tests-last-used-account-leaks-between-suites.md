---
id: unit-tests-last-used-account-leaks-between-suites
status: backlog
priority: medium
area: "testing"
created: 2026-11-17
updated: 2026-11-17
source: "sesión «Dejar 2.3 perfecta» (17-nov): suite unitaria completa sobre la integración de la captura de Grupos"
---

# Dos pruebas unitarias leen una «última cuenta» que dejó otra prueba

## Medido (2026-11-17, iPhone 17 Pro, iOS 27.2, `YalaTests` entero)

En la primera corrida cayeron dos casos, y en la segunda, sobre el mismo árbol, los 14.589 pasaron:

- `SharedStateIsolationTests.scopeLastUsedAccount_entraSinUltimaCuenta` (línea 174): `vistoDentro == nil` falló — dentro
  del ámbito aislado se leyó una última cuenta.
- `ActivationRestoreDiscardTests` «el borrado sin reset conserva la identidad y REABRE las puertas del seed» (línea 267):
  `lastUsedAccountID` del App Group no era `nil` tras el borrado.

Los dos miran `AppPreferences.Keys.lastUsedAccountID` en el App Group real. La rama integrada (captura de Grupos) no toca
esa clave. Inferido, sin medir: alguna prueba deja una tarea suelta que escribe la última cuenta después de que el
ámbito aislado la limpió.

## Por qué importa

El job `tests` del CI es bloqueante: un rojo intermitente aquí para un merge sin que nada esté roto.

## Qué mirar

Quién escribe `lastUsedAccountID` fuera de un `withSharedStateIsolated(.lastUsedAccount)`: un `grep` de
`LastUsedAccountStore.write` / `lastUsedAccountID` en los SUT que usan pruebas sin ese trait, y si alguno lo hace desde un
`Task {}` que sobrevive a su prueba.
