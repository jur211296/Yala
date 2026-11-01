# Tu parte en líneas y Cobros: tres propuestas

Jürgen elige una. La implementa otra tanda. Nada de esto está implementado.

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
