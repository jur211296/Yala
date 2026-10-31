---
name: conducir-el-duo-sin-pantalla-propia
description: Duo por Device Hub en sesión lanzada: screencapture solo vía osascript; el carrusel no se arrastra (scrollea la página): reordénalo por argumento; abierto = horizontal con dos columnas.
metadata:
  type: reference
---

Medido el 2026-10-30 (S29, capturas App Store 2.2, Xcode 27.1, runtime 27.1 en la Mini):

- **`screencapture` directo falla** («could not create image from display») en una sesión lanzada; envuelto en
  `osascript -e 'do shell script "screencapture -x …"'` funciona. `mapa()` de `duo/comun.sh` lo llama directo:
  redefínela en tu conductor. Los clics de `clic` sí llegan sin envoltorio.
- **El árbol de `axe` del Duo abierto va en puntos 951×669** (Application dice 669×951, vertical). Un `arrastra`
  horizontal sobre el carrusel de «Tus finanzas» **desplazó la página en vertical**; 5 intentos, el carrusel no se
  movió. Lo que funcionó: relanzar con `-accountsSortOrderNames "<cuenta>|…"` detrás de los de `lanzar.sh` (el
  último gana) para que la tarjeta buscada sea la primera.
- **Estadísticas abre en «Resumen»**: toca `|detail_chip_categorías|` y después la etiqueta `Gráficas|`
  (`distribution_content_mode`).
- **Abierto = horizontal (2853×2007)**, con barra vertical y dos columnas: es el layout útil en la 2.2.

Relacionado: [[montar-el-simulador-del-duo]], [[conducir-simulador-con-axe]], [[molde-ficha-app-store]].

Medido el 2026-10-30 (S29c, avatar en la barra lateral del Duo abierto):

- **XCUITest sí corre en el Duo y discrimina**: `xcodebuild test-without-building -xctestrun <…27.1….xctestrun>
  -destination id=<duo>` con la postura puesta antes en Device Hub. El `XCUIDevice.orientation = .portrait` del `setUp`
  de `AdaptiveNavigationUITests` **no** lo sacó de abierto en horizontal. Leer marcos (no tocar) basta para un veredicto.
- **Los ids de las pantallas cambian en cada arranque** del Duo: resuélvelos por ancho nativo (2007 interior, 1398
  exterior) con `simctl io <duo> enumerate` cada vez; uno guardado de antes da «screenshot» sin fichero y sin error.
- **Tras arrancar, el Duo vuelve a cerrado** aunque lo apagaras abierto: pon la postura otra vez.
- **El `clic` de `~/Library/Caches/Yala/ficha/` puede desaparecer** a mitad de sesión (lo barrió otra): compílalo al
  scratchpad con `swiftc -O ficha-app-store/duo/clic.swift`.
