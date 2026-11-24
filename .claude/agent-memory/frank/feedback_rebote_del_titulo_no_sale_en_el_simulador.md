---
name: rebote-del-titulo-no-sale-en-el-simulador
description: El vaivén del título grande en el umbral (Reportes, 23-nov) no se reproduce en el simulador con XCUITest ni Device MCP; se mide en el vídeo del iPhone siguiendo la y de un chip
metadata:
  type: feedback
---

El rebote de Reportes (título grande ↔ compacto, chips saltando 127 ↔ 179 pt cada ~1 s) NO salió en el simulador
(24-nov-2026, iOS 27.2) con ninguno de estos gestos: `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`
de XCUITest a 12-90 pt, arrastre lento de 140 pt a 12 pt/s, `drag` de Device MCP de 9 s, ni `draw` con temblor de ±1,5 pt
(lo simplifica y no tiembla) o ±3 pt. En el simulador el título se pliega con una animación de ~0,15-0,4 s y queda
quieto. Lo que sí sirvió: medir el vídeo de Jürgen con un script que sigue la y del chip elegido por fotograma
(columna de 6 px en x=24 pt, tramo de píxeles de acento ≥ 22 pt; ffmpeg + numpy): dio 24 vaivenes y la causa.

**Why:** se gastaron ~25 min de pruebas de interfaz intentando reproducirlo; el presupuesto es de 30.

**How to apply:** ante un bucle de layout que Jürgen grabó en el iPhone, mide primero su vídeo por fotograma y no
persigas la reproducción sintética más de una corrida; si el iPhone 14 no está conectado, arregla por construcción y
deja guion de device-QA. Ver [[un-sintoma-visual-se-pregunta-con-opciones-pronto]].
