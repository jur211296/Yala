---
id: saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas
status: backlog
priority: medium
area: panel
created: 2026-09-07
updated: 2026-10-08
source: review adversarial de panel-colapsa-la-seleccion-de-cuentas-a-la-primera
---

# Con una cuenta excluida de estadísticas filtrada, el Panel se contradice consigo mismo

## Qué pasa

Cuando el filtro de cuentas **no resuelve a ninguna cuenta contable** —el caso normal es filtrar una
cuenta marcada «excluir de estadísticas»— tres piezas de la misma pantalla dan tres respuestas:

| Pieza | Qué muestra | Por qué |
|---|---|---|
| Saldo grande del Panel | **el total de todas las cuentas** | `LiveBalanceCalculator` hace fallback al agregado |
| Widgets del Panel | **0** | van por `computeEligibleAccounts`, que no tiene fallback |
| KPI de Distribución | **0** | igual que los widgets |

Es alcanzable desde la UI sin nada exótico: `PanelViewModel.orderedActiveAccounts` filtra por
`isArchived` y **no** por `excludeFromStatistics`, así que el carrusel del Panel lista esas cuentas y
se pueden tocar.

## Por qué existe

El fallback replica el comportamiento del antiguo `BalanceHelper.displayedBalance` y está fijado
deliberadamente por `liveBalance_selectedAccountIDExcluded_fallsBackToTotal` en
`YalaTests/LiveBalanceCalculatorTests.swift`. Estadísticas nunca lo tuvo: su
`computeEligibleAccounts` devuelve `[]` y el KPI sale 0.

`panel-colapsa-la-seleccion-de-cuentas-a-la-primera` lo **preservó a propósito** al generalizar el
filtro a conjunto: cambiarlo es una decisión de producto, no parte de aquel arreglo, y tocarlo a
ciegas rompe un test que fija el contrato heredado.

## Qué hay que decidir

Qué debe ver el usuario que filtra una cuenta excluida de estadísticas. Tres salidas:

1. **0 en las tres piezas** — el Panel se alinea con Estadísticas. Coherente y sencillo de explicar
   («esa cuenta no cuenta para estadísticas»), pero un saldo grande en 0 puede leerse como un fallo
   de la app.
2. **El total en las tres** — se propaga el fallback a los widgets y al KPI. Coherente, pero enseña
   un número que el filtro no pidió.
3. **No dejar filtrarlas** — el carrusel no lista cuentas excluidas de estadísticas, y el caso
   desaparece. Es el más limpio, pero quita al usuario una vista que hoy tiene.

Sea cual sea, **las tres piezas tienen que decir lo mismo**: hoy el defecto no es el número, es que
la pantalla se contradice.

## Nota relacionada

El mismo estado se alcanza con un **ID fantasma**: `EntityDeletionService` borra una cuenta sin
limpiar `SessionState.selectedAccountIDs`, así que el filtro sobrevive a la cuenta. Ahí el chip
tampoco se pinta (`buildAccountChips` devuelve `[]` si ningún ID resuelve) y el usuario ve widgets a
cero sin nada que explique por qué. Puede cerrarse aquí o en ticket propio, pero la limpieza al
borrar es un arreglo independiente y probablemente el más barato de los tres.

## Acceptance Criteria

- [ ] Decidido cuál de las tres salidas, y por qué.
- [ ] Saldo grande, widgets y KPI de Distribución coinciden en el caso «selección no contable».
- [ ] Borrar una cuenta filtrada no deja su ID vivo en `SessionState`.
- [ ] El test que fija el fallback se actualiza o se retira **conscientemente**, no de rebote.

## Medido en 2.1 (triage 2026-10-08)

- Fallback vivo: `LiveBalanceCalculator.swift:118-122`, fijado por `liveBalance_selectedAccountIDExcluded_fallsBackToTotal`
  (`LiveBalanceCalculatorTests.swift:281`).
- `PanelViewModel.computeEligibleAccounts` (`PanelViewModel.swift:1455`) no tiene fallback. `orderedActiveAccounts` (`:1065`)
  solo filtra `isArchived`.
- `EntityDeletionService.swift` no toca `SessionState.selectedAccountIDs`, así que el ID fantasma sigue.

## Pregunta para Jürgen (triage 2026-10-08)

Qué ve quien filtra el Panel por una cuenta excluida de estadísticas:

- **A** · 0 en las tres piezas, igual que en Estadísticas.
- **B** · El total en las tres.
- **C** · El carrusel no lista cuentas excluidas de estadísticas, y el caso desaparece.

**Recomendación: A**, junto con limpiar el ID al borrar la cuenta. Iguala la pantalla con Estadísticas sin quitar ninguna
vista. Exige retirar el test del fallback a conciencia. Con A, `medium`.

Triage 2026-10-08: abierto · medium → medium · El fallback de LiveBalanceCalculator sigue fijado por test, computeEligibleAccounts del Panel no lo tiene, y borrar una cuenta filtrada sigue sin limpiar selectedAccountIDs; sigue pendiente la decisión de producto que dejó 8b2aa9393.
