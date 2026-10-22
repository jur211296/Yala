---
name: capturas-simulador-para-la-web
description: Receta y trampas medidas el 2026-09-04 al sacar del simulador el set de capturas de la web (ES y EN)
metadata:
  type: feedback
---

**Para sacar capturas de marketing del simulador, esta receta funciona** (medida el 2026-09-04; el set
vive en `Web/Screenshots/v3-2026-09-04/` con su README):

1. Copiar `Secrets.xcconfig` del árbol principal: **un worktree no lo tiene** (está en `.gitignore`) y sin
   él el build falla con «Unable to open base configuration reference file».
2. `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100
   --wifiBars 3 --cellularBars 4` y `ui <udid> appearance dark`. Al terminar, `status_bar clear`.
3. Lanzar con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed grupos`. La semilla
   es determinista (`SeededRandom(42)`): las mismas cifras en cada corrida, así el copy puede citarlas.

**Las trampas, todas medidas:**

- **El nombre de usuario NO sobrevive al relanzamiento** bajo `-uitest` (defaults efímeros, ver
  `UITestEphemeralDefaults.swift`). Y el nombre solo se propaga a tu fila en un grupo si **cambia** con la
  app abierta y antes de que la pantalla de Grupos se cargue por primera vez. Si relanzas, en Balances
  vuelves a salir como «Tú». Orden que funciona: lanzar → poner el nombre → abrir Grupos → capturar.
- **Las categorías son datos sembrados, no interfaz**: cambiar el idioma del simulador no las traduce. Para
  capturas en otro idioma hay que **volver a sembrar** con el simulador ya en ese idioma
  (`defaults write -g AppleLanguages -array en-US` + relanzar con `-uitest-reset -uitest-seed`).
- **El árbol de accesibilidad se degrada** tras muchos ciclos (snapshot devuelve `count: 1` y los gestos ya
  no llegan al scroll). Lo cura relanzar la app, no esperar.
- **`sips -Z N` escala el lado LARGO.** Para capturas verticales usa `--resampleWidth N` o acabas con
  395×860 en vez de 620×1348.
- **El período por defecto es «Todo el tiempo»** y al día 4 del mes «Este mes» son 14 movimientos: para
  marketing, «Últimos 30 días» cuenta mejor y es igual de cierto.

**Why:** el set anterior de la web venía de una versión previa de la app y sus cifras no salían de ninguna
pantalla concreta; al medir aparecieron dos afirmaciones falsas en el copy (el formulario de registro no
interpreta lenguaje libre; el Panel ya no saluda por nombre).

**How to apply:** cualquier tanda de capturas para `Web/` o para Lola. Y la regla general que dejó:
**antes de escribir en la web que la app hace algo, hazlo en el simulador.**

Relacionado: [[medir-la-web-a11y-y-preview]] · [[web-pr62-espera-a-jurgen]]
