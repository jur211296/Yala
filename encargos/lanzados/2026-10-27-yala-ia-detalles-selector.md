# Yala IA: «Detalles» de un registro propuesto no abre ningún selector

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `yala-ia-detalles-selector` · Sesión cola **S12b** · al cerrar → **S13**.

## Contexto
Hallazgo de la sesión que dejó en verde los XCUITest rojos de la base de 2.2 (PR #653). Es una regresión real de 2.2: la nocturna del 21-oct estaba verde y la del 23-oct roja. En la hoja «Registro propuesto» de Yala IA, tocar Categoría, Cuenta, Fecha o Etiquetas no hace nada: SwiftUI construye la hoja y UIKit no la presenta. Ticket: `chat-draft-details-rows-dont-open-their-selector`. Card del tablero: «Yala IA: «Detalles» de un registro propuesto no abre ningún selector» (high).

## Qué se pide
1. Bisecar `df498b7cc..43daa3354` con `ChatMessagingLayoutUITests/test_draftDetails_opensSheet_withTheNewRecordAccountSelector` como oráculo, empezando por el merge `221791927` (lote 07). Verifica la hipótesis; no la des por buena.
2. Arreglar la causa raíz para que los cuatro campos de Detalles abran su selector.
3. Un PR a 2.2 en auto-merge, con el XCUITest verde y un test que fije cada uno de los cuatro selectores si el existente no los cubre.

Mueve la card a «in progress» con `--agente frank` al empezar; al cerrar, a done (o in qa a jurgen si hace falta QA manual).

## Qué NO tocar
- marketing/ y Web/ (Lola).
- Otras sesiones de la cola (no las lances).
- No desactivar ni saltar el test, ni el gate.

## Cómo se sabe que está bien
Los cuatro campos de Detalles abren su selector y el XCUITest está verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Se biseca desde el lote 07 como pide el encargo?** → Se midió primero y la hipótesis cae: `e06bfff0c` (#571, lote 07) da VERDE con el oráculo; la bisección `--first-parent e06bfff0c..f23ddacad` da como primer rojo **#602** (`43daa3354`, lote 02 · formulario B).
Por qué: el encargo pide verificar la hipótesis, no darla por buena. Alternativa descartada: arreglar a partir del lote 07 sin medir.

**D2 · ¿Se bisecan los commits de dentro de #602?** → No: la rama tiene un único commit de producto (`77f62f037`). Se aísla la causa con experimentos sobre los ficheros que tocó (sizing de los selectores, `.presentationBackground`, buscador).
Por qué: bisecar un commit no da más información. Alternativa descartada: partir el commit a mano.

**D3 · ¿Qué fix?** → El mínimo en la causa raíz compartida, conservando lo que decidió Jürgen en #602 (material grueso a media altura, L2-22; buscador, L2-3). Si la causa es un modificador de presentación, se cambia cómo se aplica, no la decisión visual.
Por qué: el encargo es un bug, no rediseño. Alternativa descartada: revertir partes de #602.

**D4 · ¿Qué tests?** → Se mantiene `test_draftDetails_opensSheet_withTheNewRecordAccountSelector` (cuenta) y se añaden tres casos, uno por campo (categoría, fecha, etiquetas), para que el rojo diga cuál falla. Se valida que caen sin el fix.
Por qué: el existente solo cubre cuenta. Alternativa descartada: un único caso de los cuatro, que con `continueAfterFailure = false` calla los siguientes.

**D5 · ¿«`43daa3354` no compila»?** → Falso: era un build incremental; en la bisección compiló y dio rojo. Se dice en el PR.
