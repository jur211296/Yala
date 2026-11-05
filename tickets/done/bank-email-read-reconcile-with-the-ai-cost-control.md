---
id: bank-email-read-reconcile-with-the-ai-cost-control
status: done
priority: high
area: "gateway, ai"
created: 2026-11-04
updated: 2026-11-04
source: "encargo S2 (correo del banco), decisión de Jürgen del 2026-11-04: opción B"
---

# Reconciliar la lectura del correo con el control del coste de la IA (S1)

La lectura del correo vive fuera de `gateway/src/ai/` (`gateway/src/mail/read.ts`) porque S1 tenía esa carpeta y
esperaba una decisión. Lleva su propia fila (`MAIL_READ_ROUTE`) y su propio tope (`MAIL_READ_MAX_OUTPUT_TOKENS = 400`,
entrada recortada a 6.000 caracteres). El uso de tokens solo se loguea (`[mail] read tokens_in=… tokens_out=…`).

## Hecho al rebasar (2026-11-04)

S1 entró en 2.3 mientras esta sesión trabajaba, y la reconciliación se hizo en el mismo PR:

- [x] El uso de tokens se registra por el camino de S1: `recordUsage(usageSink(env), usageRecord({task: "mail.read",
  category: "mail", …}))` en `gateway/src/mail/email.ts`. Sin nada del correo (test).
- [x] El tope: `maxOutputTokens: 400`, como exige S1 para toda llamada de chat.
- [ ] ~~Pasar la fila a `ROUTES` como tarea `mail.read`~~ — descartado a propósito: `TASKS` es también la lista de lo
  que la app puede pedir por el proxy con `X-Yala-Task`, y esta lectura solo la lanza el servidor. Regla en
  `.claude/rules/ai-gateway.md`.
