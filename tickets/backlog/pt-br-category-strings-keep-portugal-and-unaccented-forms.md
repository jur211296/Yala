---
id: pt-br-category-strings-keep-portugal-and-unaccented-forms
status: backlog
priority: low
area: l10n
created: 2026-10-16
updated: 2026-10-16
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
