---
id: apple-id-change-check-stays-off-after-a-failed-migration
status: qa
priority: low
area: "sesiones, modo-nube"
created: 2026-09-27
updated: 2026-10-06
qa-status: needs-testing
source: "review adversarial de `apple-id-change-boot-check-runs-before-the-migration-guard-can-see` (2026-09-26), lente de falso bloqueo"
---

# Tras una migración fallida, el cambio de Apple ID no se detecta hasta pulsar «Reintentar»

## El problema, en lenguaje de usuario

Si un paso de los datos a la nube terminó en fallo y la persona no ha vuelto a Almacenamiento, Yala no le ofrece cerrar
la sesión privada aunque cambie de Apple ID. No se pierde nada: se queda en el teléfono una copia que es de otra cuenta.

## Por qué pasa (medido el 2026-09-26)

- `failedRollback` deriva `.failed(.migration)` y el guard exige `.idle` (`AppleIDChangeCloseLogic.migrationAtRest`). La
  fase dura hasta «Reintentar» (`CloudMigrationController.resetAfterRollback`).
- Era el criterio del controller antes del ticket de origen; hasta entonces el arranque lo saltaba porque el controller
  aún no existía.
- Antes del cutover el teléfono está intacto (`MigrationWorkExecutor`), así que probablemente se podría ofrecer. Pero
  el terminal puede llevar efectos pendientes (`.rollback`) que un resume ejecuta.

## Qué hay que decidir (Jürgen)

¿Se ofrece el cierre con una migración fallida y sin efectos pendientes? Hasta decidirlo, no se ofrece.

## Nota (2026-09-27): la decisión ya gobierna dos lectores

Desde `private-sign-out-proceeds-with-a-migration-in-flight`, el cierre de la sesión privada usa el MISMO predicado
(`CloudSignOutFlowLogic.migrationBlockReason` sobre `migrationAtRest`). Con `failedRollback`, hoy tampoco se puede cerrar la
sesión privada hasta pulsar «Reintentar»: el aviso lo dice. Si se decide ofrecer el cierre tras un fallo sin efectos
pendientes, el término entra en `migrationAtRest` y se abren los dos a la vez; el test
`migracionFallida_tambienPara` de `PrivateSignOutMigrationGuardTests` es el que tiene que cambiar.

## Decisión (Jürgen, 2026-10-04): A

Ofrecer cerrar la sesión privada tras una migración fallida, solo cuando el fallo NO lleva efectos pendientes. Con
efectos pendientes o con la migración en curso, sigue sin ofrecerse.

## Premisa re-medida (2026-10-06, `origin/2.1` 78c7fa34b)

Se sostiene: `migrationAtRest` exigía que la derivación diera `.idle`, `failedRollback` deriva `.failed(.migration)`, y
los dos lectores del cierre leían ese predicado. **Y hay un tercer lector que el ticket no nombraba**: el borrado
pendiente del iCloud privado del arranque (`ContentView`, `WelcomePrivateICloudGateLogic.lateWipeLaunch` y
`waiverLapses`). Ensanchar `migrationAtRest` habría hecho que, tras un fallo, ese borrado se reanudara solo y que caducara
la renuncia de «Activar la nube sin borrar», con «Reintentar» todavía a la vista. Por eso el término nuevo va en un
predicado aparte y ese lector no cambia.

## Qué cambió (2026-10-06)

Para quien usa la app: si un paso de sus datos a la nube falló y no volvió a Almacenamiento, **puede cerrar la sesión
privada desde Ajustes**, y si cambia de Apple ID **Yala le ofrece cerrarla** al arrancar. Si el fallo todavía tiene algo
pendiente de deshacer (lo deshace el arranque siguiente) o la migración está en curso, sigue parándose como antes, con el
mismo aviso.

- **Predicado nuevo, `AppleIDChangeCloseLogic.migrationAllowsPrivateSessionClose`** = `migrationAtRest` **o**
  `migrationFailedAndSettled`. Lo leen los dos lectores del cierre y solo ellos: el guard del arranque
  (`AppBootstrapper.migrationAtRestForAppleIDChange`) y `CloudSignOutFlowLogic.migrationBlockReason` (que gobierna el cierre
  manual de las tres celdas por archivos y la hoja del cambio de Apple ID). `migrationAtRest` se queda estricto.
