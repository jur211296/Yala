---
name: revision-html-en-la-max
description: Montar una revisión HTML+PDF en la Max — sin Pillow ni Ghostscript; magick, Chrome headless con marco de 390 px y --print-to-pdf
metadata:
  type: reference
---

En la Max (9-nov-2026, revisión de la zona 41) faltan dos cosas que el molde de las revisiones por vistas daba por hechas:

- **Pillow no está** (`capturas.py` de la zona 39 lo importa). Se convierte con ImageMagick:
  `magick in.png -resize 560x -strip -interlace Plane -quality 72 out.jpg`. `magick montage … -tile 5x1` sirve para hojas
  de contacto rápidas de las capturas.
- **Ghostscript no está**: `magick file.pdf[n]` falla. Para mirar páginas del PDF, la herramienta Read con `pages`.
- **Chrome headless no baja de ~500 px de ventana**: una captura con `--window-size=390,…` recorta la página y parece
  desbordada sin estarlo. Para verla a tamaño teléfono, una página con un `<iframe>` de 390 px y
  `--allow-file-access-from-files`; para medir, `documentElement.scrollWidth` del iframe volcado en el `<title>` con
  `--dump-dom --virtual-time-budget`.
- PDF: `--headless=new --no-pdf-header-footer --print-to-pdf=<ruta> file://<todo.html>` con `--user-data-dir` en el
  scratchpad (no toca el Chrome de Jürgen).

Relacionado: [[verificar-html-y-pdf-con-chromium-de-playwright]] (la alternativa con Playwright), [[capturas-con-conductor-xcuitest]].
