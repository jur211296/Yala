---
name: verificar-html-y-pdf-con-chromium-de-playwright
description: En la Mini no hay Chrome ni el módulo playwright, pero sí el Chromium headless de su caché: sirve para capturas a 390/1280, detectar desborde lateral e imprimir el PDF de una revisión.
metadata:
  type: reference
---

Para verificar una revisión HTML (docs/ux/…) sin abrir Chrome: el binario
`~/Library/Caches/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-mac-arm64/chrome-headless-shell`.

- Captura: `--headless --hide-scrollbars --window-size=390,1600 --force-device-scale-factor=2 --screenshot=<png> file://…`.
- Desborde lateral: copia temporal de la página con un `<script>` que escribe `document.documentElement.scrollWidth` en un
  atributo del `body`, y `--dump-dom --virtual-time-budget=3000`; 390 = sin scroll lateral.
- PDF: `build.py --todo <html>` y `--no-pdf-header-footer --virtual-time-budget=8000 --print-to-pdf=<pdf>`.
- Revisar el PDF: `pdftoppm -r 40 -png` (sí está); `magick montage` falla sin ghostscript: montar con PIL.

Medido el 2026-11-09 en la revisión de la zona 40. Ver también [[maquetas-con-piezas-reales-de-la-app]].
