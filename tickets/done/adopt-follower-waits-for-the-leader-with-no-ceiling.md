---
id: adopt-follower-waits-for-the-leader-with-no-ceiling
status: done
priority: medium
area: "modo-nube, migración, adopt"
created: 2026-09-23
updated: 2026-09-23
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: pide dos iPhone y un lider parado a media activacion; cubierto por MigrationRunnerTests 16-bis
source: "Paso 0 de `adopt-claim-stays-parked-with-no-ceiling` (2026-09-23): la otra fase que reclama para un adopt"
---

# Si entras en tu cuenta mientras otro teléfono la está activando, la espera no tiene fin si tu cuenta deja de estar disponible

## El problema, en lenguaje de usuario

Entro en mi cuenta de la nube en un segundo teléfono justo cuando el primero la está activando. Yala me dice que espera
a que el otro termine («esperando a otro dispositivo»). Si en ese rato mi sesión se borra o la cuenta contesta que no me
deja entrar, la espera sigue igual para siempre: no hay aviso, ni techo, ni botón para salir.

## Por qué pasa (leído el 2026-09-23 en este árbol; no ejecutado)

`MigrationRunner.pollLeaderInternal` reclama en `waitingForLeader`. Con `.sessionExpired` y `.accountUnavailable` solo
apunta `lastClaimBlocker` y devuelve sin evento; con `.transient`, igual. La fase `waitingForLeader` no está en
`ForwardStepPhase`, así que el techo que `adopt-claim-stays-parked-with-no-ceiling` le puso al claim del adopt no la
cubre, y `ForwardCancelScope` no ofrece «Cancelar» ahí. En Almacenamiento la tarjeta es `waitingCard()`, sin botones.
Mientras el Welcome está delante, su poll sí lo ve (`CloudWelcomeSignInFlow.phase` → `.accountBlocked` / `.error`); al
salir, no.

**Y un «Cancelar» que se pierde** (lente de consumidores de la review, medido): desde el 2026-09-23 el claim del adopt
ofrece «Cancelar la activación». Si la persona lo confirma con el claim en vuelo y el claim contesta `claiming_in_progress`,
la fase pasa a `waitingForLeader`, `journalMigrationCancel` no la ofrece y retira el «sí»: la persona confirmó cancelar y
aterriza en la tarjeta de espera, sin botón.

## Qué habría que decidir

1. ¿Techo para `waitingForLeader`? El seguidor espera a un líder que puede tardar horas con un corpus grande, así que el
   plazo largo no puede ser el de los pasos (72 h sin avanzar podría ser corto o largo según el líder).
2. ¿«Cancelar» ahí, con la salida de la marca `adoptClaimExitRaw` (vuelve a «Activar la nube en este dispositivo»)? Si
   sí, cierra también el «sí» que hoy se pierde.

## Criterios de aceptación

- [x] Un seguidor con la sesión borrada o un 403 persistente no se queda en `waitingForLeader` para siempre.
- [x] Test con el fallo persistente, midiendo que la fase cambia (`MigrationRunnerTests` §16-bis).

## Relacionado

- `adopt-claim-stays-parked-with-no-ceiling` — el mismo hueco en el claim del adopt (22 %), cerrado.
- `adopt-uploads-a-foreign-corpus-without-a-lineage-check` — el otro problema del seguidor.

## Paso 0 (2026-09-23, sesión autónoma)

