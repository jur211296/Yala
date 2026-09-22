---
id: snapshot-upload-has-no-ceiling-and-no-way-out
status: backlog
priority: very-high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "review adversarial de `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22), lente de consumidores"
---

# La subida de tus datos a la nube se puede quedar al 55 % para siempre, sin aviso y sin botón

## El problema, en lenguaje de usuario

Si al pasar los datos a la nube algo falla de forma persistente —no vuelve la red, o la base del teléfono deja
de leerse—, la barra se queda en **«Migrando…», 55 %**, y ahí se queda. Cierras la app y vuelves: 55 %. Al día
siguiente: 55 %. No hay aviso, no hay «Cancelar», no hay «Reintentar» y el motor de la nube no corre mientras
tanto, porque esa fase no es estable.

## Por qué pasa (medido el 2026-09-22 en este árbol)

`uploadingSnapshot` tiene **exactamente dos** aristas de salida en la máquina
(`MigrationStateMachine.swift:546` `snapshotUploaded` y `:614` `fatalError`, que `driveUpload` nunca emite).
**No tiene techo.** No hay un `snapshotStalled` como el `markerExportStalled` del paso 4 ni como el
`reversePreMountStalled` que cerró `reverse-before-mount-has-no-way-to-abandon-the-return` para las cuatro
fases de la vuelta.

Y `driveUpload` (`MigrationRunner.swift:976`) devuelve `false` ante `.transient`, o sea corta retomable. El
reintento llega por `rekickIfParked` en cada foreground, y vuelve a fallar igual. `resetAfterRollback`
(`:544-547`) solo acepta `failedRollback`/`reverseFailedRollback`, así que **el botón «Reintentar» de la
tarjeta de fallo no alcanza a esta fase**.

**Esto es PREEXISTENTE y su causa vieja es la red**: un `push` que devuelve `.transient` de forma persistente
produce el mismo limbo, y lo produce desde que existe la fase.

## Lo que cambió el 2026-09-22, y por qué se aceptó

`verify-reads-a-failed-local-fetch-as-an-empty-outbox` añadió una causa a ese limbo: un `fetch` de `SyncOutbox`
que lanza persistentemente. **Antes de ese ticket esa avería salía del limbo, pero por la puerta falsa**: el
`catch` devolvía `[]`, la página se daba por **confirmada** y el cursor avanzaba, así que el snapshot llegaba a
`verifying` con filas sin subir → el Merkle divergía → mismatch → tope → `failedRollback`. La persona acababa
en «no se pudo migrar», que es el desenlace correcto, alcanzado mintiendo.

Se aceptó el cambio porque **mejora el caso común y empeora el raro**:

- **Avería transitoria** (lo normal: un `fetch` que falla una vez): antes, la página se confirmaba
  irreversiblemente y **esas filas se perdían para siempre** aunque el fallo durase un segundo. Ahora se
  reintenta y no se pierde nada.
- **Avería permanente**: antes se llegaba al fallo por la vía de dar por subido lo que no subió; ahora se queda
  en el limbo que la red ya tenía.

⇒ el arreglo correcto no es volver al `[]`: es **darle techo a la fase**, que es lo que le falta desde siempre.

## Qué habría que decidir

1. **¿Techo por tiempo journaleado, como las otras dos familias?** El molde existe dos veces
   (`markerExportStalled` con `ICloudCutoverGateLogic`, y los DOS relojes del pre-montaje). La pregunta abierta
   es si aquí hace falta también el reloj por CAUSA o basta el de fase: el snapshot tiene una cifra que baja
   (el cursor), así que «avanzar» es medible y quizá el molde correcto sea el de `reverseUpload`, que mide el
   tiempo SIN AVANZAR.
2. **¿A dónde sale?** `failedRollback` con `.rollback` es lo que hace `verifying`; pero el snapshot ya escribió
   filas en el backend, así que hay que mirar si el rollback las limpia.
3. **¿Se ofrece «Cancelar»?** Las cuatro fases del pre-montaje lo ofrecen desde
   `reverse-before-mount-has-no-way-to-abandon-the-return`. Aquí no hay nada.

## Criterios de aceptación

- [ ] `uploadingSnapshot` tiene un techo y una salida journaleada.
- [ ] Un fallo persistente del push o del `fetch` local no deja la barra al 55 % indefinidamente.
- [ ] La persona ve algo y tiene un gesto disponible.
- [ ] Test de la fase con el fallo persistente, midiendo que la fase CAMBIA.

## Relacionado

- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el que añadió la segunda causa y lo destapó.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el mismo bug-class, ya cerrado en la vuelta.
