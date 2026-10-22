---
id: import-offers-the-groups-system-account
status: done
priority: medium
area: import
created: 2026-10-19
updated: 2026-10-22
source: QA guiado 2026-10-19 (A · C1), card «Importar archivo deja elegir la cuenta interna de Grupos («Grupos PEN»)»
---

# Importar archivo deja elegir la cuenta interna de Grupos («Grupos PEN»)

## Qué pasaba

En Perfil › «Importar archivo», la lista de cuentas incluía «Grupos PEN», la cuenta interna del puente de gastos de
grupo (`isSystemAccount`). Importar a ella mezclaría movimientos personales con los de los grupos. `ImportIntroSheet`
y `ImportCurrencyMappingSheet` solo quitaban las archivadas; el formulario de movimiento, la voz y la foto ya la excluían.

## Cerrado (2026-10-22)

Los dos selectores piden las cuentas a `ImportAccountChoiceLogic.importableAccounts` (ni archivadas ni de sistema).
Tests: `ImportAccountChoiceAndResultTests`.
