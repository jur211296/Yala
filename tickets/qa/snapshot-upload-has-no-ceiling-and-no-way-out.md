---
id: snapshot-upload-has-no-ceiling-and-no-way-out
status: qa
priority: very-high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-23
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

## Paso 0 (2026-09-22, sesión de día — decisiones de Jürgen por AskUserQuestion)

### Lo medido antes de decidir

- **Dos premisas del ticket, corregidas.** (1) Sí hay un botón: la tarjeta de progreso de la ida enseña «Retomar»
  (`storage_resume_button`), que relanza la misma pasada y choca con lo mismo; lo que no hay es «Cancelar» ni
  «Reintentar». (2) «El motor de la nube no corre» no le quita nada a esta persona: sigue en `.icloud`, su iCloud
  funciona igual. Lo que sí se para mientras la fase dure es el refresco de widgets en segundo plano
  (`BGTaskMigrationGate`, rol `.reader` → `suspendAndReschedule` en toda fase transitoria) y, sin quiescencia, los
  BGTasks de informes.
- **`.rollback` no toca el backend** (`MigrationWorkExecutor.execute(.rollback)`: borra `relaunchRequestedKey` y deja
  rastro). Lo ya subido se queda en la cuenta, igual que hoy cuando `verifying` agota sus reintentos; el siguiente
  intento lo re-sube y converge por LWW (re-claim del mismo dispositivo → `created`). No hay RPC de abort de la ida.
- **Causas que el snapshot ve hoy, todas colapsadas en `.transient`**: el push devuelve `.sessionExpired` (SDK borró la
  sesión, o 401 que no es de attest), `.accountUnavailable` (403) o `.transient` (red, 5xx, `yala_attest_required`); el
  `fetch` del outbox lanza (desde el 22-sep); `enqueueSnapshotRows` lanza por un `fetch`/`save` local o por deriva del
  HLC (`ClockDriftError`/`CanonicalTimeError`); tras un push `.completed` quedan filas vivas.
- **Avanzar es medible**: `.pageConfirmed(cursor)` journalea el cursor. Un corpus grande que sube despacio confirma
  páginas; uno clavado no.
