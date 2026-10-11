---
id: reverse-upload-unreadable-sample-waits-the-long-ceiling
status: qa
priority: low
area: "modo-nube, migración"
created: 2026-09-23
updated: 2026-10-06
qa-status: needs-testing
source: "decisión aparcada de `an-incomplete-inventory-reads-as-the-whole-corpus` (2026-09-23, cola nocturna)"
---

# Si la vuelta a iCloud no puede leer tus tablas, espera el plazo largo antes de rendirse

## El problema, en lenguaje de usuario

Pulso «Volver a iCloud» y la app se queda esperando a que mis datos lleguen a iCloud. Si la avería es que el teléfono
no consigue leer una de mis tablas, la espera no lo sabe decir: me enseña el mensaje de «subiendo» y tarda lo mismo que
si iCloud fuera lento, hasta el plazo largo, antes de volver al modo nube. Mis datos no corren peligro —siguen en la
nube de Yala—, pero espero días por algo que esperar no arregla.

## Por qué pasa

Desde `an-incomplete-inventory-reads-as-the-whole-corpus` una muestra que no pudo leer una tabla es
`ReverseUploadStatus.unreadable`: no cierra la vuelta y no cuenta como avance, que era el bug. Pero la espera de
`reverseUpload` elige su presupuesto con `ReverseUploadBlocker`, que solo conoce las señales del canal iCloud, y no
tiene un motivo «avería de este dispositivo». Sin motivo, cae en el plazo largo con el texto de «subiendo»; y si CloudKit
tiene un error vigente, al revés: corta a los 15 min culpando a iCloud de una avería que es de este teléfono.

La ida ya tiene ese motivo (`SnapshotStallBlocker.localFailure`, techo corto, «este dispositivo no pudo preparar tus
datos») y la fase previa al montaje de la vuelta también (`ReversePreMountBlocker.localFailure`).

**Desde el 2026-09-26 cubre también la captura que no pudo mirar ninguna fila** (`reverse-upload-sample-reads-unreadable-rows-as-drained`):
el SQLite del espejo que no abre o no tiene sus tablas ya no cierra la vuelta, sale `.unreadable` y espera aquí. Si el espejo
sin cuenta de iCloud no crea esas tablas (sin medir), ese teléfono cae aquí y además da `icloudOff` o `unknown`: esos
motivos PAUSAN el reloj corto, así que esperaría las 72 h con el texto de «subiendo». El canario `cloudReverseUploadSampleUnreadable` dice
cuántos teléfonos caen aquí.

**Y la pantalla pierde el motivo si la espera empieza ilegible** (review del 2026-09-26, medido en el código):
`MigrationRunner.observeReverseUploadWait` solo guarda `lastReverseUploadSample` con una cifra buena. Sin ninguna
previa, el motivo que ya se conoce (`icloudOff`) se tira y la tarjeta dice «Subiendo tus datos a iCloud», sin el aviso
de «Si iCloud no está activo…». El test `reverseUploadCeiling_unreadableFirstObservation_sealsClockButNoLowest` fija eso
a propósito. Un arreglo posible: una muestra con la cifra opcional que conserve el motivo.

## Qué hay que decidir (es de producto)

1. ¿La espera de `reverseUpload` corta con el techo CORTO ante una muestra ilegible, como la ida?
2. ¿Qué dice la pantalla mientras tanto y al salir? Hoy «subiendo» no es verdad para este caso.

## Decisión (Jürgen, 2026-10-04): A

Techo corto, igual que la ida, y un texto que no diga «subiendo» cuando la muestra no se puede leer.

## Criterios de aceptación

- [x] Decisión de Jürgen sobre plazo y texto.
- [x] Una muestra ilegible elige ese plazo y ese texto, con test y control positivo.
- [x] La espera que EMPIEZA ilegible conserva el motivo en pantalla (el test que fijaba lo contrario se ajustó).
- [ ] Device-QA del control: una vuelta normal sigue diciendo «Subiendo» y termina (guion abajo).

## Qué cambió (2026-10-06)

