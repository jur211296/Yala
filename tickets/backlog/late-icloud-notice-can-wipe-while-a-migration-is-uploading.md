---
id: late-icloud-notice-can-wipe-while-a-migration-is-uploading
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-10-08
updated: 2026-10-08
source: "review adversarial de `late-icloud-wipe-stays-frozen-after-a-settled-failed-migration` (2026-10-08), lente de estado durable — punto 4"
---

# El aviso del espejo tardío puede ofrecer «borrar» con una migración a la nube en marcha

## El problema, en lenguaje de usuario

Quien eligió privado sin poder mirar iCloud recibe más tarde un aviso: «encontramos datos viejos en tu iCloud, ¿los
borramos?». Ese aviso puede salir mientras sus datos se están subiendo a la nube, y si elige borrar, el borrado corre a
la vez que la subida.

## Medido (por lectura, 2026-10-08)

- El congelado con la ida en vuelo (`lateWipeLaunch` → `.holdForMigration`) solo existe con un borrado YA pendiente (arm o
  «a medias»). Sin ninguno, `lateWipeLaunch` da `.none` y `runLateICloudMirrorCheck` sigue a `decideLateMirror`, que no
  mira la migración: con el testigo y el espejo puestos, `.ask(corpus)` presenta el aviso y «Borrar» ejecuta
  `performLateICloudWipe`.
- Tampoco lo relee el consumo del intent del router ni el propio borrado: una ida lanzada mientras el router retiene la
  hoja deja el borrado corriendo durante la subida.
- Sin reproducir: la ida no se puede llevar en simulador hasta ese punto con el aviso delante.

## Qué hay que decidir

Probablemente sin decisión de producto: el aviso debería esperar al reposo (o al fallo asentado) igual que el borrado
pendiente. Confirmar antes que el espejo sigue montado durante la subida de la ida (si se desmonta antes, el aviso no sale).

## Relacionado

- `late-icloud-wipe-stays-frozen-after-a-settled-failed-migration`.
- `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`.
