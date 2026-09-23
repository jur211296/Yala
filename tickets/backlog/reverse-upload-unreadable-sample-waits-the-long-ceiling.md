---
id: reverse-upload-unreadable-sample-waits-the-long-ceiling
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-23
updated: 2026-09-23
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

## Qué hay que decidir (es de producto)

1. ¿La espera de `reverseUpload` corta con el techo CORTO ante una muestra ilegible, como la ida?
2. ¿Qué dice la pantalla mientras tanto y al salir? Hoy «subiendo» no es verdad para este caso.

## Criterios de aceptación

- [ ] Decisión de Jürgen sobre plazo y texto.
- [ ] Una muestra ilegible elige ese plazo y ese texto, con test y control positivo.

## Relacionado

- `an-incomplete-inventory-reads-as-the-whole-corpus`.
- `reverse-upload-has-no-ceiling-and-no-exit` — el techo de esta espera.
