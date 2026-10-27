---
id: groups-only-by-choice-holds-group-scheduled-payments
status: done
priority: medium
area: "groups, scheduled-payments"
created: 2026-10-26
updated: 2026-10-27
source: "review adversarial de la card p0iu (completa ↔ solo grupos)"
---

# En «Solo grupos» se pausan también los pagos programados de grupo

En «Solo grupos» sobre Yala completo se pausan todos los pagos programados, también los de grupo: sus borradores no se
crean, así que el gasto compartido no llega al grupo hasta que la persona vuelve y lo aprueba, y los saldos de los demás
esperan. Decisión de producto pendiente: ¿los pagos de grupo deberían seguir?

## Decisión de Jürgen (2026-10-27)

Se pausan también los de grupo. Al volver a Yala completo **no aparecen de golpe**: siguen suspendidos hasta su ciclo
normal. Ampliada en el Paso 0 del encargo S11e: lo mismo para los pagos programados personales (una sola regla para la
pausa). Los de pago único sí salen al volver, porque no tienen próxima fecha.

## Hecho (encargo S11e)

- Al volver, `UsageModeService.returnToFull` llama antes a `ScheduledPaymentDraftService.skipOccurrencesMissedDuringPause`:
  cada pago recurrente cuyo vencimiento cayó entre el día en que empezó la pausa y ayer pasa a su primer vencimiento
  desde hoy, sin borrador. Lo de hoy sale normal.
- La marca de «Solo grupos» apunta cuándo empezó la pausa (`GroupsOnlyViewMark.since`) y la fecha muere con ella.
- Un borrador que ya estaba pendiente (de antes de la pausa, o del iPad en Yala completo) se queda, y lo de la pausa
  que venía detrás se salta: aprobarlo o descartarlo con la fecha ya por delante no la vuelve a avanzar. Un vencimiento
  de antes de la pausa que nunca salió, sale al volver; lo de la pausa que venía detrás, no. Lo cazó la review
  adversarial: la primera versión dejaba salir lo de la pausa uno a uno detrás de ese borrador.
- Avanza `nextDueDate`, no marca fechas saltadas: esas viajan y archivarían borradores que el iPad sí sacó.
- Residual: si antes de la pausa ya había DOS o más vencimientos atrasados sin salir, después de esos sale lo de la
  pausa uno a uno, como antes.
- Tests: `UsageModePausedPaymentsTests` (con control sin el salto), `UsageModePausedPaymentsLogicTests`, el cableado en
  `UsageModeWiringTests`.

Sin device-QA: lo fijan los tests de servicio con el store real.
