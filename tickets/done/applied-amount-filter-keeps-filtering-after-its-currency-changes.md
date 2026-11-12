---
id: applied-amount-filter-keeps-filtering-after-its-currency-changes
status: done
priority: low
area: "filters"
created: 2026-10-25
updated: 2026-10-28
source: "review adversarial del lote 12.5 (2026-10-25), leído en el código, sin medir en pantalla"
---

# Un monto ya aplicado sigue filtrando cuando cambia la moneda que tenía a la vista

## Qué pasa (leído en `2.2`, sin medir)

El lote 12.5 hizo que la hoja de Filtros no aplique el monto cuando no queda una sola moneda a la vista. Quedan dos
caminos fuera de la hoja:

1. Quitar el chip de una moneda desde la barra de filtros (`FilterControlBar`): el monto sigue aplicado y pasa a
   comparar cada registro en su propia moneda.
2. Crear el primer registro en una moneda nueva: el monto aplicado empieza a filtrarla en su unidad.

Y el chip «>100» no dice en qué moneda compara.

## Qué hacer

Medirlo. Si se confirma: vaciar el monto (o avisarlo) cuando su moneda deja de ser la única a la vista, desde
cualquier escritor del filtro (`session-filters.md`: el filtro tiene varios escritores).

## Resolución (2026-10-28, lote panel-filtros-moneda)

Decisión: **vaciar**, no avisar. Es lo único que garantiza que el monto nunca compare mezclando monedas, y la cápsula del
monto desaparece de la barra, que es lo que se ve.

- La hoja aplica el monto con su moneda (`SessionState.applyAmountFilter`).
- `SessionState.revalidateAmountCurrency` lo vacía si esa moneda deja de ser la única a la vista, desde los cuatro
  escritores posibles: `selectedCurrencies`, `excludedCurrencies` (la ✕ de la barra, «Ver solo / Ocultar» desde un
  segmento), el fin de `performBatchFilterUpdate` y `incrementDataVersion` (el primer registro en una moneda nueva).
- Las monedas con registros salen de `CurrenciesWithRecords`, la misma cuenta que la hoja (si divergieran, la guarda
  vaciaría el monto que la hoja acaba de aplicar). La instala el arranque.
- Un monto sin moneda apuntada (tests, un escritor que no la sabe) o sin fuente no se toca.

Fuera: el chip «>100» sigue sin decir la moneda.

Tests: `PanelFiltrosMonedaLogicTests#AppliedAmountCurrencyGuardTests` (los dos caminos del ticket, controles y el bloque).
