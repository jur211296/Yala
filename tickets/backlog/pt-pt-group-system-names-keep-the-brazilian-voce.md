---
id: pt-pt-group-system-names-keep-the-brazilian-voce
status: backlog
priority: very-low
area: l10n, groups
created: 2026-10-25
updated: 2026-10-25
source: lote 12.4 (pasada nativa pt-PT)
---

# pt-PT: dos subcategorías de sistema de Grupos dicen «você»

`subcategory.system.openingBalanceOwed` («Saldo inicial (devem a você)») y `subcategory.system.openingBalanceDebt`
(«Saldo inicial (você deve)») son las dos únicas cadenas de pt-PT que siguen con trato de Brasil. No se tocaron porque
`seedSystemGroupCategoriesIfNeeded` empareja estas subcategorías POR NOMBRE con las que ya existen
(`qa/l10n-review/claves-protegidas.txt`): cambiar el texto sin más crearía una segunda en cada teléfono portugués.

## Qué hacer

El mismo molde que «Sin asignar» en el lote 12.4: que el emparejamiento acepte también el nombre viejo
(`SubcategoryTransferViewModel.legacyUnassignedNames`) y entonces cambiar el texto a «Saldo inicial (devem-te)» /
«Saldo inicial (deves)». Comprobar antes si el nombre viaja al backend de Grupos.
