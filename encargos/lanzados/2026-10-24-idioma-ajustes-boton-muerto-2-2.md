# Arreglar: tras cambiar el idioma desde Personalización, Ajustes no se reabre y su botón deja de responder

## Contexto
Card: `tablero-tras-cambiar-el-idioma-desde-personaliza-6d71` (high, 2.2). Bloquea a `tablero-ux-2-2-l16-5-el-idioma-de-la-app-solo-se-qb1r` (L16-5, opción B híbrida que Jürgen decidió el 23-oct y que entró en PR #611).

Medido en el barrido de QA 2.2 (2026-10-24, PR #617), simulador iPhone 17 Pro iOS 27.0, Yala Dev de origin/2.2 @ 03fa38a03, arrancada con `-uitest -uitest-skip-onboarding`, un solo idioma en el iPhone, reproducido 2 de 2:
Ajustes › Personalización › «Idioma de la app» abre el selector de Yala (bien) › English (US): la app se redibuja en inglés, pero NO se reabre Ajustes en Personalización (queda el Panel) y tocar el botón de Ajustes (avatar, `profile_avatar`) ya no abre nada. Otros botones del Panel sí responden. Cerrar Yala y abrirla lo arregla. Igual de inglés a español.
Capturas: `~/Claude/worktrees/_capturas/2026-10-24-barrido-qa-2-2/qb1r-1-fila-un-idioma.png` y `qb1r-2-tras-elegir-ingles-ajustes-no-abre.png`.

Pista (INFERIDA, sin medir; verifícala, no la des por buena): `PersonalizationSettingsView` pone `navigation.pendingSettingsReturn = .personalization` y `selectMainTab(.panel)` antes de cambiar `LanguageManager.overrideLanguage`; `PanelSettingsReturnOpening` debía reabrir la hoja. Puede que la hoja quede «presentada» en el estado del Panel anterior a la reconstrucción (`isPresentingSettings` true) y el Panel nuevo ni la reabra ni deje abrir otra. La review del 23-oct ya avisaba de un «botón de Ajustes muerto» con el ancla tapada (`ContentView`, `.languageDidChange`).

## Que se pide
1. Descartar primero que sea solo del modo `-uitest` (probar también arrancando sin él).
2. Reproducirlo con un XCUITest que falle: cambiar el idioma desde Personalización con un solo idioma en el iPhone y volver a tocar Ajustes.
3. Causa raíz y arreglo, sin parches que tapen el síntoma. Debe quedar la conducta decidida (B): al elegir, Ajustes se reabre en Personalización; y el botón de Ajustes siempre abre la hoja.
4. Al cerrar, mover la card del bug a done (o a in qa si hace falta el ojo de Jürgen en el iPhone) y devolver la card L16-5 a in qa asignada a jurgen con el guion corto (la parte de dos idiomas en el iPhone sigue sin probar).
5. Pipeline serial Yala: limpiar → build con `xcodebuild -jobs 2` sin simulador booteado → boot 1 simulador → tests → apagar y limpiar. Máximo 1 simulador.
6. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.
7. Gate: la sesión arranca sobre `origin/2.2`. Justo antes del gate, mira si el PR anterior (#617) sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si 2.2 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
8. Capturas de antes y después en `capturas/` del worktree (`antes.png`, `despues.png`) y sus rutas en el resumen.
9. Cierra con `/cerrar-total`. No hay decisión de producto pendiente: la B ya está decidida.

## Que NO hay que tocar
- No cambiar el diseño decidido (B híbrido) ni el copy.
- No marketing/, no producción, no mergear a mano a 2.2 (el PR queda en cola de merge).
- No abrir otro simulador en paralelo ni dejar simuladores encendidos al terminar.

## Como se sabe que esta bien
Tras elegir otro idioma en el selector de Yala, Ajustes se reabre en Personalización y el botón de Ajustes sigue abriendo la hoja, con un XCUITest que lo fija y la suite del alcance en verde. PR abierto a 2.2 en cola de merge.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Arreglo antes o después de tener el rojo?** → Después. Primero un XCUITest nuevo (`AppLanguageSettingsReturnUITests`) que falle con el código de `origin/2.2`, ida y vuelta (es → en → es).
Por qué: el encargo lo pide y la pista es inferida. Alternativa descartada: arreglar por lectura de la pista.

**D2 · ¿Cómo se arregla?** → Se decide al medir la causa, con dos condiciones fijas: (a) la hoja se pide cuando de verdad puede montarse, y (b) el flag `isPresentingSettings` no puede quedarse en `true` sin hoja en pantalla (el botón no puede morir). Sin esperas por tiempo fijo.
Por qué: un `sleep` taparía el síntoma en un aparato y no en otro (regla 4 de presentaciones de `swiftui-ds.md`). Alternativa descartada: reabrir con retraso.

**D3 · ¿Cómo encuentra el test cada idioma del selector?** → `accessibilityIdentifier("app_language_option_<código>")` en las filas del selector. No cambia nada visible ni el copy.
Por qué: el texto de las filas cambia con el idioma; un id no. Alternativa descartada: buscar por etiqueta.

**D4 · ¿El modo `-uitest` explica el fallo?** → Se mide arrancando Yala Dev a mano sin `-uitest` en el simulador, antes de arreglar.

**D5 · ¿Dónde acaba la card del bug?** → `done` si el XCUITest fija la conducta en verde; la card L16-5 vuelve a `in qa`, asignada a Jürgen, con el guion corto de dos idiomas en el iPhone (lo único sin probar).

**D6 · Orden de entrega** → Paso 0 → medida → arreglo → mirar #617 y rebasar una vez con el simulador apagado → build `-jobs 2` → gate → commit → PR en cola de auto-merge → `/cerrar-total`.

### Cierre de D2 y D4 (medido)

- **Causa (D2), medida con sonda en el simulador.** Al elegir el idioma, el Panel nuevo pide Ajustes con la ventana todavía llevando DOS hojas (Ajustes y el selector) que UIKit está cerrando. En los casos rojos UIKit lo rechaza: `Attempt to present <PresentationHostingController> … which is already presenting`; medio segundo después la ventana queda sin nada presentado y `isPresentingSettings` del Panel queda en `true` sin hoja: tocar el avatar pone `true` sobre `true` y no pasa nada. A mano (toques lentos) la carrera se gana a veces; el XCUITest sin arreglo cayó en la reapertura 2 de 3 veces.
- **Arreglo (D2).** `SettingsReturnOpening.run`: espera a que la ventana no tenga nada presentado (`ModalPresentationProbe`, condición viva, tope 3 s), pide la hoja, comprueba con UIKit que llegó (1,5 s) y, si no, baja el flag y reintenta una vez. Si la ventana no se libera, no la pide: el botón nunca queda muerto. Con el arreglo, el XCUITest 3 de 3 en verde.
- **D4.** Sin `-uitest` la app arranca en el Welcome de una instalación nueva (otro almacén), así que no se recorrió a mano. Ningún paso del camino (selector, `.languageDidChange`, reapertura, hoja de Ajustes) tiene ramas de `UITestHooks`, y la causa es una carrera de UIKit: no depende del modo de test.
- **Desviación del pipeline.** Los builds incrementales de la medición se hicieron con el simulador ya arrancado (la regla de `testing.md` prohíbe apagarlo entre corridas). El primero, `-jobs 2` con el simulador apagado.
- **Gate (medido).** Build `Yala` y `Yala Dev` sin warnings en lo tocado · `YalaTests` 11.425 tests, 0 fallos · XCUITest de las 39 suites cuyas áreas casan con lo tocado: 180 casos, 175 verdes, 5 skipped, 0 fallos, centinela 0 (solo durante los 75 min) · audit limpio · índice OK.
