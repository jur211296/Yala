---
id: adopt-window-late-imports-overwrite-newer-cloud-edits
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-25
updated: 2026-09-25
source: "review adversarial (lente de tests) de `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`, 2026-09-25"
---

# Lo que el espejo importa tarde tras un adopt sube con un reloj nuevo y puede pisar ediciones más nuevas de la nube

## El problema, en lenguaje de usuario

Mi primer iPhone pasó mis finanzas a la nube hace una semana y desde entonces he corregido algunos movimientos. Activo la
nube en el segundo iPhone del mismo Apple ID. Su iCloud todavía no ha terminado de bajar la copia vieja. Si el adopt termina
antes de que llegue todo, lo que llega después sube con la versión vieja y puede deshacer mis correcciones.

## Lo medido (2026-09-25, en el código) e inferido

- Medido: tras el adopt, el paso 3 (`fastForwardHistoryBaseline`) ancla la línea base; lo que el espejo importe DESPUÉS lo
  traduce el primer drain tras relanzar, porque el drain no filtra por el autor del espejo.
- Medido en la documentación del propio motor (`HistoryTokenFallbackLogic`): re-emitir filas con un HLC fresco pisa por LWW
  escrituras ajenas más nuevas.
- Medido: el drain corre, y el push sube, ANTES del primer pull del runtime (`CloudSyncRuntime.start` → `performCycle`).
- Inferido, sin reproducir: que en la práctica lleguen filas conocidas por el backend después del reconcile. La quiescencia
  del import lo acota; el ticket padre lo acota más en el caso del store vacío (espera al primer import entero tras un
  `found`); queda el adopt que arranca con filas locales y un import a medias (el «import-lag» de siempre).

## Opciones, sin decidir

- En el primer drain tras un adopt, no traducir los inserts del espejo de filas cuya identidad conoce el backend (el pull
  las traerá con su versión).
- O acuñar para esas filas el HLC que tenían y no uno fresco.

## Relación

- Surge de `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`.
- Hermano: `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`.
- Familia: `adopt-orphan-with-a-fresh-hlc-beats-the-absent-leaders-edit`.