- **`migrationFailedAndSettled`**: el controller no trabaja y su estado es `nil` o `.failed(.migration)` (un `.idle`
  desfasado no concede); la derivación del journal da `.failed(.migration)` (deja fuera la vuelta fallida y el
  relanzamiento pendiente); sin efectos pendientes; modo persistido `.icloud`.
- **Los pendientes salen del mismo fetch que la fase**: `MigrationPhaseStore.currentJournalRead`
  (`JournaledMigrationRead`), y `MigrationRestReading` gana `journalHasPendingEffects`. `currentPhaseRead` y
  `phaseRead(fetch:)` son esa lectura sin los pendientes. Ilegible cuenta como «con pendientes».
- **Coherencia tras cerrar (punto 3 del encargo): sin cambios, por construcción.** El cierre arma el borrado del
  arranque, que borra el archivo sync-meta donde vive el journal (`performSignOutWipeIfArmed`, fijado por
  `SignOutWipeHookTests`): «Reintentar» y el fallo viejo no pueden volver. Si el borrado del archivo falla, el arm se
  retira y no se borró nada. «Reintentar» no se tocó.
- Sin copy nuevo.

Tests: `AppleIDChangeFailedMigrationCloseTests` (la tabla: fallida sin efectos → sí; con efectos → no; en curso → no;
idle → sí; un mutante por término), `PrivateSignOutMigrationReasonTests` (`migracionFallida_tambienPara` pasa a
`migracionFallida_sinPendientesSigue_conPendientesPara`, y la rejilla compara con el predicado nuevo y lleva los
pendientes), `PrivateSignOutMigrationWriterTests` (la puerta del escritor, en las tres celdas), `MigrationPhaseStoreJournalTests`
(fase y pendientes de la misma fila; ilegible cuenta como pendiente) y los scans de `AppleIDChangeWiringTests`,
`PrivateSignOutMigrationWiringTests` y `MigrationJournalUnreadable*`. XCUITest:
`SessionExitsPerCellUITests#test_privateCell_C_signOutAfterAFailedMigrationWithNothingPending_isNoLongerStoppedByIt`,
con el seam `-uitest-migration-failed` (finge la fila del journal en los dos fetch de producción) y Almacenamiento con
«Reintentar» como control en la misma corrida.

## Qué quedó fuera

- **El arranque con el `.rollback` todavía pendiente no ofrece el cierre en ESE arranque.** La comprobación del Apple ID
  corre una vez y el resume del arranque drena el efecto después; el siguiente arranque (o el siguiente cambio de cuenta)
  ya lo ofrece. Es el residual (3) que el docblock de `checkForAppleIDChange` ya tenía escrito para cualquier disparo que
  llega fuera de reposo; converge solo y no se abre ticket.
- **La vuelta a iCloud fallida (`reverseFailedRollback`) sigue parando el cierre**: no entra en la decisión.
- **El borrado pendiente del iCloud privado sigue congelado tras un fallo asentado**: su lector (`ContentView`,
  `lateWipeLaunch`) se dejó en `migrationAtRest` estricto, porque comparte el booleano con la caducidad de la renuncia de
  «Activar la nube sin borrar». La decisión A no lo cubre: ticket
  [[late-icloud-wipe-stays-frozen-after-a-settled-failed-migration]].

## Guion de QA en iPhone (opcional; no bloquea)

**El caso del ticket no se puede provocar a mano en el iPhone**: hace falta una ida a la nube que salga por un fallo
(un techo de 15 min o de 72 h, o otro teléfono que tome el relevo) y, para la oferta, además cambiar de Apple ID. El
cierre manual lo cubre el XCUITest; la oferta del cambio de Apple ID, la tabla unitaria y los scans (en el simulador esa
comprobación está apagada: sale a CloudKit). Lo que sí se mira en el iPhone es que nada cambió en reposo:

Hace falta Yala compilado desde `2.1` (con este cambio), en iCloud y sin ninguna migración empezada.

1. Ve a Perfil → Ajustes → «Dónde viven tus datos». **Comprueba:** la tarjeta ofrece «Migrar a la nube», no un fallo.
2. Vuelve a Ajustes y toca «Cerrar sesión». **Comprueba:** sale la hoja de siempre. Toca «Cancelar»: no se borra nada.

Si algún día un teléfono real se queda con una tarjeta «No pudimos activar la nube…» y el botón «Reintentar» en
Almacenamiento: desde este cambio, «Cerrar sesión» en Ajustes ya no responde «El paso de tus datos entre iCloud y la nube
todavía no terminó» (salvo en el primer arranque tras el fallo, si quedó algo por deshacer).
