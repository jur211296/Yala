# Tu parte en líneas y Cobros: tres propuestas

Jürgen eligió la B el 1-nov y la ajustó en la misma sesión: la versión que manda es la de la sección
**«Versión final acordada»**, al final. Lo de arriba es el registro de las propuestas.

- Página con las maquetas: `propuestas.html` (se abre en el navegador; es la misma que el artifact
  https://claude.ai/artifact/J74eL1gLzfrCDNN88zo7Sa).
- Capturas reales de hoy (simulador, iPhone 17 Pro, iOS 27.0): `hoy-grupos-claro.jpg` (Nuevo gasto de Grupos con el
  registro unificado aplicado) y `hoy-bandeja-oscuro.jpg` (la hoja de la Bandeja que completa un gasto de grupo).
- Decisiones de la sesión: `encargos/lanzados/2026-11-01-grupos-tu-parte-en-lineas-propuestas.md`, sección Paso 0.

## El problema

Hoy tu lado de un movimiento de grupo es siempre un gasto, y de una sola línea. El puente escribe montos negativos y el
formulario abre el selector de subcategoría solo con las de gasto. No existe el Cobro.

1. **La recarga de Pía.** Pía paga S/ 510 para recargar la tarjeta Sip de Jürgen y lo apunta como un gasto de 510, todo
   de Jürgen. En realidad son S/ 500 que pasan a Sip (ni ingreso ni gasto) y S/ 10 de comisión. La deuda con Pía es de
   S/ 510. Hoy Yala apunta un gasto de 510 en la cuenta «Grupos» y Sip no se entera.
2. **Una venta que aún no te pagan.** Tu lado es un ingreso y el otro te debe. Hoy solo se puede apuntar como un gasto
   pagado por ti, y Yala saca de tu cuenta un dinero que nunca salió.

## Las tres propuestas

| | A · Líneas, Cobro local | B · Líneas + Cobro del grupo | C · Repartir después |
|---|---|---|---|
| Qué es | Tarjeta «Tu parte» en Nuevo gasto y en la Bandeja; cada línea es gasto, ingreso o recarga | A, y un selector Gasto \| Cobro que viaja al grupo | Los formularios no cambian; «Repartir tu parte» en el detalle del registro |
| Caso Pía | En el mismo gesto (crear o aprobar) | En el mismo gesto | Aprobar y luego repartir |
| Cobro | Interruptor «No salió dinero de tu cuenta» | Tipo propio, con aviso «te cobró» | «Convertir en cobro» después |
| Servidor de Grupos | Nada | Columna `kind`, Worker y aviso | Nada |
| Cards | 7 | 9 (6 + 3) | 6 |

**Recomendación: B en dos tandas.** La primera (6 cards, sin tocar el servidor de Grupos) ya resuelve el caso de Pía. La
segunda trae el Cobro, primero en staging. Si no se quiere tocar Grupos, A resuelve lo mismo con el Cobro solo en tu lado.

## Lo que comparten: cómo se guardan las líneas

- **Las líneas son una receta en el canal personal**, un JSON en una sola pata del gasto (`TransactionItem.splitLinesRaw`,
  `since: 6`, molde `cashflow_lines.amount_changes_raw`). El puente deriva de ella las demás patas en cada pasada. Guardarlas
  como filas sueltas no sirve: `BridgeBranchLogic.partitionVirtualTxs` borra toda pata virtual de más.
- **La recarga es un par de transferencia** (`transferPairID`, `balanceAdjustmentType = "transfer"`) desde «Grupos» si
  pagó otro, o desde tu cuenta si pagaste tú. Estadísticas ya excluye todo movimiento con `balanceAdjustmentType`.
- **`GroupBridgeStatsAdjustment` cambia**: netea el préstamo contra la primera pata real del gasto, que con líneas podría
  ser la entrada en Sip. Tiene que ignorar las patas de transferencia. El conector `mcp/` tiene su port
  (`mcp/src/logic/groups.ts`) y cambia igual.
- **Si el monto del gasto cambia**, las líneas dejan de cuadrar y vuelve un borrador a la Bandeja.

## Compatibilidad

- **Otros miembros:** no ven tus líneas. En B, quien tenga 2.1 no recibe `kind` (el Worker poda por versión) y ve un
  gasto pagado por ti; sus saldos salen bien porque el cálculo no mira el tipo.
- **Un aparato tuyo con 2.1:** no conoce la receta y su puente deja una sola pata cuando reprocesa ese gasto. La receta
  sigue en el servidor y un aparato con 2.2 rehace las líneas. Se corta subiendo la versión mínima al publicar 2.2.
- **Versiones viejas:** 1.x no tenía Grupos y 2.0 los llevaba por iCloud, transporte retirado en la Fase 3.

## Orden de despliegue

Canal personal: DDL → Worker → app, con el campo nuevo en los cuatro `.ckdb` y desplegado a Production de CloudKit antes
del build. Grupos (solo B): `split_expenses.kind` con `since: 3`, `group_capability_manifest.json` v3 y
`GroupsSyncCapability.columnSince`. Todo cambio de servidor, en staging antes que en producción.

## Versión final acordada (2026-11-01)

Acordada con Jürgen en la sesión `grupos-opcion-b-version-final`. Maquetas por escenario: `opcion-b.html` (artifact
https://claude.ai/artifact/7r4utQ1genzSPEzmPJzutV). Sustituye a la B de arriba donde se contradigan.

**Lo que cambia respecto a la B original.**

1. **El formulario de Nuevo gasto de Grupos no cambia.** Ni tarjeta «Tu parte», ni selector Gasto | Cobro, ni «Nuevo
   movimiento». Jürgen: no complicarle la vida a quien no combina Grupos con sus cuentas.
2. **No existe el Cobro.** «Todas las transacciones de un split ya son cobros»: un tipo aparte confunde. Se caen las tres
   cards del Cobro (columna `kind`, Worker y manifest v3 de Grupos, aviso `chargeAdded`). **El servidor de Grupos no se
   toca.**
3. **La línea de ingreso desaparece de «Tu parte».** Las líneas son Gasto o Recarga.

**Cómo queda.**

- **Partir tu parte** se hace fuera del formulario y solo lo ve quien tiene el puente activo (no en sesión solo-grupos):
  - en la **Bandeja**, si el gasto lo apuntó otro: la hoja de hoy más un botón «Partir»;
  - en la **pantalla de éxito**, si lo apuntaste tú: enlace «Partir tu parte» en el bloque de «qué apuntó Yala en tus
    finanzas»; y más tarde desde el **detalle del registro**.
  - Las líneas tienen que sumar tu parte; si no, «Guardar»/«Aprobar» esperan y la tarjeta dice cuánto falta.
  - Recarga = par de transferencia desde «Grupos» (pagó otro) o desde la cuenta con que pagaste (pagaste tú).
- **Categorías de ingreso en el gasto de grupo.** El selector de categoría del formulario ofrece también las de ingreso.
  Con una de ingreso no se pide cuenta (no salió dinero). Es el único cambio del formulario.
- **Lo que te deben por una venta queda «por cobrar».** Tu cuenta «Grupos» lo suma (sigue coincidiendo con el saldo del
  grupo) y Estadísticas no lo cuenta como ingreso. *(Decisión 1 · a.)*
- **El ingreso cuenta el día que te pagan**, con la liquidación de siempre. Un pago cubre primero lo más antiguo (por
  fecha, mezclando ventas y gastos adelantados); lo que no es venta entra como devolución, igual que hoy. Una deuda
  cruzada que deja el saldo en cero cubre la venta entera. Con «simplificar deudas» cuenta tu saldo, no quién paga a
  quién. *(Decisión 2 · a.)*
- **Los demás miembros no ven nada nuevo**: un gasto normal y el aviso «agregó» de siempre.
- **Fuera de alcance:** vender algo a medias y cobrar tú todo (el sofá de los dos). Se apunta con dos registros.
  *(Decisión de Jürgen.)*

**Compatibilidad.** Un aparato tuyo con 2.1 no conoce la receta ni lo por cobrar: deja tu parte en una línea hasta que
un aparato con 2.2 la rehace, y ante una venta por cobrar pide una cuenta en la Bandeja (no aprobarla ahí). Se corta
subiendo la versión mínima al publicar 2.2.

**Lo técnico que sigue en pie de arriba:** la receta en el canal personal (`TransactionItem.splitLinesRaw`, `since: 6`,
DDL → Worker → app, campo en los cuatro `.ckdb` y deploy a Production de CloudKit antes del build); el ajuste de
`GroupBridgeStatsAdjustment` y su port en `mcp/`; el borrador a la Bandeja cuando el monto cambia y las líneas no
cuadran. Las cards están en el tablero (proyecto Yala, versión 2.2).
