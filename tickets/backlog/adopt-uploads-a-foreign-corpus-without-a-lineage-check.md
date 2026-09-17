---
id: adopt-uploads-a-foreign-corpus-without-a-lineage-check
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-16
source: "residual declarado de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (Paso 0 · D9), 2026-09-16"
---

# El adopt sube a la cuenta todo lo que el backend no conoce, sin mirar si esos datos son de esa cuenta

## El problema, en lenguaje de usuario

Tengo mis finanzas en este iPhone, en mi iCloud. Por un camino raro —ver abajo— la app termina «activando la nube» en
este teléfono con una cuenta que ya tenía datos de otra persona o de otro iCloud. Mis movimientos se suben a esa cuenta y
se mezclan con los suyos, y la mezcla llega a todos sus dispositivos. Nadie me pregunta.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- `MigrationWorkExecutor.runAdoptOrphanReconcile` sube como huérfana **toda fila local cuya identidad no está en el
  backend**: las 6 entidades de identidad sintética sin `syncID` reciben uno fresco antes del diff, y las 10 de identidad
  propia (`Budget.id`, `Account.shortcutID`…) no están en el backend de otra cuenta. Lo fija
  `adoptReconcile_nilIdentity_backfilledAndUploaded` (`MigrationWorkExecutorTests`). Su único freno es un backend
  enumerado vacío (`abortedEmptyBackend`).
- Está diseñado para el segundo dispositivo del mismo Apple ID, donde el corpus local ES el del líder y solo las filas
  de la ventana del cutover son huérfanas. **No comprueba que lo sea.**
- `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` cerró los caminos normales: «Migrar a la nube» ya no
  llega al adopt con una cuenta que tiene lo personal (comprobación previa + `ForwardClaimIntent.migrateOnly` en el claim).

## Los caminos que quedan

1. **Un seguidor de un líder con otro corpus, cuando entra por un adopt.** `claiming_in_progress` → `waitingForLeader` →
   `leaderCompleted` → adopt, sin mirar la intención (`follower_ignoresTheIntent`, `MigrationRunnerTests`). Con dos
   dispositivos del mismo Apple ID es el caso diseñado. Con dos corpus distintos mezcla. Desde el 2026-09-16 «Migrar a la
   nube» ya no se hace seguidor (D18 de Jürgen: `claiming_in_progress` vuelve al inicio con aviso); quedan las entradas de
   adopt (Welcome, la tarjeta del marcador).
2. **El relevo de un líder callado.** Si «Migrar» pasa la comprobación con la cuenta aún nueva, otro dispositivo la reclama,
   y el claim de éste se queda aparcado más de 60 min, `claim_account` le da el turno (`created`) y sube su corpus encima
   de lo que el otro alcanzó a subir. El SQL está medido; que ocurra, con un claim aparcado tanto tiempo, es inferido.

**El otro camino se cerró en el mismo PR que abrió este ticket.** Un relanzamiento con el claim a medias adoptaba porque
la intención de migrar vivía en memoria, y la review midió que la ventana no era una petición: dura todo lo que el claim
pase aparcado por la red. La intención se journalea ahora con la transición al claim (`MigrationState.forwardClaimIntentRaw`,
schema 6) y la fija `afterRelaunch_theJournaledIntentStillRefuses`.

## Opciones, sin decidir

- **Guarda de linaje dentro del escritor** (`runAdoptFlow`): adoptar solo si el `CloudMigrationMarker` del líder está en
  el store local, que es la prueba de que este dispositivo espeja el corpus de esa cuenta. Lo cierra, pero un
  segundo dispositivo cuyo espejo aún no importó el marcador dejaría de adoptar hasta que llegue, y hace falta una salida
  para el efecto pendiente que no sea «reintentar para siempre». **El faro (`CloudBeacon`) no vale como prueba**: lo
  escribe también el alta born-cloud, que no tiene corpus en CloudKit.

## Criterios de aceptación

- [ ] Ni el seguidor de un adopt ni un relevo suben a una cuenta un corpus que no desciende de esa cuenta, o el caso se
      decide y se documenta como aceptado.
- [ ] El segundo dispositivo del mismo Apple ID sigue adoptando, con sus huérfanas de la ventana.
