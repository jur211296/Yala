---
id: scheduled-payment-actions-name-the-month-they-apply-to
status: qa
priority: high
area: scheduled-payments
created: 2026-11-01
updated: 2026-11-03
source: tablero-pago-planificado-ya-pagado-ya-lo-pague-y-3zva (Jürgen, 2026-11-01 08:52)
---
# Pago planificado ya pagado: «Ya lo pagué» y «Saltar este mes» no decían a qué mes se refieren

## Qué le pasaba al usuario

En el detalle de «Google Workspace Yala» ($17.99 al mes, el día 1), con noviembre ya pagado: la píldora decía «Vence en
30 días · 1 de diciembre», debajo «Noviembre de 2026 ya está pagado», y aun así «Ya lo pagué» y «Saltar este mes»
(«No se apunta nada; los demás meses siguen igual»). No se entendía si eran de noviembre o de diciembre: eran de
diciembre. Jürgen pidió que el mes al que aplican se viera con jerarquía, no solo con un texto más claro.

## Qué se hizo (2026-11-03, encargo 03 de la cola)

- Con el mes en curso ya pagado, encima de los botones va un encabezado con una línea y un titular: «Próximo: diciembre
  de 2026». Los botones dicen «Ya pagué diciembre» y «Saltar diciembre», y la ayuda «No se apunta nada en diciembre; los
  demás meses siguen igual». Si ese mes tiene varias fechas (semanal, diario) se nombra la fecha, porque saltar quita una.
- Se descartó ocultar o bajar de nivel las acciones: pagar por adelantado es legítimo.
- Con el mes en curso sin pagar, todo sigue igual. Con una fecha de un mes anterior vencida y sin pagar, también: no es «Próximo», es atrasada
  (lo cazó la review).
- Bandeja y widget de pagos: medidos, no cambiados. Los dos leen `nextDueDate`, y pagar noviembre lo avanza al 1 de
  diciembre, la misma fecha que el detalle nombra. Lo fija un test de paridad.
- Textos nuevos en los 16 idiomas.

Regla en `ScheduledPaymentDetailLogic.currentMonthSettled` / `actionTarget`. Tests:
`ScheduledPaymentNextMonthActionsTests` y `ScheduledPaymentsLote10UITests#test_monthAlreadyPaid_actionsNameTheNextMonth`.

## Guion de QA en el iPhone (2 min)

1. En Yala, abre Planificación › Pagos y entra en «Google Workspace Yala» (o cualquier pago mensual con el mes en curso
   ya pagado).
2. Debajo de «Noviembre de 2026 ya está pagado» tiene que haber una línea y el titular «Próximo: diciembre de 2026» con
   el icono de calendario.
3. Los botones dicen «Ya pagué diciembre» y «Saltar diciembre»; la ayuda gris nombra diciembre.
4. Entra en un pago con el mes en curso sin pagar: ni encabezado ni textos nuevos («Ya lo pagué», «Saltar este mes»).
5. Mira la Bandeja y el widget de Pagos: el pago ya pagado no aparece como pendiente de noviembre; su próxima fecha es
   el 1 de diciembre.
