---
id: hidden-single-currency-still-filters-the-amount-in-it
status: done
priority: low
area: "filtros, registros"
created: 2026-10-17
updated: 2026-10-25
source: "implementación del lote 8 de la auditoría UX 2.2 (2026-10-17), visto leyendo el código (agente de filtros)"
---

# En «Ocultar», con una sola moneda marcada, el monto se filtra en la moneda que se oculta

## El problema, en lenguaje de usuario

En Registros › Filtros, en modo «Ocultar», si marcas una sola moneda (por ejemplo USD, para no ver lo de dólares), el
bloque de monto aparece y filtra los importes **en USD**, que es justo lo que estás ocultando.

## Qué se sabe

- Visto leyendo el código durante L8-16 (`RecordsFiltersView`, condición «una única moneda» para enseñar el monto), no
  medido en pantalla.
- La regla de «una sola moneda para filtrar por monto» se escribió pensando en «Mostrar solo».

## Qué hacer

Medirlo en el simulador. Si se confirma: en «Ocultar» el monto no se ofrece con la moneda marcada (o se ofrece en la
otra, si solo quedan dos), y la línea que lo explica lo dice.

## Cerrado (cola 2.2 · lote 12.5, 2026-10-25)

Medido en el simulador con la base de 2.2: en «Ocultar», con USD marcado, el campo del monto decía USD. Ahora el monto compara en la moneda que queda a la vista (PEN), con la regla en `RecordsAmountFilterCurrencyLogic`; con varias o ninguna a la vista no hay monto, y la ayuda dice «Para filtrar por monto, deja a la vista una sola moneda» (clave nueva en los 16 locales). Tests: `RecordsAmountFilterCurrencyLogicTests` y `UXAudit22Lote8CUITests.test_filters_hidingOneCurrency_amountUsesTheOneLeft`.
