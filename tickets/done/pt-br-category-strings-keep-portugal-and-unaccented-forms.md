---
id: pt-br-category-strings-keep-portugal-and-unaccented-forms
status: done
priority: low
area: l10n
created: 2026-10-16
updated: 2026-10-25
source: barrido del pt-BR del encargo 2026-10-16-capturas-video-app-store-en-pt · card `tablero-los-textos-de-categorias-en-pt-br-siguen-yg5z`
---

# Los textos de categorías en pt-BR siguen con «Eliminar» y sin acentos

El 16-oct se corrigió el pt-BR de la app (588 cadenas: acentos y formas de Portugal). Se dejaron fuera, a propósito,
las claves `category.*` y `subcategory.*`, porque algunas son **nombres que se guardan** en la base de datos del
usuario (las categorías sembradas, y `subcategory.unassigned`, que se busca por nombre) y cambiarlas duplicaría
categorías a quien ya las tiene.

Pero esos dos prefijos mezclan nombres guardados con **textos de interfaz** que tienen los mismos fallos, unos 25:
«Eliminar categoria», «Nao e possivel eliminar», «Esta acao nao pode ser desfeita», «Transferir transacoes»…

## Qué hay que hacer

1. Separar, clave a clave, las que se guardan por nombre (no se tocan sin migración) de las que solo se pintan.
2. Corregir las de interfaz. Propuesta lista en el informe del barrido: `category.delete` → «Excluir categoria»,
   `category.cannotDeleteTitle` → «Não é possível excluir», `subcategory.deleteConfirmMessage` → «Esta ação não pode
   ser desfeita.», `subcategory.transferTitle` → «Transferir transações», etc.
3. `subcategory.unassigned` («Nao atribuido») solo con migración del nombre guardado.

## Y cuatro desajustes de contenido que salieron en el mismo barrido (pt-BR, puede que no solo)

- `tutorials.createBudgets.step1.desc` nombra un período «diário» que los presupuestos no tienen.
- `panel.widgetInfo.periodComparison.howA` habla de los botones «M/A», que en la app son «P-1/A-1».
- `tutorials.editPanel.step2.desc` cita «Restabelecer»; el botón se llama «Restaurar layout original».
- `groups.accountIsComplete.settingsHint` cita «Onde seus dados moram»; la pantalla es «Onde ficam seus dados».

Y una decisión de producto pendiente: las rutas de ayuda dicen «Ajustes > …» y la pantalla se llama «Configurações».

## Resuelto (lote 12.4, 2026-10-25)

- Las de interfaz de `category.*`/`subcategory.*` corregidas por la revisión de Sonnet («Excluir categoria», «Não é possível excluir», «Esta ação não pode ser desfeita.»…); pt-BR queda sin formas sin acento en todo el catálogo.
- `subcategory.unassigned` pasa a «Não atribuído» SIN migración: la búsqueda por nombre (`SubcategoryTransferViewModel.getOrCreateUnassignedSubcategory`) acepta también el nombre viejo (`legacyUnassignedNames`), así que quien ya la tenía no recibe una segunda. Lo mismo en fr («Non attribué»).
- Los cuatro desajustes de contenido eran de los 16 idiomas, no solo pt-BR, y se corrigieron en todos con el nombre real de cada uno: los presupuestos no tienen período diario (semanal, mensual, anual, único), los botones de comparar se llaman «P-1» y «A-1» (período anterior / mismo período del año anterior), el botón del Panel es «Restaurar layout original» (y su equivalente) y la pantalla es la de `storage.title`.
- La decisión pendiente («Ajustes > …» frente a «Configurações») sigue abierta y NO se tocó: la propia app llama a la pantalla de las dos formas (`profile.title` = «Ajustes», `settings.title` = «Configurações») y 70 textos dicen «Ajustes», varios de ellos sobre los Ajustes del iPhone, que en iOS brasileño se llaman así. La revisión proponía cambiar 4 rutas sueltas y se revirtieron para no mezclar más. Va al ticket `l10n-terminology-follows-the-tab-names`.
- Lo fijan `TranslationLot124GuardTests.brazilianPortuguese_*`, `helpTexts_nameTheRealButtonsAndScreens` y `unassigned_keepsFindingTheOldName`.
