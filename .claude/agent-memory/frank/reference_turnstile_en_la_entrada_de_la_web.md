---
name: turnstile-en-la-entrada-de-la-web
description: Probar la entrada de Yala web sin cabeza: Turnstile vive en shadow DOM cerrado; staging pasa solo, producción reta al bot y la prueba con sesión es de Jürgen.
metadata:
  type: reference
---

Medido el 2026-11-17 (lote 6, la entrada):

- **El widget de Turnstile no se alcanza con selectores** (shadow DOM cerrado): `waitForSelector("iframe[src*=challenges…]")`
  nunca casa aunque el reto se vea. Se espera con un tiempo fijo (~4,5 s) y se mira la captura.
- **Para ver el reto en una captura local**, `/api/config` interceptado con la clave de prueba `3x00000000000000000000FF`
  (siempre pide interacción); para que los botones se enciendan, `1x00000000000000000000AA` (siempre pasa).
  `herramientas/capturar-lote-6.mjs` ya lo hace.
- **Staging usa claves de prueba que pasan solas**: el recorrido sin cabeza llega a Apple, Google y el QR.
- **Producción reta al Chromium sin cabeza** («Verifique que es un ser humano») y los botones no se encienden. No se salta:
  en producción solo se mide lo servido (hash del `index-*.js` igual al build, rutas 200, `/api/me` 401) y la prueba con
  sesión queda en «Necesita de ti» para Jürgen.
- **El e2e entero tras muchas entradas seguidas** tumba 4 casos en ~100 ms; solos pasan (límite de entradas, inferido).
  Corre el e2e ANTES del recorrido, o espera unos minutos.

Relacionado: [[secretos-de-staging-en-la-mini]], [[web-parecida-a-la-app]].
