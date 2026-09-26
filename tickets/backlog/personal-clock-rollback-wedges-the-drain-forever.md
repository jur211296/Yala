---
id: personal-clock-rollback-wedges-the-drain-forever
status: backlog
priority: medium
area: "modo-nube, sync"
created: 2026-09-26
updated: 2026-09-26
source: "`groups-clock-rollback-wedges-the-drain-forever` (2026-09-26), al buscar todas las instancias del patrón"
---

# En la nube, si la hora del iPhone retrocede, tus cambios personales dejan de subir para siempre

## El problema, en lenguaje de usuario

Con tus datos en la nube, si adelantas la hora del iPhone, apuntas algo y la devuelves (o el teléfono corrige la hora
solo), lo que apuntes después con más de 5 minutos de diferencia no sube a la nube. Esperar no lo arregla: tus otros
dispositivos no lo ven nunca.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- Es el mismo mecanismo que `groups-clock-rollback-wedges-the-drain-forever` arregló en Grupos. El drain personal estampa
  con `clock.send(now: tx.timestamp)` (`CloudSyncEngine.appendRow`, `Yala/Services/CloudSync/CloudSyncEngine.swift`). Con
  el reloj lógico persistido (`SyncCursor.clockLatestHLC`) más de `HLCClock.maxDriftMillis` por delante de la fecha de la
  transacción, `send` lanza, la traducción se corta en esa transacción y el cursor se queda antes de ella. La fecha de la
  transacción no cambia y el reloj lógico no baja: corta en el mismo sitio en cada vuelta.
- Aquí la vuelta cortada devuelve `true` (lo traducido se persiste), así que ningún gesto se bloquea: los cambios
  simplemente no salen. `clock-drift-aborted-drain-lets-the-pull-overwrite-untranslated-edits` da por hecho que «se
  corrige al arreglar el reloj»; con el sello por fecha de transacción, no se corrige.
- Otros tres `clock.send(now: now)` del motor (`CloudSyncEngine.swift`, snapshot y remap de identidad) sí usan la hora de
  ahora, así que se curan cuando la hora real alcanza al reloj lógico: con la hora puesta meses adelante, meses. Lo mismo
  `PrefsOutbox.enqueue` (`Yala/Services/CloudSync/PrefsOutbox.swift`, `clock.send(now: now)` sobre `lastIssuedHLC`
  persistido): cada preferencia que cambies en ese tiempo sale `clockFailed`.

## Por dónde va

`HLCClock.sendLocal(eventTime:)` ya existe desde el arreglo de Grupos: mismo algoritmo que `send`, sin guarda de deriva y
con el contador agotado avanzando el milisegundo. Estampa igual de determinista (el dedup del re-drain sigue valiendo).
Antes de cambiarlo hay que mirar a los consumidores que tratan la deriva como pasajera a propósito (la subida del
snapshot de la ida, `MigrationSnapshotUploader`, y `MigrationWorkExecutor`): el drain es el único que sella con la fecha
de la transacción.

## Criterios de aceptación

- [ ] Con el reloj lógico un día por delante, un cambio personal nuevo llega al outbox y el drain no corta.
- [ ] Test con el reloj persistido adelantado y el mismo `SyncCursor`, sin tocarlo entre vueltas.
