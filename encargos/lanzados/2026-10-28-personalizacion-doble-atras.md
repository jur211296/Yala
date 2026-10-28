# Personalización: un solo «‹» + «Nuevo presupuesto» encima del selector de periodos

## Contexto
Cola Yala 2.2 · sesión **S16**. Base `origin/2.2`. Cierre **cierra-sola** → al terminar, `/cerrar-total`.
S15 (panel-filtros-moneda, PR #670) ya cerró. No hay otra sesión Yala viva.
Decisión Jürgen 2026-10-28: «Nuevo presupuesto» va **encima** de Semanal / Mensual / Anual / Único (no encima de «Este mes»; S14/#669 lo dejó entre selector y mes).

Cumple **íntegramente** estos briefs (en este orden):
1. `~/Claude/tmp-frank/personalizacion-doble-atras-cuij.md` — un solo «‹» en Personalización.
2. `~/Claude/tmp-frank/presupuestos-nuevo-encima-selector-91in.md` — «Nuevo presupuesto» encima del selector.

Léelos y ejecútalos tal cual.

## Qué se pide
1. Mueve las cards a «in progress» con `--agente frank` al empezar.
2. Personalización: un solo botón «‹» (medir por qué el del sistema no se esconde; hermanas Ajustes si aplica el mismo bug).
3. Presupuestos: «Nuevo presupuesto» **encima** de Semanal / Mensual / Anual / Único; ajusta XCUITest si el de S14 asumía el orden intermedio.
4. Capturas después en el sim (Personalización + Presupuestos).
5. Al cerrar el lote, cards a done / in qa según criterio de cada brief.

## Qué NO hay que tocar
Lo que digan los briefs. No reabrir el aviso que tapa el «+» (kvig / #669) salvo que el reorden lo rompa. marketing/ y Web/ = Lola. No lanzar otras sesiones Yala.

## Cómo se sabe que está bien
Criterio de cada brief + PR a 2.2. Personalización con un solo «‹»; «Nuevo presupuesto» encima del selector de periodos; tests relevantes en verde.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Arranca en `origin/2.2`. Antes del PR, rebasea una vez sobre la base (sim apagado). Si el rebase no aplica o CI ajeno falla, sigue con lo que haya en la base — sin quedarte parado.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- Termina con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **Personalización, doble «‹»: ya arreglado en la base.** Medido: `ProfileView.paintsOwnBackButton` incluye `.personalization` desde 90b6e0870 (2026-10-25), un día después de abrirse la card; `AppLanguageSettingsReturnUITests` ya afirma que no existe `BackButton`. Las 8 pantallas que usan el «‹» del sistema no pintan uno propio (grep de `swipeBack`/`chevron.left`: 0). ⇒ no se toca código; se mide en el simulador con captura y el ticket pasa a `done`.
2. **Presupuestos: la píldora va justo encima del selector de tipo**, debajo del aviso de límite (el aviso sigue siendo lo primero cuando aparece). Mismo componente, mismo padding.
3. **XCUITest**: `TopPrimaryActionUITests` afirmaba el orden intermedio de S14; se invierten sus dos aserciones (Nuevo › tipo › período). Ningún otro test asume el orden (grep de `budgets_create_button`).
4. **Cards**: cuij → done (medido); 91in → done (lo fija el XCUITest; no pide iPhone).
