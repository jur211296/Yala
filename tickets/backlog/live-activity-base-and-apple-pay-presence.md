---
id: live-activity-base-and-apple-pay-presence
status: backlog
priority: high
area: "live-activities, notificaciones"
created: 2026-10-28
updated: 2026-10-28
source: card `tablero-live-activities-presencia-en-pantalla-de-hi45`; informe `docs/live-activities-factibilidad.md`
---

# Tras Apple Pay, la pantalla de bloqueo dice «Registramos tu gasto»

## Qué cambia para el usuario

Después de pagar con Apple Pay, en vez de solo la notificación aparece una tarjeta en la pantalla de bloqueo y la isla:
«Registramos tu gasto», el importe, el comercio y lo que falta (cuenta, categoría). Con un chevron; tocarla abre la
Bandeja, igual que la notificación de hoy. A los 5 minutos sin tocarla se va y queda la notificación de siempre.

## Alcance

- Base común para los demás tickets: `NSSupportsLiveActivities`, la tarjeta en `YalaWidgets`, un servicio único que
  abre, actualiza y cierra, y el patrón «tarjeta 5 min → notificación de respaldo» (se cancela si se usó la tarjeta).
- Si el usuario apagó las Live Activities de Yala, o la plataforma rechaza abrirla, sale la notificación de hoy.
- Yala solo en grupos: mismo bloqueo que hoy, sin tarjeta.

## Primero, medir (en el iPhone; el simulador no corre automatizaciones de Wallet)

1. `ApplePayTransactionIntent` adoptando `LiveActivityIntent` abre la tarjeta con Yala cerrada. Si no, el ticket se
   queda en la notificación y se dice por qué.
2. A los 5 minutos: tarjeta terminada (sale de la isla) frente a caducada (`staleDate`, se queda gris). Elige Jürgen
   con capturas.

## Hecho cuando

- Pago con Apple Pay con Yala cerrada → tarjeta visible en pantalla de bloqueo e isla con importe y lo que falta.
- Tocarla abre la Bandeja en el borrador.
- Sin tocarla, a los 5 minutos queda solo la notificación; tocándola antes, no llega la notificación.
- Live Activities apagadas en Ajustes → notificación de hoy, sin error.
- Tests del servicio (abrir/cerrar/respaldo) y guion de QA en iPhone.

Versión: 2.4. Factibilidad y límites de la plataforma: `docs/live-activities-factibilidad.md`.
