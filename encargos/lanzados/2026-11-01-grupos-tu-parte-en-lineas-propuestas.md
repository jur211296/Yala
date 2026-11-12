---
esfuerzo: high
release: no
---
# Propuestas: partir tu parte de un movimiento de grupo en gasto, ingreso o recarga, y cobros en grupos

Card: tablero-propuestas-partir-tu-parte-de-un-movimie-itr6

Sesión de PROPUESTAS, aprobada por Jürgen el 1-nov a las 13:07. Solo propuestas y documento: NO se implementa nada, no se toca el código de la app y no se abre un PR de producto.

## Contexto
Hoy, en Grupos, tu lado personal de un movimiento siempre es un gasto:
- `GroupTransactionBridge.swift` escribe montos negativos en `bridgeExpense`, `createCaseBVirtualMyShare` y `createDraftCaseA`.
- `GroupExpenseFormView.swift` abre `SubcategorySelectorSheet` con `transactionType: .expense` fijo.
- Las hojas de aprobación de la Bandeja (`GroupExpenseDraftFinalizationSheet`, `GroupExpenseAccountAndSubcategoryFinalizationSheet`) eligen el tipo según el signo, pero el draft siempre llega negativo.
- No se puede partir tu parte en varias líneas.
- No existe un cobro ni una venta: solo hay `SplitExpense` y settlements. Las únicas líneas de ingreso son las de sistema `loanToGroups`.

Casos reales:
1. Pía recarga la tarjeta Sip de Jürgen. Paga S/ 510 y mete un gasto de grupo por 510. En realidad son S/ 500 de recarga a la cuenta Sip (una transferencia a una cuenta propia, ni ingreso ni gasto) más S/ 10 de comisión (gasto). La deuda con Pía es de S/ 510.
2. Le cobras a alguien una venta que todavía no te paga. Tu lado es un ingreso con subcategoría de ingreso y el otro te debe.

## Qué se pide
Un artifact con 2 o 3 propuestas, con capturas reales de las pantallas actuales y mockups lado a lado, que cubran:
1. **Partir tu parte en líneas** (gasto con subcategoría, ingreso, y transferencia o recarga a una cuenta propia), tanto al apuntar en Nuevo gasto de Grupos como al aprobar desde la Bandeja. El caso Pía/Sip tiene que quedar resuelto de punta a punta.
2. **Un tipo «Cobro» en grupos**: tu lado es un ingreso y el otro queda debiéndote.
3. **Coherencia** con el registro unificado (la opción A ya implementada), la Bandeja, Yala IA y Estadísticas. La recarga no cuenta como ingreso ni como gasto, y hay que revisar `GroupBridgeStatsAdjustment`.
4. **Impacto**:
   - en el modelo (`SplitExpense` y las líneas del bridge);
   - en la sincronización con Supabase y el Worker (esquema, RPC, avisos);
   - en la compatibilidad con 1.0 y 2.1 y con los otros miembros del grupo que no tengan la versión nueva.

   Cada propuesta lleva su recomendación y una estimación de cards. Si alguna requiere cambios en el servidor, se prueban primero en staging y solo después en producción.

## Qué NO hay que tocar
- El código de la app, el servidor y la base de datos.
- La cola: la implementación se encola después, según lo que decida Jürgen.

## Cómo se sabe
- El artifact existe, con las opciones comparadas, los mockups, el impacto y una recomendación.
- La card queda en "awaiting decision" o en QA, con el enlace al artifact.
- El digest de cierre presenta las opciones de forma breve para que Jürgen elija.

## Cierre autónomo
Cierra sola. El digest presenta las opciones para que Jürgen elija; no se implementa nada.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué se entrega?** → Un artifact con tres propuestas y una copia del mismo contenido en
`docs/disenos/grupos-tu-parte-en-lineas/` (README + imágenes), sin tocar código.
Por qué: el encargo pide artifact y lo que dura tiene que vivir en el repo, como el registro unificado.
Alternativa descartada: solo artifact (se pierde al caducar el enlace).

**D2 · ¿Capturas reales de dónde?** → Nuevo gasto de Grupos: la captura del registro unificado ya
aplicado (commit `eb88d9bed`, árbol de hoy). Aprobación de la Bandeja: simulador con la semilla
existente `gasto-de-grupo-sin-su-grupo`. Sin semillas nuevas.
Por qué: una semilla nueva es código de la app, y el encargo lo prohíbe.
Alternativa descartada: escribir `DevSeed` para un borrador de grupo con su grupo.

**D3 · ¿Cuántas propuestas y en qué se diferencian?** → Tres. A: líneas en el formulario y en la
Bandeja, el Cobro solo en tu lado. B: A más el Cobro como tipo del grupo, que viaja al servidor.
C: los formularios no cambian; se reparte después, desde el registro.
Por qué: los dos ejes reales son dónde se parte y si el Cobro lo ven los demás.

**D4 · ¿Cómo se apunta una recarga?** → Como una transferencia (par con `transferPairID` y
`balanceAdjustmentType = "transfer"`) desde la cuenta «Grupos» (pagó otro) o desde tu cuenta real
(pagaste tú) hacia la cuenta propia. Ni ingreso ni gasto, por construcción.
Por qué: Estadísticas ya excluye todo movimiento con `balanceAdjustmentType`.

**D5 · ¿Dónde viven las líneas?** → En el canal PERSONAL, como una «receta» en JSON sobre una sola pata
del gasto (columna nueva `TransactionItem.splitLinesRaw`, `since: 6` en el manifest personal, mismo molde
que `cashflow_lines.amount_changes_raw`). El resto de patas se deriva de ella en cada pasada del puente.
Nunca en el grupo.
Por qué: el puente borra hoy toda pata virtual de más (`BridgeBranchLogic.partitionVirtualTxs`); si las
líneas fueran solo filas, una pasada del puente, o un aparato con 2.1, las borraría. Con la receta en la
pata que el puente conserva, se rehacen.
Alternativas descartadas: una tabla propia (el manifest personal versiona columnas, no tablas: `since` por
entidad no existe) y un marcador por fila (un 2.1 no lo ve y borra las patas sin poder rehacerlas).

**D6 · ¿Qué se recomienda?** → B, en dos tandas: primero las líneas (local), después el Cobro con
servidor (staging antes que producción).
Por qué: resuelve los dos casos de punta a punta, y Jürgen elige la propuesta completa cuando el
dominio financiero lo pide. Asumido: si prefiere no tocar el servidor de grupos, A cubre el caso Pía igual.
