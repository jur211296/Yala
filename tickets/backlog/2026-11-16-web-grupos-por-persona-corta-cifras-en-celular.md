---
id: 2026-11-16-web-grupos-por-persona-corta-cifras-en-celular
status: backlog
priority: low
area: web
created: 2026-11-16
updated: 2026-11-16
source: hallazgo del lote 5 de «Yala web como la app»
---
# Yala web: «Por persona» de un grupo corta las cifras en el celular

En el detalle de un grupo, a 390 px, la tabla «Por persona» (Pagó, Le toca, Saldo) corta las cifras con puntos
suspensivos («S/ 1,840.…»). Ya pasaba antes del lote 5 (capturas `antes-grupo-*-movil` y `despues-grupo-*-movil` en
`docs/web-app/parecida-a-la-app/capturas/lote-5/`). Propuesta: en el celular, una fila por persona con el saldo a la
derecha y Pagó / Le toca debajo, como la app.