El árbol entero está en el encargo (`encargos/lanzados/2026-09-23-adopt-follower-waits-for-the-leader-with-no-ceiling.md`,
«## Paso 0 — decisiones»). Jürgen contestó las dos preguntas eligiendo la recomendación:

1. **El techo del 22 %**: 15 min acumulados con la sesión borrada o el 403, 72 h sin noticias del líder con cualquier
   causa. **Cada `claiming_in_progress` es avance** (el líder tiene el lease vivo) y reinicia los dos relojes. La tarjeta
   avisa del 403 o de la sesión borrada en cuanto se ven.
2. **«Cancelar la activación» también en la espera**, con la salida del adopt (marca `adoptClaimExitRaw`, vuelve a
   «Activar la nube en este dispositivo»). Cierra el «sí» que se perdía.

## Lo que se hizo

- `ForwardStepPhase` gana `waitingForLeader` (valor nuevo de los canarios `cloudForwardStepWaiting` y
  `cloudForwardStepAborted`). La máquina le da las dos aristas de los tres pasos (`forwardStepStalled`,
  `forwardStepCancelled`). Mismos campos `forwardStepStall*`: sin schema nuevo.
- `MigrationRunner.pollLeaderInternal`: los tres no-éxitos pasan por `observeForwardStepStall` con la clasificación de
  `driveClaim`; `claiming_in_progress` borra los relojes (`noteLeaderAlive`) y los sella la primera observación que no
  avanza. Un «sí» apuntado se honra antes de volver a reclamar, tras un `claiming_in_progress` y antes de traducir un
  `created`.
- `AdoptClaimScope.isAdoptClaim` y `ForwardCancelScope` incluyen la fase: misma marca y mismo aviso.
- Almacenamiento: la tarjeta de espera lleva el aviso y **«Dejar de esperar»**, con su diálogo (seis claves nuevas en los
  16 idiomas; decisión de Jürgen tras la review, abajo).
- Regla: «Y la espera del seguidor también» en `swiftdata-cloudkit.md`.

## Review adversarial (2026-09-23, tres lentes independientes + refutación por hallazgo)

**Arreglado:**

1. **(consumidores + relojes, media) Sellar el reloj al entrar en la espera, y en cada `claiming_in_progress`, echaba al
   seguidor con un solo poll sin red.** El seguidor es quien cierra Yala mientras espera: al volver días después sin
   cobertura, el primer poll salía con «la activación lleva días sin avanzar» aunque su líder hubiera terminado. Ahora la
   buena noticia BORRA los relojes y los sella la primera observación que no avanza, como en los otros tres pasos.
2. **(consumidores, media) «Cancelar la activación» se leía como parar el otro teléfono**, y «Seguir activando la nube» era
   falso en un teléfono que solo espera. Jürgen eligió textos propios: «Dejar de esperar», con su diálogo y su aviso de
   sesión («Deja de esperar y vuelve a entrar…»).
3. **(las tres lentes, baja) Un «sí» con el poll en vuelo que contestaba `created`** tomaba el relevo, escribía el faro y
   cancelaba ya en la identidad, sin marca: Almacenamiento ofrecía «Migrar». Ahora se honra antes de traducir el `created`.
4. **(cancelar, baja) Dos comentarios desactualizados** sobre el alcance de «Cancelar», y la regla decía que al seguidor lo
   acotan los techos del líder: lo acota el lease de 60 min.

**Aceptado, con su porqué:**

- **El tiempo con Yala cerrada cuenta una vez sellado el reloj** (D16 y la decisión del 2026-09-22 para los pasos): igual
  que en el 22 %.
- **Un «sí» dado con el efecto del adopt ya en marcha se retira sin avisar**: residual escrito del efecto del adopt.
- **Cancelar desde la espera no cierra la sesión que abrió el adopt**: residual escrito (`adopt-exit-keeps-the-session-it-opened`).
- **Un reloj atrasado al sellar**: la familia de `reverse-upload-ceiling-trusts-a-clock-set-back-during-the-wait`.

**Con ticket propio:**

- `forward-step-ceiling-wins-over-a-cancel-given-in-the-same-pass` (low) — preexistente en los cuatro pasos.
- `waiting-card-disables-stop-waiting-without-saying-why` (low).
- `follower-waits-forever-on-a-lease-with-a-null-heartbeat` (very-low, inferido).
- Un `cancelMigration()` descartado por reentrada lo recoge `storage-actions-release-the-working-flag-under-a-running-resume`.

## QA en dispositivo

No se monta a voluntad: pide dos iPhone con la misma cuenta y un líder parado a media activación, y los techos (15 min de
403 o sesión borrada, 72 h) no se provocan a mano. Lo fijan `MigrationRunnerTests` §16-bis, `MigrationStateMachineTests`
y `ForwardStepCeilingLogicTests`.
