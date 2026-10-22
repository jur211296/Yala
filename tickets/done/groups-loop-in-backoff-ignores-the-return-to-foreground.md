---
id: groups-loop-in-backoff-ignores-the-return-to-foreground
status: done
priority: low
area: "groups, sync"
created: 2026-09-15
updated: 2026-09-16
source: "review adversarial de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15)"
---

# Volver a Yala no adelanta la subida de grupos que espera su reintento

## El problema, en lenguaje de usuario

Me quedo sin red un rato con la app abierta, salgo, recupero la conexión y vuelvo a Yala. Los cambios de mis grupos no
suben al volver: pueden tardar hasta cinco minutos, salvo que guarde algo o tire hacia abajo para refrescar.

## Lo medido (leído en el código, sin ejecutar)

- Tras un fallo pasajero, el loop de Grupos duerme con un backoff creciente de 5, 10, 20… hasta 300 s
  (`SyncCadencePolicy.backoffDelay`).
- Volver a primer plano llama a `GroupsSyncClient.startIfEligible(context:trigger: "foreground")`
  (`AppBootstrapper`), pero con el loop vivo `GroupsLoopRestartLogic.shouldStart` devuelve `false` y no pasa nada: el
  sueño no se interrumpe.
- El runtime personal sí lo hace: su `handleBecameActive` cancela el sueño y corre un ciclo en el acto.
- Sin red y con la sesión vigente ya pasaba. Desde el 2026-09-15 pasa también con el token caducado: hasta entonces ese
  caso mataba el loop, y volver a primer plano lo re-arrancaba en el momento.
