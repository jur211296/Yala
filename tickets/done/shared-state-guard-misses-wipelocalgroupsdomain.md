---
id: shared-state-guard-misses-wipelocalgroupsdomain
status: done
priority: low
area: "testing"
created: 2026-09-11
updated: 2026-11-04
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

## Cerrado (2026-11-04)

`SharedStateIsolationTests.cadaLlamadaAlBorradoDeGruposInyectaSuReset` cuenta cada llamada
`try DataWipeService.wipeLocalGroupsDomain(` en código (no en literales ni comentarios; 23 hoy) y exige que inyecte
`resetSyncState:`. No pide el trait: `.wipeAppGroupMirrorIsolated` restaura claves del App Group, no el directorio del
espejo. Tercer escritor con el mismo perfil: `GroupsSyncClient.purgeOutboxForSessionChange` purga el espejo del cliente,
que en los tests ya es `nil` por defecto (ticket del espejo, mismo PR). Mutante: quitar `resetSyncState:` de una llamada
pone el test en rojo.

Medición (iPhone 17 Pro de la Max, iOS 27.2, scheme `Yala`, corrida completa de YalaTests con el simulador en turno):
la base (`origin/2.3` sin tocar, instalación limpia) dejó **1.262** ficheros de preferencias, **74** directorios en
`tmp/`, el `.plist` del App Group con `isProUser`, `lastUsedAccountID` y `siri_finance_snapshot`, y **2.910** avisos
«vnode unlinked while in use»; con el arreglo (12.783 tests en verde): **0** preferencias nuevas, App Group sin claves
antes y después (leído vía `cfprefsd`: el fichero en disco va desfasado), onboarding sin marcar y **3** avisos, los del
control negativo del eje 4b del spike R3, que los provoca a propósito.
