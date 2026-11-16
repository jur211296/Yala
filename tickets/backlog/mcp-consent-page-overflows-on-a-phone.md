---
id: mcp-consent-page-overflows-on-a-phone
status: backlog
priority: low
area: mcp
created: 2026-11-05
updated: 2026-11-05
source: encargo 2026-11-05-tu-ia-registra-en-yala (hallazgo al capturar la pantalla de permiso)
---

# La pantalla de permiso del conector se sale por la derecha en un teléfono

## Qué ve el usuario

Al conectar Yala desde Claude o ChatGPT en el móvil, la tarjeta del permiso es más ancha que la pantalla: el final de
cada línea y el botón «Continuar» quedan cortados y hay que desplazar de lado.

## Medido

Renderizada con Chrome sin ventana a 390 pt de ancho (2026-11-05), la tarjeta se corta por la derecha. La causa, en
`mcp/src/pages.ts` (estilos de `page()`): `main` lleva `width:100%` y `padding:24px` sin `box-sizing:border-box`, así
que mide el ancho disponible más 48 px. Ya estaba así antes del encargo «Tu IA registra en Yala»: esos estilos no cambiaron (`git show` de la base). Arreglo probable: `box-sizing:border-box` en `main`; comprobarlo en un iPhone real.
