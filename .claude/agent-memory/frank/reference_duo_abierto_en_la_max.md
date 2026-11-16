---
name: duo-abierto-en-la-max
description: Duo abierto en la Max: XCTest captura la interior en negro; se abre por enlace y se captura con simctl; el clic de Device Hub pide la pantalla libre.
metadata:
  type: reference
---

Medido el 2026-11-05 (barrido final 2.2, Max, Xcode 27.2):

- **La Max no trae `axe`.** El recorrido va con un conductor XCUITest temporal (fuera del commit) y la variante por
  entorno (`TEST_RUNNER_*`): `-userTheme 1|8` y `-UIPreferredContentSizeCategoryName …AccessibilityXXXL`.
- **Con el Duo abierto, `XCUIScreen.main` y `app.screenshot()` devuelven NEGRO** (la exterior apagada / la interior no se
  captura desde el runner). Lo que funciona: abrir cada pantalla con `simctl launch` + `-uitest-deeplink` /
  `-uitest-deeplink-url` y capturar con `simctl io <duo> screenshot --display=<UUID de ancho 2007>`. Sin toques.
- **Postura:** Device Hub al frente con el Duo elegido; «abierto» es el último botón de la barra inferior, en (1192, 882)
  con la ventana donde abre (pantalla 1920×1080). Hace falta que Terminal tenga Grabación de pantalla y Accesibilidad.
- **La pantalla de la Max puede estar en uso por Jürgen**: un clic a ciegas cayó en su consola. Antes de pulsar, captura
  la pantalla y, si hay otra ventana al frente, pide al bot que la libere.

Relacionado: [[montar-el-simulador-del-duo]], [[conducir-el-duo-sin-pantalla-propia]].
