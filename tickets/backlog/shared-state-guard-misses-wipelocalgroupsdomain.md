---
id: shared-state-guard-misses-wipelocalgroupsdomain
status: backlog
priority: low
area: "testing"
created: 2026-09-11
updated: 2026-10-08
source: "review adversarial de `detach-history-replay-can-tombstone-groups-on-next-launch` (lente de contrato)"
---

# El guard que obliga al trait de aislamiento busca `wipeAllUserData(` y se le escapa `wipeLocalGroupsDomain(`

## Lo medido (2026-09-11)

`SharedStateIsolationTests.todaSuiteQueEjecutaElWipeLlevaSuTrait` exige el trait
`.wipeAppGroupMirrorIsolated` a toda suite cuyo fuente contenga `wipeAllUserData(`. Pero
`DataWipeService.wipeLocalGroupsDomain` **también** toca estado compartido: su parámetro `resetSyncState`
tiene por defecto `GroupsOutboxMirror()?.purgeAll()`, que purga el espejo REAL del App Group.

⇒ una suite que llame a `wipeLocalGroupsDomain` **sin** inyectar `resetSyncState` pasa el guard y borra el
espejo de las demás. El fallo que produciría es de los que no se parecen a su causa: otra suite se queda sin
sus filas de outbox y falla por «no encontró lo que sembró», en una corrida completa y no en solitario — la
misma firma que el repo ya documenta en `testing.md` («verde a solas, cero acompañado»).

Hoy no hay ninguna suite en esa situación (las que la llaman inyectan el seam), así que es un guard con un
hueco, no un rojo.

## Lo que se espera

Que el escáner cuente también `wipeLocalGroupsDomain(` — y que se mire si hay un tercer escritor del espejo
con el mismo perfil antes de cerrar. La aserción del guard tiene que seguir muriendo con su mutante: quitar
el trait de una suite listada debe dar rojo.

## Medido en 2.1 (triage 2026-10-08)

- El escáner de `SharedStateIsolationTests.swift:313-314` cuenta `wipeAllUserData(`, `wipePersonalDataKeepingGroups(` y
  `wipeLocallyForRemoteWipeSignal(` (las dos últimas son posteriores al ticket). Sigue sin contar `wipeLocalGroupsDomain(`.
- `DataWipeService.wipeLocalGroupsDomain` (`DataWipeService.swift:642`): `resetSyncState` sigue purgando el espejo real por
  defecto (`GroupsOutboxMirror()?.purgeAll()`).
- 14 suites lo llaman. Revisé las que tienen menos `resetSyncState` que llamadas (`CloudSessionRetirementTests`, `WelcomeKeptGroups`,
  `WelcomePrivateICloudGate`, `FreshStartGroupsLossExit`), y o lo inyectan o llevan el trait: hoy no hay ninguna suite en rojo.

Triage 2026-10-08: abierto · medium → low · El escáner sigue buscando solo wipeAllUserData(, wipePersonalDataKeepingGroups( y wipeLocallyForRemoteWipeSignal(; wipeLocalGroupsDomain sigue purgando el espejo real por defecto, aunque hoy las 14 suites que lo llaman inyectan el seam.