- **Cadencia del productor**: boot + cada foreground + re-kick de 30 s con Almacenamiento delante
  (`StorageSettingsView`, `tick % 30`). 900 s / 30 s = 30 observaciones: con racha consecutiva un timeout intercalado
  la reiniciaría (lección de #210) ⇒ acumulado con pausa.
- **El mismo agujero en otros tres pasos de la ida** (fuera de este PR, ticket propio): `claimingMigration` (corta sin
  evento en `.transient`/`sessionExpired`/`accountUnavailable`), `assigningIdentity` (el `throw` corta sin evento) y
  `cutover(.pending)` (`confirmCutoverServer() == false` corta sin evento). `cutover(.serverConfirmed)` es otro problema:
  ahí ya no hay rollback posible. Ticket: `forward-migration-steps-have-no-ceiling-and-no-exit`.
- **Hallazgo aparte**: el paginador de cada tabla (`MigrationSnapshotUploader.makeSpec`) lee un `fetch` que lanza como
  tabla VACÍA y la salta. Hoy termina en `failedRollback` por el Merkle (que desde el 22-sep lanza), así que no es
  pérdida silenciosa, pero es el mismo patrón `fetch → []`. **Ya tenía ticket**
  (`an-incomplete-inventory-reads-as-the-whole-corpus`, fila `makeSpec`): no se duplica, se le añade una nota.

### Decisiones de Jürgen

1. **Techo: 15 min / 72 h, como la vuelta.** 15 min ACUMULADOS bajo una causa que esperar no arregla (sesión caducada,
   cuenta suspendida, fallo local); 72 h SIN subir una sola página con cualquier causa. Cada página confirmada reinicia
   los dos relojes.
2. **Texto por motivo** en la tarjeta de fallo (no el genérico).
3. **«Cancelar» con confirmación** durante la subida: vuelve a «Migrar a la nube» sin aviso de fallo.
4. **Alcance: solo la subida**; los otros tres pasos, ticket propio.

### Lo técnico, decidido por mí con lo medido

- **Dos relojes, molde de #210** (`reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`): el de AVANCE
  (último `pageConfirmed`, o primera observación) gobierna las 72 h; el de CAUSA (acumulado con pausa: causa distinta
  empieza de cero, misma causa suma, observación sin causa PAUSA) gobierna los 15 min. La lógica del acumulado se
  EXTRAE a un helper puro que usan las dos etapas, en vez de copiarla: es la parte sutil, y dos copias divergen.
- **Un avance borra también el reloj de causa**: una página confirmada prueba que la sesión, la cuenta y la lectura
  local funcionaron.
- **La sesión caducada es DEFINITIVA aquí** (en la vuelta va al largo): la ida no tiene botón de «Iniciar sesión» en la
  tarjeta, y la salida (fallo → «Reintentar») es justo la que vuelve a pedir la sesión.
- **La deriva del HLC va al LARGO**, no a «fallo local»: el reloj puede corregirse solo, y el texto de fallo local no
  sería verdad para ella.
- **Salida del techo**: `failedRollback` con `[.rollback]`, la misma de `verifying` y de `fatalError`. **El motivo lo
  elige el techo que VENCIÓ**, no la última observación (lección 1-bis de #210): las 72 h salen con «dejó de avanzar»
  aunque la pasada traiga un 403 recién visto.
- **Cancelar**: `notStarted` sin efectos, molde de `consentDeclined`/`claimRefusedExistingAccount`. Deja la sesión de
  la nube puesta, que es el mismo estado al que ya llega hoy «Reintentar» tras un fallo, así que no crea uno nuevo.
- **El botón solo se puede tocar con la subida APARCADA**: con una pasada en vuelo `isWorking` lo deshabilita, que es
  la «subida parada» de la pregunta.
- **Journal**: `MigrationState` schema 8 → 9, cinco campos aditivos (cuatro del techo + el motivo de la salida, que
  sobrevive a `failedRollback` como `cutoverICloudVerdictRaw` y se limpia en `notStarted`). Los cuatro del techo se
  limpian juntos (`clearSnapshotCeiling()`) al ENTRAR y al SALIR de la fase —la vuelta desde `verifying` por mismatch
  empieza sin reloj— y en el reset, la normalización y los cierres.
- **Canarios**: uno por observación (`canaryOnce`, molde de `cloudReversePreMountWaiting`, con los dos tramos) y uno
  en la salida.

## QA en dispositivo (lo que un teléfono SÍ puede comprobar)

Los techos (15 min de un motivo definitivo, 72 h sin avanzar) y los cuatro textos de fallo no se pueden montar a
mano: exigen una cuenta suspendida, una base local que no se deja leer o tres días de espera. Los fijan los tests
unitarios (`MigrationRunnerTests` §14, `SnapshotUploadCeilingLogicTests`: qué clave elige cada motivo, que las cuatro
frases son distintas y que ninguna sale como clave cruda). Lo que sí se
comprueba en el teléfono es la cancelación y que nada se rompe:

**Montaje**
1. Build de **Yala Dev** (va a staging) en un iPhone con un corpus grande: varios miles de movimientos, para que la
   subida tarde lo bastante. Tu cuenta de staging, sin migrar.
2. Ajustes → Almacenamiento → «Migrar a la nube» → consentimiento → iniciar sesión.

**Guion**
3. En cuanto la barra llegue a **55 %** («Activando la nube…»), activa el **modo avión**.
   Esperado: la barra se queda en 55 % y, cuando el intento se aparca (unos segundos), aparece
   **«Cancelar la activación»** debajo de «Retomar».
4. Toca «Cancelar la activación» → en el diálogo, **«Seguir activando la nube»**.
   Esperado: no cambia nada, la barra sigue en 55 %.
5. Toca «Cancelar la activación» → **«Sí, cancelar»**.
   Esperado: la tarjeta vuelve a «Migrar a la nube», **sin** alerta de error ni tarjeta de «No pudimos activar la nube».
6. Quita el modo avión y vuelve a «Migrar a la nube» hasta el final.
   Esperado: la migración termina normal (el segundo intento re-sube lo que el primero dejó a medias).
7. Control de que la subida sana no ofrece cancelar a destiempo: en otro intento, con red, mira la barra en 55 %.
   Esperado: el botón aparece deshabilitado mientras sube y la migración sigue sola.

## Review adversarial (2026-09-22, tres lentes independientes + refutación por hallazgo)

**Arreglado:**

1. **(las tres lentes, por separado) El 401 con la sesión todavía guardada se trataba como sesión caducada
   definitiva.** Su caso principal es el reloj del teléfono atrasado: sacaba de la subida a los 15 min, y
   «Reintentar» → «Migrar» reusaba el mismo JWT rechazado sin pedir nada. Ahora solo es definitivo con la sesión
   BORRADA por el SDK (`canRenewSession` leído después del push); con la sesión guardada va al plazo largo, que el
   SDK cura al renovar o convierte en definitivo al descubrir la revocación.
2. **Un «Sí, cancelar» podía perderse** si un re-kick arrancaba con el diálogo abierto y la red de vuelta: la pasada
   subía todo y seguía hasta el cutover. Ahora el «sí» se apunta en el runner antes de esperar, y la pasada lo ve
   antes de la página siguiente.
3. **Cancelar dejaba abierta la sesión que abrió el intento**, que `GroupsAssociationRegistrar` registraría como
   cuenta de grupos en el siguiente arranque. Ahora se cierra, molde de la parada del claim.
4. **(dos lentes) El texto del techo largo acusaba a la red** («cuando tengas buena conexión»), y las 72 h las alcanza
   cualquier causa. Ahora es neutro.
5. Frases que el cambio dejó falsas en `swiftdata-cloudkit.md` y en `CloudMigrationController`, y un docblock del
   runner que llamaba «racha» al acumulado.
6. Tests que no podían fallar: la comparación L10n contra L10n no veía una clave sin traducir (ahora se mira la clave
   cruda); la rama del fallo local al encolar no tenía test (seam + test); el guard de fase de `cancelSnapshotUpload`
   era inalcanzable (retirado).
7. `qa/coverage-index.json`: la nota del ticket anterior vivía dentro de `lastVerified` y se perdió al reescribirlo;
   restaurada en `coverage`.

**Aceptado, con su porqué:**

- **El tiempo con la app cerrada cuenta** para las 72 h: es lo que dice «72 h sin subir una sola página», y es el mismo
  trato que la espera de la vuelta (D16 de `reverse-upload-has-no-ceiling-and-no-exit`). Tras tres días sin abrir la
  app, un primer intento fallido sale en ese intento.
- **Un teléfono sin App Attest que llegue a migrar** espera las 72 h (el 401 `yala_attest_required` es pasajero) y sale
  con el texto neutro. La puerta de Ajustes ya no le ofrece migrar (`offersCloudMigrationEntry`).
- **El botón se deshabilita con un intento en vuelo**, como el de la vuelta: con una red que no contesta, cada intento
  tarda hasta 60 s y el botón solo se toca entre intentos.

**Con ticket propio:** `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved` (inferido por una lente, no medido).

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con el guion del bloque D (modo avión al 55 % y «Cancelar la activación»).
