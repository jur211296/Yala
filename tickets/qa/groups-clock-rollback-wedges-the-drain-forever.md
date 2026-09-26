---
id: groups-clock-rollback-wedges-the-drain-forever
status: qa
priority: medium
area: "groups, sync"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `groups-drain-failure-reads-as-nothing-pending` (2026-09-26), lente de regresión"
---

# Si la hora del iPhone retrocede, tus cambios de grupos dejan de subir para siempre

## El problema, en lenguaje de usuario

Si alguien adelanta la hora del iPhone a mano, apunta un gasto de grupo y luego la devuelve (o el teléfono corrige la
hora sola), los gastos de grupo que apunte después de más de 5 minutos de diferencia dejan de subir. No se curan
esperando. Y desde el 2026-09-26 tampoco se puede cerrar sesión, desasociar la cuenta de grupos ni «Empezar de cero»:
las tres salidas se niegan a borrar lo que no subió y dicen «inténtalo en un rato», que en este caso no es verdad.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- El drain estampa cada cambio con la fecha de su transacción: `clock.send(now: tx.timestamp)`
  (`GroupsSyncClient.translate…`, `HLC.swift`). Si el reloj lógico persistido (`GroupSyncCursor.clockLatestHLC`) va más
  de `HLCClock.maxDriftMillis` (5 min) por delante de esa fecha, `send` lanza y la vuelta corta en esa transacción.
- El cursor se queda antes de ella, así que cada drain posterior corta en el mismo sitio. La fecha de la transacción no
  cambia, y el reloj lógico tampoco baja: no se cura con el tiempo.
- Nada de lo que se apunte después sale del teléfono: el drain nunca pasa de esa transacción.
- Desde `groups-drain-failure-reads-as-nothing-pending` esa vuelta cortada devuelve `false` y las salidas que borran se
  bloquean. Es a propósito —borrar perdería esos cambios, que ya no suben—, pero el aviso dice `.uploadRetryLater`.

Es el mismo mecanismo que describe `clock-drift-aborted-drain-lets-the-pull-overwrite-untranslated-edits` en el canal
personal, que da por hecho que «se corrige» al arreglar el reloj: con el sello por fecha de transacción, no se corrige.

## Por dónde va (a decidir; toca el núcleo del sync)

- Estampar con `max(tx.timestamp, ahora)` rompe el determinismo del HLC, del que depende el dedup de un re-drain tras un
  fallo (`seen` por `(syncID, hlc, op)`). Hay que medir qué duplicaría.
- O tolerar la deriva en `send` para eventos LOCALES antiguos (la deriva protege de relojes ADELANTADOS, no de
  transacciones viejas).
- Y, mientras tanto, decidir si esas salidas deben ofrecer algo distinto de «inténtalo en un rato».

## Criterios de aceptación

- [x] Con el reloj retrocedido más de 5 min entre dos cambios de grupo, el segundo sube en cuanto hay red.
- [x] Un test que avanza la hora real SIN tocar `clockLatestHLC` y comprueba que el drain termina.

## Hecho (2026-09-26)

**Qué cambia para el usuario.** Si la hora del iPhone estuvo adelantada y volvió, los gastos de grupo que apunte después
suben como siempre, y cerrar sesión, desasociar y «Empezar de cero» ya no se paran por eso. No hay texto nuevo: el
«inténtalo en un rato» falso dejaba de ser verdad porque el bloqueo no se curaba, y ahora ese bloqueo ya no ocurre.

**Qué se tocó.** `HLCClock.sendLocal(eventTime:)` (`HLC.swift`): el mismo algoritmo que `send`, sin la guarda de deriva y
con el contador agotado avanzando 1 ms. El drain de Grupos (`GroupsSyncClient.appendRow`) estampa con ella y sigue usando
la fecha de la transacción, así que un re-drain produce los mismos HLC y el dedup no duplica. `send` no cambia. Las
decisiones y lo descartado, en el Paso 0 del encargo (viaja al PR).

**Verificado.** `GroupsClockRollbackDrainTests` (6 casos, cliente real con stores en disco: el reloj persistido un día por
delante y sin tocarlo, el gasto sube, lo de después sube ordenado detrás, el re-drain no duplica en los dos regímenes, el
HLC sale de la fecha de la transacción y no de la hora de ahora, y la captura previa a una salida termina, sube y queda
`.drained`) y 7 casos de `sendLocal` en `HLCTests`. Mutantes: volver a `send` pone rojos los 4 casos del reloj adelantado.
Review adversarial de tres lentes (HLC y LWW, regresión, reglas del área); lo que cazaron, arreglado en la misma rama.

**Encontrado y no tocado**, con ticket: el precio del arreglo, que un teléfono con la hora adelantada gana los conflictos
de sus grupos hasta que la hora real lo alcanza (`groups-clock-ahead-wins-every-conflict-until-real-time-catches-up`); y el
gemelo del canal personal, que sigue con `send` (`personal-clock-rollback-wedges-the-drain-forever`).

## Device-QA (pendiente, no bloquea)

Inferido del código, sin recorrer en un iPhone. Hace falta una cuenta de grupos con sesión y un grupo con otro miembro
(o un segundo iPhone con la misma cuenta, para ver que el gasto llega).

1. En el iPhone, con «Ajustar automáticamente» encendido (Ajustes → General → Fecha y hora), abre Yala y entra en el grupo.
2. Ajustes del iPhone → General → Fecha y hora → apaga «Ajustar automáticamente» y **adelanta la fecha un día**.
3. Vuelve a Yala y apunta un gasto en el grupo («Prueba adelantada»). Espera unos segundos.
4. Vuelve a Ajustes → Fecha y hora y **enciende «Ajustar automáticamente»** (la hora vuelve a la real).
5. En Yala apunta otro gasto en el mismo grupo («Prueba después»).
6. **Esperado**: los dos gastos aparecen en el otro iPhone o en el otro miembro tras tirar hacia abajo en el grupo. Con el
   código de antes, «Prueba después» no salía nunca del teléfono.
7. Perfil → Ajustes → cuenta de grupos → «Desasociar».
8. **Esperado**: desasocia sin el aviso «no llegaron al servidor… inténtalo en un rato». Con el código de antes, se
   quedaba en ese aviso para siempre.
9. Precio aceptado, por si lo ves: durante ese día, si el otro miembro edita «Prueba adelantada», gana tu versión.
