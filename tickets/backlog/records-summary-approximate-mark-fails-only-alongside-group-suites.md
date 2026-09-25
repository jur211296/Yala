---
id: records-summary-approximate-mark-fails-only-alongside-group-suites
status: backlog
priority: medium
area: "testing, currency"
created: 2026-09-15
updated: 2026-09-25
source: "gate de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` (2026-09-15): único rojo de la suite completa"
---

# Un test del resumen de Registros pasa solo y falla acompañado de las suites de grupos

Esto no lo ve nadie que use la app: lo paga la suite. Y lo que cuesta es peor que un rojo — **es un rojo que
parece del cambio que se está revisando**, y mandó una sesión entera a buscar una causa que no tenía.

## Lo medido (2026-09-15)

`RecordsSummaryApproximateMarkTests` → **«Dos lados bajo el umbral con un saldo pequeño SÍ marcan el saldo»**,
`YalaTests/ApproximateAmountMarkTests.swift:1115` y `:1118` (dos `#expect`: que el lado de ingresos NO marque y
que el saldo SÍ marque).

| Cómo se corrió | Resultado |
|---|---|
| las 3 suites de su fichero, aisladas | **pasa** · 39 tests en 3 suites en 0,21 s |
| dentro de un lote de 69 suites | **falla** · 683 tests, 1 fallido con 2 issues |
| suite completa en un proceso | **falla** · el mismo test, los mismos dos `#expect` |

**No es el patrón del store compartido por `#fileID`**: en ese fichero **solo** `RecordsSummaryApproximateMarkTests`
llama a `makeTestContext()` (líneas 1011, 1042, 1068 y 1094), así que sus dos suites hermanas no le vacían el
store.

**Con quién comparte lote cuando cae** — las cuatro son de grupos, bridge y FX: `ApproximateAmountMarkTests`,
`DevSeedGroupBridgeFXLegsTests`, `GroupBridgeCloudSyncIntegrationTests` y `GroupsPendingBridgeDurabilityTests`.
Las dos últimas tocan estado global: **15 y 8 usos** de `UserDefaults.standard` o de singletons `.shared`.

## La hipótesis, sin medir todavía

El test afirma qué se marca como aproximado, y eso depende de la calidad de conversión FX y de qué filas entran
en el resumen. Dos sospechosos concretos, los dos ya conocidos en `.claude/rules/testing.md`:

1. **Una preferencia global que una vecina escribe y no restaura** — el precedente exacto es
   `RecordsViewModel.applyFilters`, que lee `includeGroupTransactionsInFeed` de `UserDefaults.standard` por su
   cuenta y, en `false`, descarta toda fila con `splitExpenseID`.
2. **Tasas o divisa preferida** dejadas por las suites de FX, que cambiarían la calidad de la conversión y con
   ella la marca.

## Cómo confirmarlo (barato)

- Correr el test con **una sola** vecina cada vez: cuatro corridas y sale el culpable.
- Con el culpable en mano, la corrección es la de la regla: fijar y **restaurar** esa clave en la suite que la
  escribe (`defer`), o aislarla con `makeIsolatedDefaults()`.

## Criterios de aceptación

- [ ] Nombrada la clave o el singleton que cruza, con su suite escritora.
- [ ] El test pasa dentro de la suite completa, y sigue pasando aislado.
- [ ] Si la escritora necesita ese estado global, queda con `defer` que lo restaura.

## Relación con otros tickets

- `approximate-mark-ors-over-whole-period` (en `qa`) — el trabajo que trajo este test, commit `415193daa`.
- `appstorage-onboarding-desarma-el-aislamiento-de-tests` — misma familia (estado que sobrevive al test), otro sitio.

## Reapariciones

- **2026-09-25**, gate de `an-undecodable-migration-phase-reads-as-never-started`: único rojo de la suite completa
  (7937 tests en 756 suites, los mismos dos `#expect` de `:1115` y `:1118`); `RecordsSummaryApproximateMarkTests` a solas,
  3/3 verde. El cambio de esa sesión no toca resúmenes ni `SessionState`.
