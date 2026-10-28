# Tras onboarding de cero, «+ Nuevo registro» sale inactivo y no se explica

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `nuevo-registro-inactivo-post-onboarding` · Sesión cola **S12f** · al cerrar → **S12d**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/nuevo-registro-inactivo-post-onboarding-omw5.md`

Léelo y ejecútalo tal cual. Captura del antes en el brief.

## Qué NO tocar
Lo que diga el brief. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief + PR a 2.2.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0 (Frank, 2026-10-27 — auto-contestado, MODO AUTÓNOMO)

**Causa (medida en código).** La fila del Panel se apaga con `canUseVoiceInput` = cuenta activa **y**
subcategoría visible. Lo que deja «cuenta sí, subcategorías no» tras un onboarding con «Sí, cargar
categorías»: `seedCategoriesIfNeeded` sale por su centinela `seedCategoriesExecuted` **antes de mirar la base**
(y también si en ese instante quedan categorías viejas que el espejo se lleva después). Cualquiera de las dos
deja la elección del usuario sin efecto y no hay nada que la vuelva a correr. El botón «Crear categorías» del
selector tiene el mismo agujero (llama a la misma función). Qué camino exacto siguió el iPhone de Jürgen es
INFERIDO: no hay telemetría de la semilla.

**Decisiones.**
1. Una petición EXPLÍCITA de categorías (onboarding «Sí», «Crear categorías» del selector y el botón nuevo del
   Panel) siembra siempre que no haya ninguna categoría del usuario, aunque el centinela diga que ya sembró:
   `seedDefaultCategoriesOnUserRequest`. Los arranques automáticos siguen con el centinela. Riesgo aceptado:
   si las categorías de iCloud llegan después, se duplican y las funde `CategoryDeduplicationService`.
2. El Panel nunca se queda gris en silencio: con cuenta y sin categorías usables, la fila se sustituye (molde
   L3-10) por un botón «Crear categorías» y una línea que dice por qué. Sin ninguna categoría propia, el botón
   crea las de siempre; si hay categorías pero ninguna subcategoría visible, abre Ajustes › Categorías.
3. Fuera: la fila de Estadísticas y el botón flotante (mismo gris silencioso, también sin cuentas desde
   L3-10). Van a una card.
4. Texto: botón reusa `empty.activateCategoriesAction`; línea nueva `panel.createCategoriesHint` en 16 idiomas.
