---
id: 2026-11-20-hoja-y-nota-difieren-con-pagos-apuntados-a-futuro
status: done
priority: low
area: "panel, salud-financiera"
created: 2026-11-20
updated: 2026-11-22
source: revisor con checklist del gate de la hoja de Salud financiera en tres secciones (fuera de la checklist)
---
# Hoja y nota de Compromisos difieren con un pago apuntado a fecha futura

La hoja compara «Tu dinero hoy» con corte de HOY (la cifra del hero del Panel, `LiveBalanceCalculator.TodayCutoff`) con lo
que falta pagar este mes. La nota usa las mismas cuentas pero con `asOf: .distantFuture` (regla de `currency-fx.md`: lo
pendiente ya descuenta lo pagado con un movimiento enlazado aunque esté fechado después).

Escenario: el alquiler se apunta hoy con fecha 25 y queda enlazado a su pago planificado. Sale de lo pendiente en las dos;
la nota lo resta del dinero y la hoja no, así que la hoja dice «Te alcanza» con ese importe de más y la nota puede bajar.

Hecho cuando: la hoja cuenta lo apuntado a futuro de este mes en las cuentas de «Tu dinero hoy» (como línea o restándolo
de la comparación) sin cambiar la cifra del hero, o se decide aceptar la diferencia.

## Resuelto (2026-11-22)

Opción «restarlo de la comparación» + línea secundaria. «Tu dinero hoy» (barra y frase) sigue siendo la cifra del hero;
la diferencia («Te alcanza» / «Te faltarían») suma lo apuntado con fecha posterior a hoy en las mismas cuentas
(`Comparacion.apuntadoFuturo`, medido como la nota con `asOf: .distantFuture`) y una línea lo dice («Ya descontamos S/ X
que apuntaste con fecha más adelante», 16 idiomas). Test de paridad hoja/nota en `YalaTests/FaltaPagarCompromisos/`.
