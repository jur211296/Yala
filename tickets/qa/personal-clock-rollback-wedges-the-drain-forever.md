---
id: personal-clock-rollback-wedges-the-drain-forever
status: qa
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

- [x] Con el reloj lógico un día por delante, un cambio personal nuevo llega al outbox y el drain no corta.
- [x] Test con el reloj persistido adelantado y el mismo `SyncCursor`, sin tocarlo entre vueltas.

## Hecho (2026-09-26)

**Qué cambia para el usuario.** Con tus datos en la nube, si la hora del iPhone estuvo adelantada y volvió, lo que
apuntes después sube como siempre y tus otros dispositivos lo ven. Antes no salía nunca del teléfono. Lo mismo con las
preferencias: un cambio de ajustes hecho en ese tiempo ya no se pierde. Sin texto nuevo.

**Qué se tocó.**
- El drain personal (`CloudSyncEngine.appendRow`) estampa con `HLCClock.sendLocal(eventTime: tx.timestamp)`, la pieza
  que abrió el arreglo de Grupos. Sigue usando la fecha de la transacción, así que un re-drain produce los mismos HLC.
- `PrefsOutbox.enqueue` estampa con `sendLocal(eventTime: now)`. Su reloj solo lo avanzan sus propios cambios, así que
  la guarda de deriva solo protegía al teléfono de su propio pasado, y cada cambio rechazado se perdía.
- **No se tocaron, a propósito:** la subida del snapshot, las huérfanas del adopt y el remap de identidad estampan con la
  hora de ahora, sus llamadores tratan la deriva como pasajera (reintentan) y se curan cuando la hora real alcanza al
  reloj lógico. Las decisiones, en el Paso 0 del encargo (viaja al PR).
- Seam `_testThrowOnClockStamp` para el único corte que queda (un año fuera de 0001–9999); el T14 de
  `CloudSyncEngineTests` pasa a él. Regla de sync, comentarios e índice de QA al día.

**Verificado.** `PersonalClockRollbackDrainTests` (5 casos, motor real con stores en disco: el reloj persistido un día
por delante y sin tocarlo, el cambio sale y el cursor lo pasa, lo de después sale ordenado detrás y el reloj persistido
sigue al último, el re-drain no duplica, el HLC sale de la fecha de la transacción, y el corte que queda deja la
transacción para la vuelta siguiente) y 4 casos de reloj en `PrefsOutboxTests`. Mutantes, 6/6 muertos: volver a `send`
en el drain o en las prefs, estampar con la hora de ahora o con otra fecha fija, quitar el seam. Review adversarial de
tres lentes (HLC, regresión, tests): sin regresiones; lo que cazó (dos huecos de test y frases desactualizadas),
arreglado en la misma rama.

**Encontrado y no tocado**, con ticket: el precio, que ese teléfono gana los conflictos hasta que la hora real lo alcanza
y el otro dispositivo puede quedarse con su valor sin converger
(`personal-clock-ahead-wins-every-conflict-until-real-time-catches-up`). Actualizados por el cambio:
`clock-drift-aborted-drain-lets-the-pull-overwrite-untranslated-edits` (su única causa conocida desaparece) y
`personal-sign-out-reads-an-unfinished-drain-as-nothing-pending` (queda solo el drain que aborta).

## Device-QA (pendiente, no bloquea)

Inferido del código, sin recorrer en un iPhone. Hace falta una cuenta con los datos en la nube y un segundo dispositivo
con la misma cuenta (otro iPhone o iPad) para ver que el cambio llega.

1. En el iPhone, con «Ajustar automáticamente» encendido (Ajustes → General → Fecha y hora), abre Yala.
2. Ajustes del iPhone → General → Fecha y hora → apaga «Ajustar automáticamente» y **adelanta la fecha un día**.
3. Vuelve a Yala y apunta un gasto («Prueba adelantada»). Espera unos segundos.
4. Vuelve a Ajustes → Fecha y hora y **enciende «Ajustar automáticamente»** (la hora vuelve a la real).
5. En Yala apunta otro gasto («Prueba después») y cambia un ajuste que se sincronice (por ejemplo, tu nombre en Perfil).
6. Espera un minuto con la app abierta.
7. **Esperado**: en el otro dispositivo, tras abrir Yala, aparecen los dos gastos y el ajuste cambiado. Con el código de
   antes, «Prueba después» y el ajuste no salían nunca del iPhone.
8. Precio aceptado, por si lo ves: durante ese día, si editas «Prueba adelantada» desde el otro dispositivo, gana la
   versión del iPhone.
