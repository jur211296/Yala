---
id: inbox-success-says-transaction-created
status: done
priority: low
area: "inbox, copy"
created: 2026-10-14
updated: 2026-11-05
card: tablero-pagos-planificados-adelantar-gasto-ofrec-flvl
source: "auditoría UX 2.2 · lote 10 (pagos planificados)"
---

# La pantalla de éxito al aprobar un borrador dice «Transacción creada» y ofrece «Aprobar siguiente» también al venir de Pagos

Medido el 2026-10-14 al «Adelantar gasto» un pago planificado (lote 10, captura `10.8-02-tras-aprobar.png`): tras aprobar sale «Transacción creada» (BRAND-VOICE prohíbe «transacción») y un botón «Aprobar siguiente» que lleva a otros borradores de la Bandeja, aunque la persona venía del detalle de un pago. Es pantalla de la Bandeja (lote 4); no se tocó por alcance.

## Hecho cuando

Dice «Gasto guardado» (o «Ingreso guardado») y, abierta desde Pagos, vuelve al pago sin ofrecer otros borradores.

## Resolución (2026-11-05, lote P1)

Ya estaba arreglado en código por el lote 10 (18-oct, después de abrir este ticket): «Adelantar gasto» pasó a «Pagar
ahora», abre el formulario con `payNowTitle` y al guardar vuelve al detalle del pago, sin pantalla de éxito ni «Guardar el
siguiente» (`InboxDraftEditSheet.approve`). La Bandeja ya no dice «Transacción» («registro guardado»). Faltaba el test:
`ScheduledPaymentsLoteP1UITests#test_payNow_savesAndReturnsToThePayment_withoutTheInboxSuccessScreen`, rojo con la vuelta
al pago quitada (mutante) y verde con el código.