- Y con App Attest ausente, también desde el 2026-09-15 (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`):
  su 401 paraba el loop y volver a primer plano lo re-arrancaba; ahora espera en backoff, hasta 5 min.

## Lo que hay que decidir (Jürgen)

1. Despertar el loop al volver a primer plano (cortar el sueño y ciclar ya), como hace el runtime personal.
2. Dejarlo: los cambios suben solos en el siguiente reintento.

## Decisión Jürgen (2026-09-15)

**Despertar el loop al volver a primer plano** (opción 1): cortar el sueño del backoff y ciclar ya, como el runtime personal. No dejar solo el siguiente reintento.

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el cambio que lleva este caso a más gente.

## Hecho (2026-09-16)

**Volver a Yala ya adelanta la subida.** El sueño de cada vuelta del loop vive ahora en una tarea propia
(`GroupsSyncClient.napTask`), y el foreground la corta: el ciclo siguiente sale en el acto en vez de esperar
los 5, 10, 20… hasta 300 s que quedaran del backoff. Es el molde del runtime personal, cuyo
`handleBecameActive` re-arranca la cadencia y con eso corta el sueño en curso.

### Por dónde entra, y por qué ahí

Por el mismo `startIfEligible(context:trigger:)` que ya llamaba `AppBootstrapper.handleBecameActive` — en su
`else`, o sea justo donde antes no pasaba nada porque el loop ya vivía. Que el despertar viva DENTRO de esa
función y no en una llamada aparte del bootstrapper es lo que impide que un call-site futuro se olvide de
despertar: el post-sign-in lo hereda sin tocarlo.

La decisión la toma `GroupsLoopRestartLogic.shouldWake`, complemento exacto de `shouldStart`: mismas tres
entradas, `loopAlive` invertido. Un test recorre las ocho combinaciones y exige que las dos sean disjuntas y
que su unión sea el gate compuesto, así que el día que `shouldStart` gane una condición nueva el `else` no
podrá despertar el loop en el caso que esa condición vino a excluir.

### Dos ventanas, dos mecanismos, y ninguna se solapa

- **El foreground que llega con el loop DORMIDO** lo sirve la cancelación del `napTask`.
- **El que llega MIENTRAS el ciclo corre** no tiene sueño que cortar: lo sirve la marca `wakeRequested`, que
  pone a 0 el delay de esa vuelta y solo de esa (se baja al entrar en cada vuelta, así que un ciclo
  `.coalesced` no puede encadenar vueltas sin pausa).

Despertar **no toca `consecutiveTransients`**: adelantar un reintento no borra la racha, que es lo que mide
cuánto esperar si este ciclo también falla. Lo fija una aserción: tras el wake, el segundo backoff sigue
pidiendo 10 s.

### El riesgo que traía el diseño, y su test

Sacar el sueño a una tarea aparte podía romper algo que ya funcionaba: un `Task {}` **no hereda la
cancelación** de quien lo crea, así que `stopLoop()` —el que llama `teardownForSignOut` en los cinco caminos
de cierre de sesión— se habría quedado esperando el backoff entero antes de que el loop mirase su propia
cancelación. Lo cierra el `withTaskCancellationHandler` de `nap(_:)` y lo pinnea
`stopLoopWhileSleeping_cutsTheNapToo`.

### Lo que cazó la review adversarial, que es la mitad no obvia

Tres lentes independientes coincidieron en el mismo defecto **serio, y era mío**: el sueño en tarea aparte se
publicaba en un campo sin identidad. `stopLoop()` deja `loopTask = nil` en el acto, pero el loop viejo sigue
dentro de su request —lo que tarde la red— y al salir corre sus `defer`; entre medias, un
`startIfEligible("post-sign-in")` —el que corre justo después de cerrar sesión y volver a entrar— publica un
loop nuevo. El `defer` del viejo le borraba el handle al nuevo: **dos loops vivos**, un `stopLoop` posterior
cancelando `nil`, y un wake que emitía su línea en el log sin cortar ningún sueño. O sea, el bug del ticket
resucitado y encima invisible. Ahora cada loop lleva su **generación** y solo publica y limpia el vigente;
el mismo defecto estaba en el `defer { loopTask = nil }` **anterior a este cambio**, y va arreglado aquí
porque este cambio lo vuelve dañino de una forma nueva.

Y cazó una aserción mía **que no podía fallar**: el primer test del gate del despertar comprobaba la
cancelación justo después del wake, sin soltar el MainActor — `cancel()` solo marca la tarea, y el `catch`
que lo registra no corre hasta entonces, así que salía verde también con el gate borrado. Se descubrió
midiendo el mutante, no leyendo el test.

### Verificación

Build ×2 sin warnings nuevos. `GroupsLoopRestartLogicTests` (+5 casos) y `GroupsSyncClientTests` (+6).
**Mutation-tested ×7**: quitar el wake del guard · quitar la propagación de la cancelación · quitar el
`napTask?.cancel()` · quitar la marca del mid-ciclo · no bajarla por vuelta · borrar el gate `shouldWake` del
cliente · borrar la comprobación de generación del `defer` del loop. **Los siete en rojo**, cada uno en su
caso. Los tests que miden el corte del sueño usan un sleeper de 400 ms real y un fusible: si el wake no
llega, **fallan** en vez de colgarse.

**Un mutante SOBREVIVE y se declara**: publicar el `napTask` sin comprobar la generación
(`if loopGeneration == generation { napTask = nap }` → `napTask = nap`). Su escenario exige que el loop nuevo
llegue a dormir ANTES de que el viejo llegue a su propio sueño, y montar eso en un test costaba más andamio
del que mide. Se mantiene por simetría con el `defer` de al lado, que sí está pinneado.

### Residuales conocidos, medidos y aceptados

- **Despertar también corta la cadencia sana de 60 s**, no solo el backoff. Es lo que hace
  `CloudSyncRuntime.handleBecameActive` en `.running`, y distinguirlas sería divergir del molde que el ticket
  manda copiar. El rastro lleva `sleeping=<bool>` para poder separarlas en el log.
- **Sin red, cada vuelta a la app suma un ciclo fallido** y por tanto un escalón de backoff: con seis o siete
  activaciones se clava el tope de 300 s. Misma aritmética que el runtime personal, cuyo `.coalesced` solo
  protege si ya hay un ciclo en vuelo.
- **Nada de esto alcanza al modo piggyback con el runtime personal PARADO**, donde Grupos ni siquiera tiene
  loop: sale como ticket propio, `groups-has-no-cadence-when-the-personal-runtime-is-stopped`.

**Sin device-QA, y el motivo:** reproducirlo pide cortar la red con cambios de grupos sin subir, esperar a
que el backoff crezca y volver a primer plano con la red ya recuperada. No hay seam de simulador que lo
monte, y lo que se observaría —que la subida sale antes— no tiene superficie visual. El rastro en producción
es la línea `GroupsSync loopWoken trigger=foreground` en Console.app.

### Lo que deja anotado en otro sitio

`groups-loop-restart-docs-cite-a-retired-mount-guard` gana un tercer desajuste medido: dos comentarios de
este mismo par de ficheros llaman al canal «DARK (producción hoy)» y el compilado está en `true` desde el
2026-07-30.
