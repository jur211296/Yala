---
esfuerzo: high
release: no
---
# Grupos B: cablear la tarjeta «Tu parte» con «Partir» en la Bandeja, la pantalla de éxito y el detalle del registro

Cards: tablero-grupos-b-5-partir-en-la-bandeja-de-un-ga-wrlu, tablero-grupos-b-6-partir-tu-parte-en-la-pantall-ffpl

## Contexto
Manda la opción B que Jürgen acordó el 1-nov: `docs/disenos/grupos-tu-parte-en-lineas/README.md`, sección «Versión final acordada», y el diseño técnico en `tickets/in-progress/grupos-tu-parte-en-lineas.md` (PR #733). El puente (cards 2 y 3, PR #737) ya está en 2.2. La tarjeta «Tu parte» y la hoja de una línea (card 4, PR #738) ya están en 2.2 como componente sin cablear; las decisiones de diseño que tomó esa sesión están anotadas en el PR #738.

Pendiente de confirmar con Jürgen (anotado en el cierre del #737): al aprobar el aviso de «las líneas ya no cuadran», el puente deja tu parte en una sola línea y retira la receta, mientras que el diseño acordado decía que aprobar la reescribe. Si tu trabajo depende de ese comportamiento, respeta lo que hay en 2.2 y anótalo en el PR; no lo cambies.

## Qué hacer
### Card 5: «Partir» en la Bandeja de un gasto de grupo
- En las hojas de grupo de la Bandeja (GroupExpenseDraftFinalizationSheet y hermanas), la hoja de hoy más un botón «Partir» que abre la tarjeta «Tu parte»; «Aprobar» espera a que cuadre. Solo con el puente activo.
- Hecha cuando: XCUITest del caso Pía desde la Bandeja; sin tocar «Partir» la hoja aprueba como hoy; capturas antes/después.

### Card 6: «Partir tu parte» en la pantalla de éxito y en el detalle del registro
- Enlace en el bloque «qué apuntó Yala en tus finanzas» de GroupExpenseSuccessView y acción en el detalle del registro puenteado. Solo con el puente activo y fuera de sesión solo-grupos. El formulario de Nuevo gasto NO cambia.
- Hecha cuando: XCUITest: apuntar el súper y partirlo desde el éxito; sesión solo-grupos sin enlace; capturas antes/después.

Haz XCUITest de cada flujo. Pon capturas de antes y después (claro y oscuro, con Dynamic Type grande) en el digest.

## Reglas
- Lo que toque el servidor (Worker o Supabase) se prueba en staging antes de producción.
- Capturas de antes y después de la UI en el digest.
- Si algo no cabe, crea su card en 2.2 antes del barrido QA (S36).

Termina con /cerrar-total.

## Paso 0

Decisiones tomadas al empezar (sesión autónoma, sin Jürgen delante; lo que el diseño acordado no fija se resuelve por la
maqueta `opcion-b.html` y, si calla, por lo mínimo).

1. **Bandeja: «Partir» es una pastilla al lado de la de categoría**, como en la maqueta (escenario 1, pantalla 2). Al
   tocarla, la tarjeta «Tu parte» sustituye a la pastilla de categoría dentro de la misma hoja; «Aprobar» se enciende con
   `GroupSplitLinesEditorLogic.canSave`. Sin tocar «Partir», la hoja es la de hoy.
2. **Qué hojas lo llevan**: `GroupExpenseDraftFinalizationSheet` (pagó otro: puntero `[.subcategory]` y aviso de «no
   cuadra») y las dos de cuenta (`GroupExpenseAccountFinalizationSheet`, `…AndSubcategory…`: pagaste tú y lo apuntó otro
   en remoto). En las de cuenta se sigue pidiendo la cuenta; con la tarjeta abierta desaparece la pastilla de categoría
   (las líneas la llevan) y se esconden los «¿Ya lo apuntaste?» (enlazar un movimiento no parte nada).
3. **Puerta**: puente activo para ese grupo (`BridgeModeResolver`), sesión privada (eje de datos, el que mira el puente),
   fuera de la shell solo-grupos (`isGroupsFocusedShell`, visibilidad), tu parte > 0 y no es un saldo inicial. Lógica pura
   en `GroupSplitLinesEntryLogic`. Un borrador opt-in (puente apagado) no lo ofrece.
4. **Líneas iniciales**: el aviso de «no cuadra» abre con la receta que ya había (para arreglarla); lo demás, una línea de
   gasto por tu parte entera con la categoría elegida (card 4, decisión 5).
5. **Una sola línea de gasto = lo de hoy**: aprobar o guardar sin receta (`isSingleExpense`), con la categoría de esa
   línea. Así «Partir» no tiene botón de deshacer: volver a una línea es deshacer.
6. **Aprobar el aviso de «no cuadra» con «Partir» reescribe la receta**; sin «Partir», sigue como lo dejó el #737 (tu parte
   en una línea y fuera la receta). No cambio ese comportamiento; queda anotado en el PR (pendiente de Jürgen).
7. **Pantalla de éxito**: enlace «Partir tu parte» dentro del bloque «qué apuntó Yala» (`moneyLine`), solo con
   `chargedToAccount` o `shareAsGroupExpense` y la puerta de 3. Abre la hoja «Tu parte» (título, descripción, importe,
   tarjeta y «Guardar»). Tras guardar, el enlace sigue y reabre con las líneas guardadas.
8. **Detalle del registro**: fila-botón «Partir tu parte» en la tarjeta de detalles de un registro de gasto de grupo (pata
   con `splitExpenseID`), misma puerta y misma hoja. La entrada de una recarga (sin puntero) no la lleva.
9. **Dónde se escribe**: `GroupSplitLinesService` (resuelve tu parte, la pata que lleva la receta y la cuenta de origen;
   escribe la receta y pasa el puente) y `DraftService.approveDraft(_:currencyConverter:splitLines:)` para la Bandeja. El
   puente no cambia.
10. **Semilla de QA**: `-uitest-seed-group-split-lines` siembra «Pía y yo» con «Recarga Sip» S/ 510 pagado por Pía y todo
    tuyo, la cuenta Sip, y lo pasa por el puente real (borrador en la Bandeja).
11. **Fuera**: la línea resumen de la maqueta («Debes S/ 510 a Pía · Sip sube S/ 500») y «Dejar para después» no están en
    las hojas de hoy ni los pide el encargo; no se añaden. El editor de un registro con receta sigue como lo dejó el #737.
