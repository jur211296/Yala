---
id: insights-to-pay-this-month-leaves-out-the-rest-of-the-month
status: backlog
priority: medium
area: estadisticas
created: 2026-10-27
updated: 2026-10-27
source: "ui-suite-2-2-five-tests-red-on-the-base: UXAudit22Lote11DecididasUITests/test_summary_showsWhatYouStillHaveToPay_andBudgetsWithTheirAmounts"
---

# «Lo que te falta pagar» de «Este mes» no cuenta los pagos de los días que quedan

## Qué ve el usuario

En Estadísticas › Resumen, con «Este mes», la sección «Lo que te falta pagar» solo suma los pagos planificados que
vencen **hasta hoy**. Un alquiler que vence el día 28, visto el 27, no aparece: la sección dice que no falta nada, o no
sale. El nombre promete lo contrario: lo que queda por pagar en el período.

## Lo medido (código de `origin/2.2` @ 279d1510b)

- `InsightsCalculator.calculateCommitments` cuenta un pago como pendiente si `interval.contains(payment.nextDueDate)`,
  y `interval` es `DetailPeriod.dateInterval` del período elegido.
- Para los períodos en curso ese intervalo **cierra hoy a las 23:59:59** desde el 2026-10-25 (`cb574f80a`, lote 12.5);
  antes cerraba en la medianoche de mañana. Con cualquiera de los dos, los pagos de los días que quedan del mes se
  quedan fuera.
- Lo destapó el XCUITest de la sección, que solo pasaba los días en que vencía (hoy o mañana) uno de los pagos de la
  semilla `realista` (días 3, 5, 15, 18, 20, 22, 25 y 28). Verde el 22-oct (vencía Netflix el 20 → no; iCloud+ el 22,
  sí), rojo el 23 y del 25 en adelante. El test ya no depende del día: se lanza con `-uitest-scheduled-due-today`.

## La decisión que falta (de Jürgen)

Para un período en curso, ¿«Lo que te falta pagar» cuenta hasta el **final del período** (el 31 en «Este mes») o
hasta hoy? Lo primero es lo que dice el nombre; lo segundo es lo que hace hoy. La cifra es financiera: no se cambia sin
esa respuesta.

## Hecho cuando

La decisión está tomada y, si es «hasta el final del período», el cálculo usa ese fin solo para los pendientes (el resto
de la pantalla sigue cerrando hoy), con un unit test que lo fije en los dos lados de la frontera.