- **Motivo nuevo de la espera, `ReverseUploadBlocker.localFailure`**, el análogo de `SnapshotStallBlocker.localFailure` de la
  ida. Lo elige el runner con la muestra `.unreadable`, sin preguntar al canal iCloud: manda sobre `icloudOff`, `unknown`,
  `icloudFull` e `icloudUnusable`. Es `.definitive`: entra en el reloj de «cualquier motivo definitivo» y sale a los 900 s,
  el mismo número que la ida. Turnándose con un motivo de iCloud sale con `stalled`, como cualquier mezcla.
- **Salida con motivo propio, `ReverseAbortReason.localFailure`** (wire `localFailure`): «No pudimos terminar de volver a
  iCloud: este dispositivo no pudo preparar tus datos para subirlos. Sigues en la nube; vuelve a intentarlo en un rato.»
  Sin correo de soporte, como la ida.
- **La tarjeta mientras espera** dice «Este dispositivo no pudo preparar tus datos para subirlos a iCloud. Si no se
  resuelve en unos minutos, seguirás en la nube y podrás volver a intentarlo.» Nunca «subiendo». 16 idiomas.
- **`ReverseUploadSample.pending` es opcional**: la espera que empieza ilegible guarda muestra (sin cifra, con motivo).
  Con una cifra buena previa la conserva, como hasta hoy.
- Lo que la persona escribe con la muestra legible y lenta no cambia: plazo largo y «Subiendo».

Tests: `MigrationRunnerTests` §13-ter (`reverseUploadUnreadable_*`, con el control legible en el mismo bucle) y el caso de la
primera observación ilegible (`…_keepsTheReason`), y `reverseUploadClocks_anUnreadableSample_stillAccruesItsDefinitiveCause`,
que fijaba la salida con «iCloud lleno» y ahora sale con `localFailure`; `ReverseUploadCeilingLogicTests` (motivo, texto,
nota y el mapeo entero de la vista, `viewMapping_eachMessageGoesToItsOwnText`). Regla de área: punto 4 de «La
espera de `reverseUpload`…» en `.claude/rules/swiftdata-cloudkit.md`.

## Residuales (anotados en sus tickets)

- **Sin cuenta de iCloud, sin medir**: si el espejo no crea sus tablas, ese teléfono sale a los 15 min culpándose a sí
  mismo en vez de oír «Si iCloud no está activo…». Nota en [[reverse-offered-on-a-device-without-icloud]].
- **Una pasada ilegible suelta + la app cerrada** cobra el hueco contra el techo corto, como ya pasaba con `icloudFull`.
  Nota en [[stall-clock-charges-a-closed-app-gap-to-a-one-off-cause]].
- Un build anterior que lea el motivo `localFailure` en el journal no enseña nota (solo con un downgrade).

## Guion de QA en iPhone (opcional; no bloquea)

**El caso del ticket no se puede provocar a mano**: hace falta que el teléfono no pueda leer su propia base de datos.
Lo cubren los tests. Lo que sí se prueba en el iPhone es el control: que una vuelta normal no ha cambiado.

Hace falta Yala Dev compilado desde `2.1` (con este cambio), en modo nube, con iCloud activo y conexión.

1. Ve a Perfil → Ajustes → «Dónde viven tus datos» → «Volver a iCloud» y confirma.
2. **Comprueba:** mientras sube, la tarjeta dice «Subiendo tus datos a iCloud. Puedes seguir usando Yala.» y, cuando
   aparece, la cifra de pendientes. **No** dice «Este dispositivo no pudo preparar tus datos».
3. Espera a que termine: la tarjeta dice «Ya casi está — reinicia Yala». Ciérrala del todo y ábrela: estás en iCloud
   con tus datos.

En la flota: el canario `cloudReverseUploadSampleUnreadable` dice cuántos teléfonos caen en este caso, y desde este
cambio `cloudReverseUploadAborted` con detalle `localFailure` dice cuántos salen por él.

## Relacionado

- `an-incomplete-inventory-reads-as-the-whole-corpus`.
- `reverse-upload-has-no-ceiling-and-no-exit` — el techo de esta espera.
