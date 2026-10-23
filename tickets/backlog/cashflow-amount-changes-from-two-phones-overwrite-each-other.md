---
id: cashflow-amount-changes-from-two-phones-overwrite-each-other
status: backlog
priority: low
area: cash-flow-plan
created: 2026-10-21
updated: 2026-10-21
source: review adversarial de L18-8 (lote decidido 2.2 · 10, flujo de caja y reportes)
---

# Dos teléfonos que cambian «desde este mes» la misma línea a la vez se pisan; una versión vieja ve otro plan

**Clase:** límite de diseño aceptado en L18-8, con dos efectos que conviene decidir a sabiendas. No es un bug de hoy.

## Qué puede ver el usuario

1. **Dos cambios a la vez.** En el iPhone A cambia Salario «desde noviembre»; antes de que se sincronice, en el B lo
   cambia «desde enero». Los cambios de una línea viajan en UN solo campo (`CashFlowLine.amountChangesRaw`, iCloud y
   Modo Nube), así que gana el último escrito y el otro se pierde entero.
2. **Una versión vieja en otro teléfono.** Un teléfono con 2.1 no conoce el campo. Si ahí la persona usa «Este mes y
   futuros» (que en 2.1 pasa la línea a monto fijo), el teléfono nuevo sigue aplicando sus cambios «desde este mes» por
   encima del monto fijo: los dos teléfonos enseñan números distintos para los meses siguientes hasta que alguien
   toque «Cambiar» en el nuevo.

## Lo que se sabe

- Inferido leyendo el código (review del 2026-10-21), sin medir con dos teléfonos.
- Es el mismo trato que ya tiene `custom_months_raw`.
- No se pierde dinero: son montos PLANEADOS, no movimientos.

## Qué decidir

Si basta con esto (recomendado mientras 2.1 conviva poco con 2.2), o si los cambios pasan a una fila por mes (modelo
nuevo, esquema de CloudKit y columna del backend nuevos).
