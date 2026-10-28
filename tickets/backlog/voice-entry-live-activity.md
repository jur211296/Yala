---
id: voice-entry-live-activity
status: backlog
priority: low
area: "live-activities, notificaciones"
created: 2026-10-28
updated: 2026-10-28
source: card `tablero-live-activities-presencia-en-pantalla-de-hi45`; informe `docs/live-activities-factibilidad.md`
---

# El registro por voz sigue en la isla al salir de Yala

## Qué cambia para el usuario

Mientras se graba un registro por voz, al salir de Yala o bloquear el iPhone la isla dice «Escuchando…» con el tiempo
que corre, y tiene Listo y Cancelar. Vale entre por donde entre (control del Centro de control, Atajo, botón de la
pantalla de bloqueo o dentro de la app).

## Límites

- La onda que sigue la voz no cabe: la tarjeta no se repinta a ese ritmo. Sí un indicador que late o el reloj.
- Seguir grabando con Yala en segundo plano pide declarar audio en segundo plano y justificarlo en la revisión de Apple.
  Hoy no está declarado.

## Hecho cuando

- Empezar a grabar, salir de Yala: la isla y la pantalla de bloqueo muestran la grabación con el tiempo.
- Listo procesa como hoy y lleva a «Esto entendí»; Cancelar descarta.
- La revisión de Apple acepta el modo de audio (o el ticket se queda solo en «tarjeta mientras la app está delante»).
- Guion de QA en iPhone.

Versión: 2.4. Factibilidad y límites de la plataforma: `docs/live-activities-factibilidad.md`.
