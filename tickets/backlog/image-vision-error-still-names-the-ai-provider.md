---
id: image-vision-error-still-names-the-ai-provider
status: backlog
priority: low
area: ai
created: 2026-10-21
updated: 2026-10-21
source: review del lote decidido 2.2 · 11 (fuera del lote)
---

# Un error de la foto todavía nombra al proveedor de IA

`ImageVisionService` (≈ línea 82) devuelve «OpenAI API key not configured» como `errorDescription`, en inglés. Si algún
camino enseña `localizedDescription` al usuario, la app nombra al proveedor, cuando la norma es decir «un servicio de IA»
(el único sitio que lo nombra es la política de privacidad). Solo pasa sin clave configurada (build mal firmado o de
desarrollo), así que es baja. No se midió si llega a pantalla.
