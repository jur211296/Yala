---
id: transfer-subcategory-is-looked-up-in-the-current-language
status: backlog
priority: low
area: "transactions, categories, l10n"
created: 2026-10-29
updated: 2026-10-29
source: "review adversarial de S27l (import-transferencias-rollback), hallazgo fuera de alcance"
---

# Al cambiar de idioma, una transferencia nueva crea otra subcategoría de transferencia

**Bug preexistente.** Lo encontró la review de la sesión S27l y no se tocó: el encargo era del import.

## Qué ve el usuario

Si cambia el idioma de Yala y crea una transferencia, aparece una segunda subcategoría de transferencia con el nombre del idioma nuevo. Las transferencias quedan repartidas entre dos subcategorías.

## Evidencia (medida en `2.2` el 2026-10-29)

`NewTransactionViewModel.ensureTransferCategory` (`:1106-1108`) y `ensureIncomeTransferCategory` (`:1171-1172`) buscan la subcategoría por `name == L10n.Transfer.categoryName`, el texto del idioma ACTUAL. Si no la encuentran, crean otra. En en, de, nl, ja y zh además nunca reutilizan la sembrada (`subcategory.accountTransfer`), porque su texto es otro.

## Propuesta

Buscar con `Subcategory.transferNames` (los 16 idiomas desde S27l) y quedarse con la que exista. El arreglo de fondo es reconocerla por papel y no por nombre: `transfer-and-adjustment-subcategories-need-a-stable-role`.

## Criterio de hecho

- [ ] Con una transferencia creada en español y la app en inglés, una transferencia nueva reutiliza la subcategoría existente.
