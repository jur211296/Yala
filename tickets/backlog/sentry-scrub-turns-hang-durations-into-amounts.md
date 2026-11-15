---
id: sentry-scrub-turns-hang-durations-into-amounts
status: backlog
priority: low
area: stability
created: 2026-11-12
updated: 2026-11-12
source: encargo 2026-11-12-memoria-produccion-yala-ios-b (encontrado por el camino)
---

# La limpieza de Sentry convierte la duración de los cuelgues en «[monto]»

Los títulos de los App Hang llegan como «App hanging between [monto] and [monto] seconds» (YALA-IOS-2, 5, 6, 7, 8, 9,
A, G). La regla de importes de `ErrorReportScrubLogic.scrubText` (una cifra con decimales) se come «2.0 and 3.0
seconds». No filtra nada del usuario, pero borra cuánto duró el cuelgue, que es lo que se quiere saber.

Medido el 2026-11-12 por la API de Sentry (`/organizations/yala-is/events/?query=environment:production`).
Arreglo probable: no aplicar la regla de importes al título de un App Hang, o reconocer «N seconds». Con su test.
