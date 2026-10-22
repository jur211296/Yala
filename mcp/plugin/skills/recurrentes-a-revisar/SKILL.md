---
name: recurrentes-a-revisar
description: Qué paga el usuario de Yala cada mes y cada año en suscripciones y pagos recurrentes, y cuáles conviene revisar. Úsala con «¿qué pago cada mes?», «¿cuánto se me va en suscripciones?» o «¿qué podría cancelar?».
---

# Recurrentes a revisar

1. Llama a `listar_recurrentes`.
2. Da el total: `totales_gasto.total_mensual` y `total_anual`, separando suscripciones y recurrentes.
3. Lista los pagos de mayor a menor equivalente mensual. Para cada uno: nombre, importe, frecuencia y cuánto
   supone al año.
4. Después, los que traen algo en `revisar`, con el hecho que lo explica:
   - `sin_movimiento_reciente`: no hay movimientos enlazados a este pago en más de dos ciclos.
   - `proximo_cobro_vencido`: la fecha del próximo cobro ya pasó y la app no la adelantó.
5. Cierra con la pregunta que decide el usuario: si sigue usando esos servicios.

Terminado: el usuario conoce su gasto fijo mensual y anual, y qué pagos revisar con el motivo de cada uno.

Yala sabe qué se paga, no si se usa. Por eso esta skill habla de pagos «a revisar» y deja que el usuario
diga si el servicio sigue sirviéndole.
