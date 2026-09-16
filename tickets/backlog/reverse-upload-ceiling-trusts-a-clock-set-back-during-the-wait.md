---
id: reverse-upload-ceiling-trusts-a-clock-set-back-during-the-wait
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-16
source: "segunda pasada de review de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), lente de código — H2; caso raro, ticket aparte por D17"
---

# Si pongo la fecha atrás durante la vuelta a iCloud, al corregirla la vuelta puede cancelarse sola

## El problema, en lenguaje de usuario

Estoy esperando a que mis datos suban a iCloud. Pongo la fecha del iPhone unos días atrás y luego vuelvo a la hora
automática. Yala cancela la vuelta y me dice que iCloud no recibió todos mis datos, aunque la subida iba bien.

## Por qué pasa

La espera mide el tiempo desde el último avance (`reverseUploadProgressAt`). Un sello en el FUTURO se re-sella con
la hora de la observación (`MigrationRunner.observeReverseUploadWait`, `MigrationRunner.swift:942-947`): así se
arregló que un reloj adelantado al sellar aplazara el techo tanto como fuera adelantado.

Pero un sello futuro aparece también cuando el reloj equivocado es el de AHORA:

1. La espera va con el sello `T`, correcto, y la cifra no baja entre dos lotes del espejo.
2. La persona pone la fecha tres días atrás y vuelve a Yala. Como `T > ahora`, se re-sella con la hora atrasada y
   se guarda en el journal.
3. Vuelve a la hora automática. La primera observación sin bajada mide 72 h o más (`:949`) y sale por el techo
   largo con la nota `stalled`.

Es un intercambio, no un descuido: sin el re-sellado este caso medía bien y el del reloj adelantado aplazaba el
techo. Los dos exigen mover la fecha más que el techo (15 min con iCloud lleno o sin cuenta útil, 72 h si no).

**La misma trampa tiene una segunda cara, en la causa.** `ReverseUploadBlockerLogic` solo cree un error de CloudKit si
`lastExportErrorAt` es posterior a `lastSuccessfulExportDate` (`ICloudCutoverGateLogic.swift:189-193`). Las dos fechas
son del mismo reloj, pero si se atrasa entre el error y un éxito posterior, el éxito queda «antes» del error: la espera
se acorta a 15 min y la pantalla dice «iCloud no tiene espacio» con la subida en marcha. Es la dirección que acorta, al
revés que el resto del diseño. `systemClockDidChange` (`iCloudSyncService.swift:262`) invalida el ancla del export, no
esta fecha.

## Lo que hay que decidir

- Si se distingue el cambio de reloj con `NSSystemClockDidChange` (ya lo escucha `iCloudSyncService.swift:262`
  para su ancla): re-sellar en la observación siguiente a cualquier cambio. No está medido si la notificación llega
  con la app suspendida, y con la app cerrada no llega.
- O si se acepta y se documenta junto a D16.

## Criterios de aceptación

- [ ] Decidido y escrito en la regla de `reverseUpload` (`.claude/rules/swiftdata-cloudkit.md`).
- [ ] Si se arregla: un test con el reloj atrasado y corregido que NO sale, y el del sello adelantado que sigue sin
      aplazar el techo.

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` (D16, D17).
