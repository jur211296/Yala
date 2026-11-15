---
id: prefilled-amount-fields-keep-the-caret-where-the-tap-lands
status: backlog
priority: medium
area: amounts, forms
created: 2026-11-10
updated: 2026-11-10
source: lote 01 de las mejoras necesarias 2.3 (Grupos)
---

# Los campos de importe que llegan rellenos dejan el cursor donde cae el toque

Encontrado el 2026-11-10 al arreglar el reparto de Grupos (ticket
`group-split-amount-field-keeps-the-old-value-and-drops-typed-digits`), **no medido** en estos campos: tocar a la
izquierda de un importe ya escrito deja el cursor delante; borrar no hace nada y lo que se escribe se mete por delante,
y `AmountInputHelper.filterAmountInput` tira los dígitos que pasan de dos decimales. En el iPhone 14, en el reparto,
«150» sobre «200.00» dejó «1,200.00». Candidatos con el mismo filtro y un importe precargado: «Saldar»
(`SettlementFormView`, llega con el importe sugerido) y, al editar, el saldo inicial (`GroupOpeningBalanceFormView`) y
otros formularios de importe en modo edición.

Cómo verificarlo: en cada uno, tocar a la izquierda del número, borrar y escribir otro. Si se reproduce, el molde es el
del reparto: al entrar en el campo, el cursor va al final (`GroupSplitEditorCard.moveCaretToEnd`).
