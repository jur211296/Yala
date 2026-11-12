---
name: ver-un-fallo-de-xcuitest-en-video
description: Un rojo de XCUITest se VE sacando el último fotograma del vídeo del .xcresult con ffmpeg; los .txt adjuntos son volcados del elemento, no de la pantalla.
metadata:
  type: reference
---

Con `-resultBundlePath`, `xcrun xcresulttool export attachments --path <bundle> --output-path <dir>` deja un
`manifest.json` (test → adjuntos), un `.mp4` por test con la grabación de pantalla, `.txt` con el volcado del elemento
que se esperaba (su `label`, su marco) y plists. **No hay PNG.** Lo que de verdad se ve está en el vídeo:
`ffmpeg -loglevel error -sseof -1 -i <mp4> -frames:v 1 -vf scale=300:-1 last.jpg` (y `-sseof -9`, `-6`, `-3` en tira con
`hstack` para ver la secuencia).

**Why:** el 2026-10-22 dos rojos del formulario se leían como bugs de la app y eran del test: el aviso «¿Era de
prueba?» se comía los 5 s del aviso tras guardar, y una cuenta nueva no se guardaba porque el test no escribía el saldo
inicial obligatorio. El volcado `.txt` decía «el chip existe con label Destino», que con hojas encima no prueba nada
([[axe-no-ve-las-hojas]]). Dos fotogramas lo resolvieron.

**How to apply:** ante un rojo de XCUITest sin causa obvia, antes de reproducir a mano (que ensucia el teclado del
simulador), corre con `-resultBundlePath` y mira el vídeo.
