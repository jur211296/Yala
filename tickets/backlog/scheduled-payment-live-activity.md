---
id: scheduled-payment-live-activity
status: backlog
priority: medium
area: "live-activities, notificaciones"
created: 2026-10-28
updated: 2026-10-28
source: card `tablero-live-activities-presencia-en-pantalla-de-hi45`; informe `docs/live-activities-factibilidad.md`
---

# El día de un pago planificado, marcarlo pagado desde la pantalla de bloqueo

## Qué cambia para el usuario

El día de un pago planificado aparece una tarjeta con el nombre, el importe y un botón «Marcar pagado». Tocar la
tarjeta abre el pago para revisarlo.

## Primero, medir

- Si iOS 26 permite **programar** una Live Activity para que arranque sola a una hora (presentado en WWDC26; firma por
  confirmar en la referencia de ActivityKit). Si existe: la app la deja programada al abrirse, igual que hoy deja las
  notificaciones del día. Si no existe: la tarjeta solo nace cuando el usuario abre Yala ese día, y conviene parar y
  preguntar a Jürgen antes de seguir.
- Plan B (no decidido): abrirla por push desde el gateway. Obliga al servidor a conocer las fechas de pago de cada
  usuario; es decisión de Jürgen.

## Alcance

- Botón «Marcar pagado» con un `LiveActivityIntent` que hace lo mismo que marcarlo dentro de la app, en segundo plano.
- Sin botón (solo tarjeta), si marcar desde segundo plano rompe alguna regla del pago planificado.

## Hecho cuando

- El día del pago la tarjeta aparece sin abrir Yala (o queda documentado por qué no).
- «Marcar pagado» deja el pago marcado y el registro creado, igual que dentro de la app; la tarjeta se cierra.
- Tests del intent y guion de QA.

Versión: 2.4. Factibilidad y límites de la plataforma: `docs/live-activities-factibilidad.md`.
