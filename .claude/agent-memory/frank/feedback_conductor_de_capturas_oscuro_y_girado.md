---
name: feedback-conductor-de-capturas-oscuro-y-girado
description: conductor XCUITest de capturas — con -userTheme 1 el oscuro sale claro; girado, app.screenshot() sale mal orientada; usar XCUIScreen y rotar con sips
metadata:
  type: feedback
---

Dos fallos de método que costaron una vuelta de capturas cada uno (2026-11-24, pagos planificados):

- **`-userTheme 1` (tema Claro de Yala) gana a `XCUIDevice.shared.appearance = .dark`**: la tanda «oscuro» sale clara.
  En oscuro, no pasar `-userTheme`. Ver [[reference-tema-claro-de-yala-en-el-simulador]].
- Girado: ya estaba escrito en [[reference-capturas-giradas-en-xcuitest]] y lo volví a pisar por no mirar el índice
  antes de escribir el conductor (`sips -r 270` lo endereza).
- Girado, seis `swipeUp(.fast)` no llegaron al final de la lista: el final se prueba en vertical.

**Why:** cada fallo se ve solo al abrir las PNG; mirar al menos una por variante antes de dar la tanda por buena.
**How to apply:** en todo conductor de capturas nuevo con variantes de tema y orientación.
