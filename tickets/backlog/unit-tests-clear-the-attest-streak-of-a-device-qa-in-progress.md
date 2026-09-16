---
id: unit-tests-clear-the-attest-streak-of-a-device-qa-in-progress
status: backlog
priority: low
area: "testing, attest, qa"
created: 2026-09-15
updated: 2026-09-15
source: "hallazgo de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` (2026-09-15)"
---

# Una corrida de unit tests en el simulador puede borrar la racha de App Attest que un device-QA lleva un día construyendo

## El problema

El device-QA de `groups-phone-that-never-attests-is-told-to-retry-forever` deja la app del scheme `Yala` más de dos horas en
el simulador y la relanza 24 h después. La racha vive en `UserDefaults.standard` (`groupsSync.attestRejectionStreak`). Los
unit tests corren con el scheme `Yala` en ese mismo simulador, y su host es esa misma app (`TEST_HOST = …/Yala.app`).

## Lo medido (leído en el código, sin ejecutar)

- Un 200 de Grupos llama a `GroupsAttestStreakStore.recordAcceptance()`, que BORRA la racha. Solo aíslan la tienda las cuatro
  suites que usan `IsolatedAttestStreak`, las del 401. Las que responden 200 —p. ej. `GroupsSyncClientPushTests` y
  `GroupsSyncApplyZoneTests`— escriben en la tienda del host.
- Desde el 2026-09-15 también la borra `CloudSyncRuntime.resolveAttest` con un token conseguido. Pasan por ahí los casos de
  `CloudSyncRuntimeTests` que no fijan `attestError` y `GroupsSyncHardeningTests.runtimeCycle_invokesGroupsRunner_flagOnOnly`,
  que corre dos ciclos del runtime.
- Consecuencia: un `/gate` de cualquier worktree entre los dos lanzamientos del device-QA deja la racha a cero, y la línea
  `GroupsSync attestTerminal` no sale al día siguiente. Se leería como un FAIL del producto.
- Sin medir: si instalar el host de test conserva el contenedor de datos de la app instalada a mano. Es lo esperable en una
  actualización, y es lo que haría real el borrado.

## Lo que hay que decidir

1. Aislar la tienda en toda suite que ejerza un 200 de Grupos o un ciclo del runtime: un trait de Swift Testing, o el helper
   en cada caso.
2. Que el guion del device-QA avise de no correr unit tests en ese simulador durante las 24 h.
3. Las dos.

## Relación con otros tickets

- `groups-phone-that-never-attests-is-told-to-retry-forever` — el device-QA que lo sufre.
- `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` — donde apareció.
