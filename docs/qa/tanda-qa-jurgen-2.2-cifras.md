# Barrido de QA · cifras que no cuadraban entre pantallas (2.2, 2026-10-23)

Barrido de los cuatro tickets del encargo `2026-10-23-cifras-distintas-mismo-dinero-2-2`, antes de su PR. El alcance
es ese encargo, no la cola entera de `in qa`.

## Resumen

- Revisados: 4. Cerrados en el barrido: 4. Para el iPhone de Jürgen: 0. Para capturas que aprobar: 0.
- Probado en el simulador (iPhone 17 Pro, iOS 27.0, Yala Dev): la cuenta excluida filtrada, con antes y después.
- **Nada bloquea el lanzamiento y no hay tanda que correr con el teléfono.**

## Lo que pasó a done

| id | motivo (caso del barrido) | evidencia |
|---|---|---|
| `records-standalone-amount-discrepancy` | §2.3 evidencia: test de integración contra el código real, con mutantes | `IncomeExpenseScreenParityTests` (Registros, hero, Flujo de caja, Tendencias, widgets e Informe × Este mes, Últimos 7 días, Este año; Informe por dimensión; filtros; neto; marca «≈»; porcentajes; hero vacío). 10 mutantes muertos por su caso. |
| `panel-budget-spent-diverges-from-planning` | §2.3 | `PanelBudgetPlanningParityTests`: el Panel y Planificación dan 240 con un fixture donde el cálculo viejo daba 1.000 (mutante muerto). |
| `saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas` | §2.4 probado en el simulador + §2.3 | Simulador: con «Cuenta Principal» excluida y filtrada, antes «Tienes ≈ S/ 8,996.28 en tus cuentas» y la tarjeta de tipo de cambio de otra cuenta; después «Tienes S/ 0.00» y sin tarjeta (`/Users/jur/Claude/worktrees/_capturas/2026-10-23-cifras-distintas-mismo-dinero-2-2/antes.png` y `despues.png`). Tests: `ExcludedAccountSelectionTests` (las tres piezas a 0; borrar la cuenta filtrada la quita del filtro), 2 mutantes muertos. |
| `widget-balance-figure-and-curve-count-different-rows-for-accountless-movements` | §2.3 | `WidgetBalanceAccountlessParityTests` (cifra = saldo vivo = último punto de la curva; período cerrado; filtro de los widgets), 2 mutantes muertos. El widget de la pantalla de inicio solo relee lo que calcula la app: no hace falta el teléfono. |

## Lo que se queda

Nada.
