---
esfuerzo: high
release: no
---
# Grupos B: categorías de ingreso en el gasto de grupo y la venta queda «por cobrar» en tu cuenta Grupos

Cards: tablero-grupos-b-7-categorias-de-ingreso-en-el-s-qfk4, tablero-grupos-b-8-una-venta-queda-por-cobrar-en-u3dy

## Contexto
Manda la opción B que Jürgen acordó el 1-nov: `docs/disenos/grupos-tu-parte-en-lineas/README.md`, sección «Versión final acordada», y el diseño técnico en `tickets/in-progress/grupos-tu-parte-en-lineas.md` (PR #733).

## Qué hacer
### Card 7: Categorías de ingreso en el selector del gasto de grupo
- El selector de categoría del formulario de gasto de grupo ofrece también las de ingreso; con una de ingreso desaparece la cuenta y la frase de abajo dice «Ana te debe S/ X. Cuenta como ingreso cuando te pague». Es el único cambio del formulario.
- Desbloqueo: Card 8 en la misma tanda (el puente tiene que saber qué hacer con un ingreso).
- Hecha cuando: XCUITest del alta de una venta; con categoría de gasto el formulario es idéntico al de hoy; capturas antes/después.

### Card 8: Una venta queda «por cobrar» en tu cuenta «Grupos»
- Gasto de grupo pagado por ti con categoría de ingreso: sin pata real; una pata en «Grupos» que suma al saldo y Estadísticas no cuenta. Ojo: un valor nuevo de balanceAdjustmentType hereda los ~45 `== nil` del repo; medirlos. Review adversarial (puente).
- Desbloqueo: Card 7 en la misma tanda.
- Hecha cuando: Tests: Grupos +120 por cobrar, Estadísticas sin ingreso, borrar o cambiar el monto mueve lo por cobrar.

## Orden
Las cards 7 y 8 van en la misma tanda: el formulario y el puente del ingreso.
- Mide los aproximadamente 45 `== nil` de `balanceAdjustmentType`.
- Haz una review adversarial del puente.
- Pon capturas de antes y después del formulario en el digest.

## Reglas
- Lo que toque el servidor (Worker o Supabase) se prueba en staging antes de producción.
- Capturas de antes y después de la UI en el digest.
- Si algo no cabe, crea su card en 2.2 antes del barrido QA (S36).

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 01:30 Lima): las recomendaciones se dan por buenas. Se discuten en el PR.

**Medido antes de decidir (árbol de `2.2` en c667e555).** `balanceAdjustmentType` sale 157 veces en `Yala/`: 52 `== nil`
y 17 `!= nil`. Los `== nil` son filtros de Estadísticas, Panel, Registros, presupuestos, flujo de caja, widgets, informes
y Yala IA: con un valor nuevo dejan fuera la venta, que es lo que se pide. Los `!= nil` pintan el importe en gris, quitan
«cambiar categoría» del menú y del teclado, saltan la reparación del chat y marcan Spotlight y los candidatos de enlace:
todos inocuos o deseados. Uno solo lee `!= nil` como «es una recarga»: la reversión de la pata conservada del puente
(`GroupTransactionBridge.swift:392`), que se corrige aquí. Supabase guarda la columna como `TEXT` sin restricción: el
servidor no cambia. El conector `mcp/` lo listará como `ajuste_de_saldo` (card 11).

**D1 · Cómo se marca lo por cobrar** → `balanceAdjustmentType = "receivable"` en una pata de «Grupos».
Por qué: hereda la exclusión de todas las superficies de Estadísticas sin tocar ninguna. Alternativa descartada: suprimirla
en `GroupBridgeStatsAdjustment`, porque unos veinte calculadores clasifican por categoría sin pasar por el ajuste y la
venta contaría como ingreso.

