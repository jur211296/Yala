---
id: 2026-11-25-paridad-de-ingresos-depende-de-solo-gastos-del-simulador
status: backlog
priority: medium
area: "pruebas, solo-gastos"
created: 2026-11-25
updated: 2026-11-25
source: "encargo 2026-11-25-primeros-pasos-cada-paso-cuenta-bien (hallazgo al correr la suite completa)"
---

# Ocho pruebas de paridad de ingresos caen si el simulador quedó en «Solo gastos»

**Medido el 25-nov en la Mini:** tras correr XCUITest que terminan en «Solo gastos» (el alta por la conversación con
«Solo gastos», `PrimerosPasosTrasElAltaUITests#test_soloGastos…`), el `UserDefaults` de Yala Dev en el simulador se
queda con `expensesOnlyMode = true`. La suite `YalaTests` corre en el mismo contenedor y `SessionState.shared` lo lee al
nacer: ocho pruebas dan «Registros ingreso: 0.0» (`IncomeExpenseScreenParityTests`, `CombinedFiltersScreenParityTests`,
`RecordsSummaryCurrencyParityTests`, `StatisticsRecalculationTests`). Aisladas o con la clave borrada, verdes.

`testing.md` ya pide que una prueba que pase por `RecordsViewModel.applyFilters` fije
`SessionState.shared.isExpensesOnlyMode` (molde: `RecordsSummaryApproximateMarkTests.conPeriodoCompleto`). Estas ocho no
lo fijan.

**Hecha cuando:** esas pruebas fijan y restauran `isExpensesOnlyMode`, o el host de pruebas lo pone en `false` al
arrancar; y salen verdes con `expensesOnlyMode = true` en las preferencias del simulador.
