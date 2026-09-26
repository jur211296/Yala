---
id: groups-drain-failure-reads-as-nothing-pending
status: qa
priority: medium
area: "groups, modo-nube"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently` (2026-09-26)"
---

# Un drain de grupos que falla se lee como «no hay nada pendiente»

## El problema

Antes de dar por vacío el outbox de grupos, el cierre de sesión y «Empezar de cero» drenan el SwiftData History al
outbox (`GroupsSyncClient.drainOnce`) y cuentan las filas vivas. Pero `drainOnce` no devuelve nada: `performDrain` se
traga cualquier error (`fetchHistory`, `buildLookups`, el `save`), y la deriva del reloj HLC corta con `break`. Lo que
no llegó a traducirse vive solo en el History, el recuento da 0 y el borrado sigue. Después ningún drain encuentra una
fila viva que traducir, y ese gasto se pierde en silencio.

Lo encontró la lente de datos de la review de `fresh-start-wipe-kills-unsent-group-writes-silently` (2026-09-26),
leyendo el código sin ejecutarlo. El hueco ya existía en `CloudSessionSignOut.pushAllPendingGroupsForSignOut`; desde
ese día también lo usa `groupsOutboxIsSettledEmpty`.

**Su gemelo, por el espejo:** el drain escribe primero en el espejo del App Group (regla Q3). Un kill o un `save`
fallido deja la fila solo ahí, y la rehidratación solo corre en `startIfEligible`, con el flag compuesto y una sesión.
En un proceso sin esas dos cosas el recuento da 0 y `resetSyncState` purga el espejo.

## Por dónde va

El molde es el del canal personal (`CloudSyncEngine.drainOnce` devuelve si terminó, desde
`drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`). Que `GroupsSyncClient.drainOnce` lo devuelva también,
y que los dos pre-checks bloqueen con `false`. Para el espejo, contar sus entradas en el cinturón del borrado.

## Arreglado (2026-09-26)

**Cerrar sesión, desasociar la cuenta de grupos y «Empezar de cero» ya no dan por subido un cambio de grupos que no
llegó a capturarse.** Si la captura falla, o si el espejo del App Group guarda cambios que no están en la cola, no
borran nada y lo dicen con el texto que ya existía: «no llegaron al servidor, siguen en este teléfono, inténtalo en un
rato» — o «vuelve a iniciar sesión» cuando solo eso los sube.

- **`GroupsSyncClient.drainOnce` devuelve si terminó** (molde del personal). `false` con cualquier error de
  `performDrain` y **también con el corte del reloj**, que en el personal sí es `true`: aquí lo leen gestos que borran.
- **Captura previa a una salida** (`captureLocalWritesForExit`): rehidratar el espejo → drenar → barrer el veneno.
  Rehidratar aquí cierra el gemelo del espejo cuando hay sesión aunque el flag compuesto esté apagado.
- **Veredicto puro** (`CloudSignOutFlowLogic.groupsCaptureVerdict`): con el outbox a 0, `.drained` solo si la captura
  terminó y el espejo no guarda nada fuera; si no, bloquea con `.uploadRetryLater` (cifra del espejo, o sin cifra).
- **El push-all re-captura** tras cada ciclo que deja el outbox a 0 (el drain del ciclo no viaja en su outcome), y
  **ante un bloqueo por App Attest**: es el único que la salida «perderlos» deja seguir, y ahora no puede llevarse lo
  que el aviso no enseñó (`attestBlockAfterRecapture`).
- **Alcance del espejo**: el push-all mira solo el de la sesión (lo único que puede subir); el borrado de «Empezar de
  cero», el de la sesión o **todo sin sesión**, porque purga el espejo entero. La subida previa comprueba ese residuo
  antes de dejar pasar (`freshStartResidualReason`: sin sesión, «vuelve a iniciar sesión»).
- **El cinturón del escritor** (`DataWipeService.requireNoUnsentGroupWrites`) cuenta también el espejo.
- **Con la traducción cortada no se re-ancla el token** (saltaba el corte y el drain siguiente daba `true` con el
  gasto perdido; preexistente, lo cazó la review).
- Seam `CloudSessionSignOut.GroupsExitWitness`, por parámetro: el espejo real del simulador guarda 48 entradas de
  `auth-uid-1` que otras suites dejan (ticket `unit-tests-write-group-amounts-into-the-real-app-group-mirror`).

**Verificado**: 21 casos nuevos (`GroupsDrainFailureReadsAsPendingTests.swift`, cuatro suites, y uno en
`GroupsDrainHistoryStoreAnchorTests`), con el cliente real, stores en disco y un espejo temporal; 17 + 5 mutantes;
review adversarial de tres lentes (datos, regresión, rule de área + concurrencia).

**Lo que la review encontró y no se tocó**, con ticket: el reloj que retrocede atasca el drain para siempre
(`groups-clock-rollback-wedges-the-drain-forever`), el cierre privado cuenta sin capturar
(`private-sign-out-counts-group-writes-without-capturing-them`), y el gemelo personal
(`personal-sign-out-reads-an-unfinished-drain-as-nothing-pending`).

## Device-QA (pendiente, no bloquea)

**Actualizado el 2026-09-26 por `groups-clock-rollback-wedges-the-drain-forever`.** El guion de antes atrasaba la hora del
iPhone para provocar un drain a medias, que era la única forma de hacerlo a mano. Desde ese ticket el reloj ya no corta el
drain: con la hora atrasada, el gasto **sube** y «Desasociar» **sigue**. Ese recorrido es ahora el guion de
`groups-clock-rollback-wedges-the-drain-forever`, y su resultado es el contrario del que esperaba este.

Lo que este ticket bloquea (un `save` o una lectura del History que fallan) no se puede provocar en un iPhone. Queda
cubierto por los tests con el seam (`GroupsDrainCaptureTests`, `GroupsExitGesturesCaptureTests`) y no tiene paso de
device-QA.
