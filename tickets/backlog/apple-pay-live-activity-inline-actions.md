---
id: apple-pay-live-activity-inline-actions
status: backlog
priority: low
area: "live-activities, notificaciones"
created: 2026-10-28
updated: 2026-10-28
source: card `tablero-live-activities-presencia-en-pantalla-de-hi45`; informe `docs/live-activities-factibilidad.md`
---

# Completar y guardar el gasto de Apple Pay sin abrir Yala

## Qué cambia para el usuario

En la tarjeta de Apple Pay, además de abrir la Bandeja, dos o tres botones con sugerencias (la cuenta habitual de Apple
Pay, la categoría más probable) y «Guardar», que registra el gasto sin abrir la app.

## Por qué va aparte y detrás

- Una Live Activity solo admite botones: nada de selectores ni listas. Elegir cualquier cuenta o subcategoría sigue
  siendo de la Bandeja.
- Para guardar con Yala cerrada, el botón tiene que crear el registro desde segundo plano, cuando hoy el intent de
  Apple Pay deja el pago en una cola y no toca la base de datos a propósito.
- Espera a ver el ticket `live-activity-base-and-apple-pay-presence` en uso: si la tarjeta y el toque a la Bandeja ya
  resuelven, este sobra.

## Hecho cuando

- Elegir una sugerencia y Guardar crea el registro igual que aprobarlo en la Bandeja; no queda borrador duplicado.
- Sin sugerencia fiable, la tarjeta no ofrece Guardar.
- Tests del intent y de la deduplicación con la cola; guion de QA.

Versión: 2.4. Factibilidad y límites de la plataforma: `docs/live-activities-factibilidad.md`.
