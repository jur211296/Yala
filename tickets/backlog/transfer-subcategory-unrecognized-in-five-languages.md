---
id: transfer-subcategory-unrecognized-in-five-languages
status: backlog
priority: high
area: "import, categories, l10n"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H2 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# La subcategoría de transferencias no se reconoce en japonés, neerlandés, polaco, chino y portugués

**Versión propuesta: 2.2.** Cifra financiera equivocada en silencio en cinco idiomas que Yala ya publica: alta. Arreglo barato (listas + test). La decide Jürgen. Card: `ynsq`.

## Qué ve el usuario

Con Yala en esos idiomas, importar un archivo con transferencias las suma a gastos e ingresos. Con los datos sembrados en español y el teléfono en inglés, un «Ajustes de saldo» importado se marca como transferencia.

## Evidencia

El import decide transferencia por `isAnySystem` (`TransactionCSVImportService.swift:220-228`, y `:1153`, `:1540`, `:1709`), que lee `Subcategory.transferNames` (`Subcategory.swift:115-123`). Faltan `transfer.categoryName` en pt/pt-BR/pt-PT («Transferência entre contas»), ja, nl, pl, zh-Hans, y el nombre sembrado `subcategory.accountTransfer` («Account transfer», «Kontoüberweisung»…); ninguna de esas subcategorías lleva `isSystem` (`NewTransactionViewModel.swift:1157`, `CategorySeed.swift:343-360`). El ajuste se compara con el texto del idioma actual (`:222`).

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H2.

## Propuesta

Completar `transferNames` y `balanceAdjustmentNames` con los nombres de los 16 `.lproj` y decidir el ajuste con `balanceAdjustmentNames`, no con el texto actual. Test de paridad que recorra los `.lproj` y falle si falta un nombre. Marcar esas subcategorías con un papel estable es el arreglo de fondo y toca esquema: va aparte.

## Criterio de hecho

- [ ] Un import con «口座間振替», «Transferência entre contas» o «Account transfer» crea movimientos de tipo transferencia.
- [ ] «Ajustes de saldo» importado con el teléfono en inglés queda como ajuste.
- [ ] Test de paridad sobre los `.lproj` en verde.
