# Panel / filtros / moneda (cinco bordes)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `panel-filtros-moneda` · Sesión cola **S15** · al cerrar → **S16**.

**Esfuerzo high** (bugs / mucho que leer). Sé exhaustivo en la paridad y los tests.

## Contexto · cards del lote
- Las tartas del Panel dejan fuera gastos que Registros cuenta con un filtro de importe
- Las tartas del Panel tratan «Ocultar» una moneda como «Mostrar solo» y comparan el monto con signo
- Exportar: en «Ocultar» el monto se etiqueta con la moneda oculta y compara con signo
- Un monto aplicado sigue filtrando cuando cambia la moneda que tenía a la vista
- Filtros combinados: cuatro bordes tras incluidos y excluidos (selector de categorías, ocultos borrados, líneas de tarjeta, monto)

## Briefs per-card (lee y cumple cada uno)
- `~/Claude/tmp-frank/panel-tartas-filtro-importe-signo-1jno.md`
- `~/Claude/tmp-frank/panel-tartas-ocultar-moneda-monto-8d7x.md`
- `~/Claude/tmp-frank/exportar-ocultar-monto-moneda-rx7l.md`
- `~/Claude/tmp-frank/monto-aplicado-cambia-moneda-8vrl.md`
- `~/Claude/tmp-frank/filtros-combinados-cuatro-bordes-996m.md`

## Qué se pide
1. Lee y cumple los cinco briefs de panel/filtros/moneda (tartas importe, Ocultar moneda/signo, exportar, monto al cambiar moneda, cuatro bordes combinados).
2. Prioriza paridad tartas ↔ Registros ↔ exportar ↔ FilterService.
3. Un PR (o PR chico por familia si el diff explota) a 2.2; tests de paridad.
4. Medir en sim antes de «arreglar» si el brief lo pide.

Mueve las cards a «in progress» con `--agente frank` al empezar; al cerrar, a in qa / done según el cierre de cada una.

## Qué NO tocar
- marketing/ y Web/ (Lola).
- Otras sesiones de la cola (no las lances).
- No desactivar tests ni saltarte el gate.
- Lo específico de cada brief per-card.

## Cómo se sabe que está bien
Cada card cumple su hechaCuando; suite relevante verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones (resueltas en autónomo, bypass)

Medido en el código de `origin/2.2` (a3655fa48) antes de decidir.

1. **Monto sin signo (1jno, mitad 2 de 8d7x, mitad 2 de rx7l).** Una sola regla, `AmountFilterCondition.matches(signedAmount:)` = `abs`, que usan `FilterService`, las tartas del Panel (`buildPieContextTransactions`) y `TransactionsExportService`. No se toca `FilterService` a signed.
2. **«Ocultar» moneda en las tartas (mitad 1 de 8d7x): ya arreglado** por c5e2c1a89 (incluidos/excluidos): el filtro de moneda del Panel es `EntityFilter(included:excluded:)`. Solo se fija con test de paridad.
3. **Exportar (rx7l).** La moneda del monto sale de `RecordsAmountFilterCurrencyLogic` con el modo global del asistente (en «Ocultar» lo marcado es lo excluido). Sin una sola moneda a la vista el monto no se aplica (como la hoja de Registros) y en «Ocultar» la ayuda es «deja a la vista una sola moneda» (clave ya traducida).
4. **Monto al cambiar la moneda (8vrl + borde 4 de 996m, son el mismo).** Se VACÍA (no se avisa): es lo único que garantiza «nunca mezcla monedas», y la cápsula del monto desaparece, que es lo que se ve. `SessionState` guarda la moneda del monto al aplicarlo (`applyAmountFilter`) y lo revalida en los cuatro escritores posibles: las dos listas de monedas, el fin del volcado en bloque y `incrementDataVersion` (moneda nueva). La lista de monedas con registros sale de un helper único con la hoja (`CurrenciesWithRecords`). Un monto sin moneda apuntada (tests) o sin fuente no se toca. El texto del chip («>100» sin moneda) no cambia: fuera.
5. **Borde 1 (selector de categorías):** contorno de la otra lista en subcategoría y en la fila de su categoría, con los colores de la hoja.
6. **Borde 2 (oculto borrado):** `forgetDeletedFilterValues` en los borrados de la persona (embudo + lista de Ajustes), después de guardar; lo que borra sync/deduplicador queda como con las cuentas.
7. **Borde 3 (línea suelta oculta con «Solo Visa»): descartado.** Inalcanzable hoy (medido: ningún segmento crea `.account`, y la hoja no ofrece líneas de una tarjeta elegida). Arreglar la normalización abre un estado nuevo que el volcado en bloque de la hoja rompería (la línea quedaría fuera de las dos listas). Se reabre con el gesto que lo ofrezca.
8. **Medir en sim:** los bugs de lógica se miden con tests en rojo contra la base; en el simulador, capturas antes/después de lo que se ve (selector de categorías y monto de Exportar en «Ocultar»).
9. **Entrega:** un PR a 2.2 en auto-merge; tickets a `done` salvo lo que pida ojo de Jürgen.
