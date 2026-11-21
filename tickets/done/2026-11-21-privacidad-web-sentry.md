---
id: 2026-11-21-privacidad-web-sentry
status: done
priority: medium
area: "web, privacidad"
created: 2026-11-21
updated: 2026-11-21
source: "decisión de Jürgen 21-nov 05:54 sobre el artifact de Sentry afinado"
---

# La política de privacidad de la web decía que Yala no usa reporte de fallos

La viñeta 3 de «11. Lo que NO hacemos» negaba los SDKs de reporte de fallos, y la app usa Sentry desde octubre. Jürgen aprobó el 21-nov el texto que lo reconoce (artifact 6577uHQk2fSxJoCEdEWvks).

## Hecho cuando

yala-app.pe/privacy y sus cinco traducciones muestran el texto nuevo, y `2.3` lleva el mismo cambio.

## Resolución (2026-11-21)

`privacyNotDoBullet3` de `Web/src/i18n/translations.ts`, en los seis idiomas, con el texto aprobado. Un PR contra `1.0` (lo publica Vercel) y el mismo commit en `2.3`. Se conservó el texto aprobado aunque la viñeta afirmativa quede bajo «Lo que NO hacemos». La sección 8 («no usamos ningún SDK de analítica de terceros») sigue siendo cierta y no se tocó.
