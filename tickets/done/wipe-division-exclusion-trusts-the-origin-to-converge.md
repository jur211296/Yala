---
id: wipe-division-exclusion-trusts-the-origin-to-converge
status: done
priority: medium
area: "groups, sync"
created: 2026-09-28
updated: 2026-09-28
qa-status: not-replicable
qa-date: 2026-09-28
qa-notes: pide dos dispositivos y 72 h de espera; lo cubren los tests contra el bridge real
source: "review adversarial de `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere` (lentes de grupos y de sync, 2026-09-28); inferido leyendo código, NO reproducido"
---

# Si el dispositivo que vació no llega a reponer, lo que prometió reponer no vuelve

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPad, que tiene los mismos grupos que el iPhone, y no lo vuelvo a abrir (o lo borro). En el iPhone los
gastos y liquidaciones de grupo desaparecen de mis cuentas y no vuelven.

## Lo medido (2026-09-28, leyendo código)

- Desde el ticket `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere`, el origen escribe en el iCloud-KV
  qué repone (`GroupsRemoteWipeDivision.declare`) y el receptor repone el resto, excluyendo esos ids para siempre
  (`GroupsBridgeRestoreConvergenceStore.markPending(excluding:)`).
- La convergencia del origen corre en su SIGUIENTE arranque en frío. Si no llega (desinstalación, relevo de persona que
  retira la petición, un gasto que agota los intentos de `GroupsPendingBridgeIntent`), nadie comprueba que lo prometido
  llegó.
- No es regresión: antes del reparto esas filas tampoco volvían.

## Qué hay que decidir

Si el receptor guarda los ids excluidos y, pasado un plazo, re-puentea los que sigan sin ninguna fila («si ya falta», el
criterio de `GroupsRemoteWipeReturn`). Coste: si el origen converge después del plazo, duplica mientras no se crucen por
el espejo.

## Relacionados

- [[a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere]]
- [[wipe-division-complement-can-be-bridged-twice]]

## Decidido (2026-09-28)

El receptor repone él lo prometido que no llega, pasado un techo. El Paso 0 entero está en
`encargos/lanzados/2026-09-28-wipe-division-exclusion-trusts-the-origin-to-converge.md`.

- **La promesa.** Al resolver el reparto, el receptor apunta en local los ids que excluye, la hora de la señal y desde cuándo confía
  (`GroupsRemoteWipeDivisionStore.trustedKey`). Lo apunta ANTES de la petición con exclusión.
- **«Llegó» = hay aquí una fila de ese id posterior a la señal** (transacción o borrador). Lo que llega sale de la promesa.
- **Techo: 72 horas** desde el arranque que resuelve el reparto (`GroupsRemoteWipeDivisionLogic.trustCeiling`). Pasado,
  `GroupsRemoteWipeDivision.takeOverIfOverdue` re-puentea lo que falta, en el arranque, justo después de la convergencia y
  con sus puertas.
- **Sin copias dobles si el origen repone tarde:** con sus filas ya aquí no se toca nada; si converge después, su bridge
  concilia por id sobre las filas del receptor ya bajadas. Queda el residual de siempre, los dos puenteando antes de
  cruzarse por el espejo (ticket `wipe-division-takeover-can-cross-a-late-origin-before-the-mirror`).
- Descartado: una nota «me hice cargo» en el iCloud-KV. Más cuota (`wipe-division-kv-key-has-no-quota-ceiling`) para una
  ventana de segundos.

## Cómo se probó

- **Repro en rojo primero:** con la retoma vacía, pasado el techo ni el gasto ni las liquidaciones volvían (4 aserciones).
- Contra el bridge real (`GroupsBridgeRestoreConvergenceBehaviourTests`, sección «Lo que el origen prometió y no llega»):
  origen que nunca repone, a tiempo, tarde antes de que el receptor mire, tarde después de que repusiera, a medias, y las
  puertas (solo-grupos y un reparto nuevo por llegar).
- Lógica (`GroupsRemoteWipeDivisionTests`): el techo con sus vecinos y el reloj atrás, la poda, la promesa que apunta el
  reparto (hora de la espera, sustitución, vacío) y el relevo de persona.
- Scans (`RemoteWipeSignalWiringTests`): la llamada en `retryPendingBridges` y el orden promesa → petición.

- Review adversarial de dos lentes (sync/dinero y tests). Cambió dos cosas: el techo cuenta desde que se resuelve el
  reparto (desde la espera, un reparto tardío vencía en el mismo arranque) y «llegó» exige una fila posterior a la señal.
  Y sumó un caso con la marca de aprobación, una liquidación sin confirmar, una de un grupo oculto y un gasto sin atender.

## Por qué a `done` sin device-QA

Reproducirlo a mano pide dos dispositivos, un origen que no vuelva a abrirse y esperar 72 horas. Es el criterio del
barrido del 23-sep: lo cubren sus tests contra el bridge real.
