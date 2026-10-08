---
id: image-entry-uitests-save-stays-off-for-a-complete-record
status: backlog
priority: medium
area: "image"
created: 2026-10-07
updated: 2026-10-08
source: hallazgo del encargo 2026-10-07-ipad-drop-unreadable-file-fails-silently
---

# En `ImageEntryReviewUITests`, «Guardar» sale apagado con un registro completo

## Qué pasa

Tres casos de `YalaUITests/ImageEntryReviewUITests` caen en iPhone 17 Pro (iOS 27.0) porque «Guardar» (`image_save`)
existe pero está apagado con lo leído completo:

- `test_readsWithoutCountdown_andSavesInTheSameSheet` — «Un registro completo se tiene que poder guardar.»
- `test_missingSubcategory_blocksSave_untilChosen` — «Con la subcategoría elegida, el registro se puede guardar.»
- `test_twoPhotos_showOneRowEach_andSaveTogether` — «Dos registros completos se tienen que poder guardar juntos.»

Los otros dos casos de la suite pasan.

## Medido

- 2026-10-07, mismo simulador, mismo resultado con el árbol del encargo y con `origin/2.1` (`beed3a228`) sin cambios:
  preexistente.
- No se averiguó qué condición de `VoiceDraftReadiness` falla. El seam `-uitest-image-result` fecha lo leído como «hoy»
  en `yyyy-MM-dd`; una fecha leída como futura (`isFutureDate`) apagaría «Guardar», y es la primera hipótesis a medir,
  no una causa comprobada. Si es eso, podría pasar también fuera del test.

## Medido en 2.1 (triage 2026-10-08)

- Sin commit de arreglo desde el 07-oct en `ImageEntryReviewUITests.swift`, `ImageSelectionView.swift` ni `UITestHooks.swift`.
- «Guardar» sigue gobernado por `VoiceDraftReadiness` con `isFutureDate: draft.effectiveDate > Date.now` (`ImageSelectionView.swift:472`).
- El seam sigue fechando «hoy» como `yyyy-MM-dd` en `en_US_POSIX` (`ImageSelectionView.swift:1019-1022`). La hipótesis de la fecha futura sigue sin medir.

Triage 2026-10-08: abierto · medium → medium · sin arreglo desde el 07-oct; la causa sigue sin medir y podría ser de producto (`ImageSelectionView.swift:472`, `isFutureDate`).
