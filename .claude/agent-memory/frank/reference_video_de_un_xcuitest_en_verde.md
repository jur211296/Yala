---
name: video-de-un-xcuitest-en-verde
description: Un XCUITest en verde no deja vídeo en el .xcresult; para el «después» de un PR se graba el simulador con simctl io recordVideo alrededor de la corrida
metadata:
  type: reference
---

El `.xcresult` solo guarda la grabación de pantalla de los casos que FALLAN: el «antes» de un bug sale gratis del rojo
(`xcresulttool export attachments`), el «después» en verde no trae ningún `.mp4`.

**Why:** 2026-11-03, bug de «Convertir a gasto compartido» desde voz e imagen: el export del verde salió vacío.

**How to apply:** para el vídeo del «después», `xcrun simctl io <udid> recordVideo --codec h264 --force <out>.mp4 &`,
la corrida con `sim-lock.sh`, `kill -INT` al grabador. Recorta el inicio (pantalla de inicio quieta) con `ffmpeg -ss`
y comprime (`scale=360:-2,fps=15,-crf 32`): de 120 MB a <1 MB, cabe en `qa/evidencia-*/` y se enlaza en el PR.
Relacionado: [[ver-un-fallo-de-xcuitest-en-video]].
