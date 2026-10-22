# Mini sesión: AskUserQuestion ticket a ticket del rediseño de sesiones — sin implementar

## Contexto
Jürgen 2026-09-09/10: antes de dejar la cola autónoma del rediseño de sesiones (PR #125 / ADR + runbook), quiere **todas** las decisiones preguntadas.

Fuente de orden: runbook `session-redesign-implementation-order` (y los tickets que lista el ADR/spec del #125). Léelo primero; no inventes otro orden.

## Que se pide
1. Recorre **cada ticket** del orden de implementación, uno a uno.
2. Por cada ticket: lee solo ese ticket (+ ADR/sección mínima si hace falta). Identifica **cualquier** ambigüedad, supuesto, borde, copy, prioridad de migración, flags, compatibilidad, criterios de hecho, etc.
3. Usa **AskUserQuestion** para preguntar. Preferencia de Jürgen: pregunta **aunque sea mínima** — no queremos errores por supuestos. Si un ticket no tiene nada que preguntar, dilo en una línea y pasa al siguiente (excepción rara).
4. Acumula las respuestas en un sitio durable del repo (p.ej. sección en el ticket, o un `docs/…` de desbloqueo del rediseño — elige lo que el repo use; actualiza board/`docs/TICKETS.md` si aplica).
5. **NO implementes código de producto.** Solo preguntas + registro de respuestas.
6. Al terminar todos: resumen para Jürgen (ticket → decisiones tomadas) y `/cerrar-total` si hay commits de docs; o cierra limpio.

## Modo conversación
Jürgen responde en la ventana. Frank solo retransmite si hace falta. No armes un guion de Device-QA. No leas el board entero.

## Como se sabe que esta bien
- Todos los tickets del runbook pasaron por la pasada de preguntas.
- Respuestas registradas y citables para la cola autónoma.
- Cero implementación de features.

## Avisos a Frank
Webhook Avisos Claude cuando: (1) bloqueado sin AskUserQuestion posible; (2) PR docs; (3) /cerrar-total con resumen «listo para autónomo»; (4) idle — una vez.
