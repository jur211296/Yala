---
id: combined-filters-edge-cases-after-option-b
status: backlog
priority: low
area: "filters, records, panel"
created: 2026-10-26
updated: 2026-10-26
source: "review adversarial de stats-filter-segment-tap-should-ask-include-or-exclude (2026-10-26), lente de estado y gesto"
---

# Filtros combinados: cuatro bordes que quedaron fuera del PR

Tras pasar a incluidos y excluidos por dimensión (PR del ticket `stats-filter-segment-tap-should-ask-include-or-exclude`)
una review adversarial dejó estos cuatro bordes. Ninguno cambia una cifra en el camino normal; los cuatro son
inferidos leyendo el código, sin reproducir.

1. **Hoja de Registros, selector de categorías.** Cuentas, etiquetas, necesidades y monedas marcan con un contorno lo
   que está en la otra lista («Mostrar solo» / «Ocultar»); el selector de subcategorías (`CategorySelectorSheet`) no.
   Elegir Comida entera en «Mostrar solo» saca de ocultos una subcategoría suya sin que se viera que estaba oculta.
2. **Un oculto cuyo valor se borró.** Si se borra una categoría, subcategoría o etiqueta oculta, su id sigue en
   `excluded*`: la barra del Panel sale sin cápsulas ni ✕ (`hasExcludedFilters` cuenta el id; `ExcludedFilterChips` no
   lo encuentra). Las cuentas sí se limpian (`forgetDeletedAccount`).
3. **Tarjetas con líneas.** Con «Solo Visa» (la tarjeta y sus líneas), ocultar una línea suelta se deshace: la
   normalización de `selectedAccountIDs` la vuelve a meter. No se ofrece hoy desde la interfaz.
4. **Monto tras quitar la moneda (preexistente).** `RecordsAmountFilterCurrencyLogic` solo decide al aplicar la hoja. Con
   «Sin PEN» el monto compara en USD; al quitar «Sin PEN» con su ✕ el monto sigue y vuelve a filtrar los PEN con el umbral
   pensado para USD. La ✕ de «Solo USD» ya lo hacía antes.
