---
id: discard-prior-icloud-confirmation-has-no-visible-cancel
status: done
priority: medium
area: "modo-nube, ajustes"
created: 2026-10-19
updated: 2026-10-25
source: "review adversarial del lote decidido 2.2 · 05 (lente de avisos que borran), medido en el simulador el 2026-10-19"
---

# «¿Borrarlos de tu iCloud?» no enseña ninguna salida: solo «Borrar y volver a iCloud»

## El problema, en lenguaje de usuario

Al volver a iCloud con datos de Yala de antes en el iCloud del teléfono, «Empezar sin ellos» pregunta «¿Borrarlos de
tu iCloud?». Ese globo solo enseña «Borrar y volver a iCloud», que borra de iCloud sin vuelta. Para no borrar hay que
saber tocar fuera.

## Medido (2026-10-19, iPhone 17 Pro, iOS 27.0)

`-uitest-seed minimal -uitest-born-cloud-storage -uitest-reverse-prior-icloud found` → «Volver a iCloud» → «Empezar sin
ellos»: el árbol trae `storage_revert_prior_discard_confirm` y ningún «Cancelar». Captura:
`~/Claude/entregas/Yala--lote-decidido-2-2-05-nube-e-icloud/capturas/borrarlos-de-tu-icloud-sin-cancelar.png`.

## Por qué pasa

`StorageRevertPriorDataDialogs` (StorageSettingsView): su «Cancelar» lleva `role: .cancel`, y en iOS 26 un
`.confirmationDialog` en globo no pinta ese rol (regla B6 de `.claude/rules/swiftui-ds.md`, medida en esta misma pantalla).
El diálogo de datos previos arrastra además un `Button(L10n.Common.cancel, role: .cancel)` redundante junto a «Ahora no».

## Qué hacer

Dar al «Cancelar» de la confirmación un botón sin rol (el molde de los de esta pantalla) y un XCUITest que lo toque y
afirme que no se borró nada; quitar el `.cancel` redundante del diálogo de datos previos.

## Criterios de aceptación

- La confirmación enseña «Cancelar» y tocarlo no empieza la vuelta ni borra (XCUITest con el seam `found`).

## Cierre (lote 12.2, 2026-10-25)

«Cancelar» de «¿Borrarlos de tu iCloud?» es un botón sin rol con su id (`storage_revert_prior_discard_cancel`), como «Ahora
no»; el `.cancel` redundante del diálogo previo se quitó. XCUITest
`ReverseICloudPriorDataUITests#test_discardConfirmation_showsCancel_andCancelDeletesNothing`: tocarlo cierra la confirmación,
no pinta el paso «borrando» y la tarjeta «Volver a iCloud» sigue. Card cchh.