**D2 · Qué es una venta** → un gasto de grupo que pagaste tú (Caso A) cuya categoría resuelve a una subcategoría de
ingreso que no es de sistema. Vale en las tres ramas del Caso A: puente activo, puente apagado y sesión solo-grupos.
Por qué: una venta no le cuesta nada a nadie en ninguna de ellas. La pata real se borra siempre, también la del «Sí,
registrar» con el puente apagado, y su borrador si sigue pendiente. *(Corregido tras la review: la primera versión la
conservaba con el puente apagado y Estadísticas contaba el `-total` entero.)*

**D3 · La pata por cobrar** → una sola, en «Grupos», por `+(total − tu parte)`, con la subcategoría de ingreso, el
concepto del gasto y su fecha. Se reutiliza entre pasadas (es la pata clasificable que el puente ya conserva) y no
lleva receta de líneas. Si nadie te debe nada, no hay pata. Sin préstamo ni pata real al lado.

**D4 · El otro lado (Ana)** → en el Caso B una categoría de ingreso no clasifica tu parte: queda sin categoría y la
Bandeja pregunta, como un nombre que no casa. Por qué: «Ana ve un gasto normal»; con la categoría de ingreso su `−120`
contaría como ingreso, porque la categoría manda en `TransactionClassificationLogic`.

**D5 · Cambios de forma de la pata conservada** → por cobrar → otra cosa (cambió el pagador o la categoría): vuelve a
ser tu parte sin tipo ni categoría. Recarga → venta: se deshace la recarga (y su entrada) antes de ponerla por cobrar.
Una regla pura decide (`GroupSaleBridgeLogic`), con tests.

**D6 · El formulario** → el selector de categoría del gasto de grupo enseña «Gasto | Ingreso» arriba (solo desde ese
formulario: los demás selectores no cambian) y abre en el tipo de lo elegido. Con una de ingreso no se pide cuenta, no
se pasa la cuenta al guardar y no sale el «¿Lo registramos?» del puente apagado. La frase de abajo dice «Ana te debe
S/ 120.00. Cuenta como ingreso cuando te pague.» con un deudor y «Te deben S/ 120.00. Cuenta como ingreso cuando te
paguen.» con varios. Sale al crear y al editar (aquí el puente sí cumple lo que dice al editar), con sesión privada y
el reparto cuadrado.

**D7 · Registros** → la fila de la venta dice «Ventas • Por cobrar • Grupos», con el importe en gris (el gris ya lo da
el tipo). El detalle no cambia. Por qué: sin la palabra, un `+120` gris en «Grupos» no se explica.

**D8 · Pantalla de éxito** → sin cambios: dice «Te deben S/ 120.00» y no promete nada en tus cuentas (sin cuenta
elegida su línea personal ya se calla).

**D9 · Residual aceptado: la categoría viaja por NOMBRE** (`SplitExpense.subcategoryName`, y el servidor de Grupos no se
toca). Si una subcategoría de ingreso y una de gasto se llaman igual, el puente toma la primera que encuentra. Va a una
card de 2.2.

**D10 · Fuera de esta tanda** → cobrar (card 9-10), Estadísticas/IA/conector con lo cobrado (card 11), «Partir» en una
venta (la línea de ingreso desapareció del diseño).

**D11 · La pata por cobrar no se edita suelta** → el editor, «Editar varios» y el menú la tratan como una pata derivada
del puente: todo bloqueado y «se edita desde el grupo». Por qué: el puente reescribe su categoría en cada pasada; la
review encontró que el editor la dejaba cambiar y la pasada siguiente lo deshacía.

**Review adversarial (dos lentes: transiciones del puente y consumidores de `balanceAdjustmentType`).** Corregidos los
dos de arriba. Fuera, con card en 2.2: nombres repetidos entre gasto e ingreso (D9, `10u2`) y las superficies que aún no
dicen «por cobrar» —detalle, widget de inicio, ficha de la cuenta, pantalla de éxito— (`00xj`). Cubierto por la versión
mínima al publicar 2.2: un aparato con 2.1 (propio o de otro miembro) no conoce la venta; el del otro miembro casaría la
categoría de ingreso por nombre y contaría su parte como ingreso negativo.
