---
id: sentry-scrub-turns-hang-durations-into-amounts
status: done
priority: low
area: stability
created: 2026-11-12
updated: 2026-11-21
source: encargo 2026-11-12-memoria-produccion-yala-ios-b (encontrado por el camino)
---

# La limpieza de Sentry convierte la duración de los cuelgues en «[monto]»

Los títulos de los App Hang llegan como «App hanging between [monto] and [monto] seconds» (YALA-IOS-2, 5, 6, 7, 8, 9,
A, G). La regla de importes de `ErrorReportScrubLogic.scrubText` (una cifra con decimales) se come «2.0 and 3.0
seconds». No filtra nada del usuario, pero borra cuánto duró el cuelgue, que es lo que se quiere saber.

Medido el 2026-11-12 por la API de Sentry (`/organizations/yala-is/events/?query=environment:production`).
Arreglo probable: no aplicar la regla de importes al título de un App Hang, o reconocer «N seconds». Con su test.

## Cierre (2026-11-21)

Cerrado con `2026-11-20-sentry-avisos-afinar`: la regla de importes ya no tapa la cifra a la que siguen «seconds» o
«and <cifra> seconds». Medido en Sentry: el cuelgue de prueba YALA-IOS-17 llegó como «App hanging between 4.5 and
5.3 seconds». Tests en `ErrorReportScrubLogicTests` (los segundos se ven; un importe al lado se sigue tapando).
