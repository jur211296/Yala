---
id: shared-scheduled-expense-shows-twice-in-inbox
status: qa
priority: high
area: "inbox, grupos, pagos-programados"
created: 2026-10-10
updated: 2026-10-10
source: "reporte de Jürgen, 2026-10-10 07:11 (Lima); card del tablero tablero-los-gastos-compartidos-planificados-apar-qo5b"
---

# Los gastos compartidos planificados aparecen dos veces en la Bandeja

## Lo que dijo Jürgen

> Los gastos compartidos (de grupo) planificados le salen DOBLE en la Bandeja.

A las 07:12 aclaró: un solo dispositivo, y el pago planificado no está guardado dos veces.

## Qué pasa, en lenguaje de usuario

Planificas un gasto compartido —Netflix a medias con tu pareja, con su cuenta y su categoría— y el día que vence
aparece en la Bandeja. Lo abres, la app te enseña el formulario del grupo con el importe, el reparto y la cuenta ya
puestos, y lo guardas. Acto seguido aparece **otro** borrador del mismo gasto, con el mismo nombre, el mismo
importe y la misma fecha, pidiéndote que elijas la categoría. La categoría ya la habías elegido al planificarlo.

## Medido (árbol `dc9ad91c9`, 2026-10-10)

- **Las rutas que crean el borrador planificado no duplican.** `processDuePayments` (arranque y vuelta a primer
  plano), `createAdvancedDraft` («Adelantar») y `recreateDraftIfNeeded` (des-saltar) pasan por `createDraft`, que
  siempre rellena `sourceScheduledPaymentID`, y las tres miran antes si ya hay un pendiente de ese pago. Corren en el
  main actor sin `await` entre la comprobación y el `save()`. Ningún otro sitio crea borradores con
  `sourceScheduledPaymentID` (bridge de grupos, notificaciones y Grupos incluidos). Lo fija
  `GroupScheduledExpenseSingleDraftTests.lasRutasDeCreacionDejanUnSoloBorrador`.
- **El segundo borrador nace al aprobar.** `InboxView.loadGroupScheduledContext` construía la
  `GroupExpensePrefillTemplate` con importe, reparto, descripción, cuenta y fecha del pago, y **sin su categoría**:
  el struct no tenía ese campo. El editor de pagos planificados la ofrece («cuenta y subcategoría son prefill
  opcional: el bridge/form las resuelve al aprobar») y el formulario de grupo nunca la recibía. El `SplitExpense`
  nacía con `subcategoryName == nil`, el puente creaba la transacción real sin categoría y, con ella, el borrador
  `.groupExpense` que solo pide categoría (`createCaseASubcategoryDraft`; con el puente apagado, el de la virtual).
  Rojo en `2.1`: `aprobarNoDejaOtroBorrador` dejaba 1 pendiente `.groupExpense ["subcategory"]`.
- **El mismo hueco en el otro productor de la plantilla**: convertir un borrador personal en gasto de grupo
  (`DraftToGroupExpenseTemplateLogic`) también perdía la categoría del borrador. Y un XCUITest lo fijaba como
  contrato: `InboxConvertToGroupUITests.test_convertDraftToGroupExpense_survivesAndReplacesDraft` esperaba que el
  borrador convertido («Almuerzo equipo», sembrado con cuenta y categoría) volviera a la Bandeja como borrador de
  grupo. Con el arreglo salió rojo en el gate; ahora afirma que la fila desaparece con la app viva y el otro
  borrador intacto.

## Arreglo

- `GroupExpensePrefillTemplate` gana `subcategory`, sin valor por defecto (como `date`): cada productor decide qué
  categoría corresponde. El del pago planificado pasa la del pago (`GroupScheduledExpenseTemplateLogic`, extraído
  de `InboxView` para poder probarlo), el de la conversión la del borrador, y `applyTemplate` la deja elegida en el
  formulario. El gasto nace clasificado y el puente no pide nada más.
- **Barrido de lo que ya está en los teléfonos** (`processDuePayments`, arranque y primer plano, detrás de la puerta
  de quiescencia): un borrador pendiente `.groupExpense` que solo pide categoría, cuya transacción real del gasto
  está enlazada a un pago planificado de grupo con categoría y sigue sin ella, se resuelve como si la persona lo
  aprobara con esa categoría (la transacción la recibe y el borrador se borra). Idempotente.

## Fuera, a propósito

- **Puente apagado**: no hay transacción real enlazada al pago (`handleGroupScheduledExpenseApproved` enlaza solo la
  real), así que el barrido no puede saber de qué pago vino el borrador de la virtual. Desde el arreglo no nacen
  nuevos; los que ya existan se resuelven a mano eligiendo la categoría. Residual.
- **Un pago planificado sin categoría** sigue pidiéndola al aprobar: el gasto nace sin clasificar y eso es correcto.

## Device-QA (iPhone, build con el arreglo)

1. Planificación → nuevo pago planificado → activa «Gasto compartido», elige un grupo, una cuenta y una
   **categoría**, y pon la fecha de **hoy**. Guarda.
2. Cierra Yala del todo y vuelve a abrirla. En la Bandeja aparece **un** borrador de ese gasto.
3. Ábrelo: en el formulario del grupo la categoría ya viene elegida. Guarda.
4. Vuelve a la Bandeja: **no** aparece ningún borrador nuevo de ese gasto. En Registros, el movimiento tiene la
   categoría del pago.
5. Si antes tenías alguno de esos borradores «elige categoría» de un gasto planificado, tras abrir la app ya no
   está, y su movimiento tiene la categoría del pago.
