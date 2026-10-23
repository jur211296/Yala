---
name: el-video-del-simulador-no-casa-con-el-reloj
description: simctl recordVideo solo escribe fotogramas cuando cambia la pantalla; recortar por hora del reloj sale corrido. Graba solo el tramo con apretón de manos test↔host
metadata:
  type: feedback
---

Al regrabar los vídeos de Tutoriales (2026-10-22) recorté el `.mov` de `simctl io recordVideo` por la hora en que el
test marcaba inicio y fin. Dos intentos salieron corridos ~2 s (vídeos que acababan en la pantalla de inicio): ni la hora
de lanzar el grabador ni «hora de parar − duración del vídeo» dan el cero del vídeo. Medido: 5 s con la pantalla quieta
dan un vídeo de **0,07 s**. simctl solo escribe un fotograma cuando la pantalla cambia.

**Why:** el tiempo del vídeo no es el del reloj del Mac; cualquier tramo quieto (las pausas que pones para que se lea)
no existe en el fichero.

**How to apply:** no recortes después: graba SOLO el tramo. El test escribe `<caso>.start` y espera `.go`; el host
arranca el grabador al ver la marca, espera 1 s y contesta; al `.end`, para y contesta `.done`. Al componer, `tpad`
clona el último fotograma y `-t` fija la duración medida en el host. Molde en `qa/scripts/tutorial-videos/record.sh` +
`YalaUITests/Flows/TutorialVideoRecordingUITests.swift`. Relacionado: [[el-video-del-simulador-salta-pantallas-cortas]].
