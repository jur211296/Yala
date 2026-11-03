# Fluidez: «+» de subpestañas de Estadísticas, borrar duplicados, esqueletos y scrollTo, marcas de ayuda del Panel y splash con Reducir movimiento

Cierre: **cierra-sola**. Al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `fluidez-subpestanas-duplicados-y-splash` · Encargo 08 de la cola Yala (lote de 5 tareas chicas, un PR, un cierre) · al cerrar → encargo 09. Esfuerzo: medium.

## Cards y criterio de hecho
- `tablero-estadisticas-el-flotante-de-una-subpesta-2dqj` — Estadísticas: el «+» flotante de una subpestaña bajada puede seguir encendido al cambiar a otra (sin medir)
  - Hecha cuando: Medido en vídeo; si pasa, al cambiar de subpestaña el «+» sigue a la fila de acciones de la subpestaña que se ve; si no pasa, descartada con el vídeo.
- `tablero-fluidez-borrar-el-ultimo-duplicado-en-el-0mzg` — Fluidez: borrar el último duplicado en el modo duplicados de Registros salta en seco
  - Hecha cuando: Borrar o fundir duplicados se funde, y el último pasa al vacío fundiéndose, con Reducir movimiento; test de cableado; vídeo.
- `tablero-fluidez-el-brillo-de-los-esqueletos-y-lo-ehsu` — Fluidez: el brillo de los esqueletos y los scrollTo animados dentro de una pestaña
  - Hecha cuando: Medido en vídeo en el Panel, Estadísticas y Flujo de caja; lo que salte, animado y con Reducir movimiento.
- `tablero-fluidez-las-marcas-de-ayuda-coachmarkove-v84b` — Fluidez: las marcas de ayuda (CoachMarkOverlay) del Panel no animan al entrar
  - Hecha cuando: Vídeo antes/después; si salta en seco, implícitas en su contenedor con DS.Animation y Reducir movimiento, en TabImplicitAnimationsWiringTests.
- `tablero-splash-las-particulas-siguen-moviendose-n3iq` — Splash: las partículas siguen moviéndose con Reducir movimiento
  - Hecha cuando: Con Reducir movimiento el splash no mueve partículas (no arranca el Timer); test de cableado; captura.

## Contexto
Restos de fluidez-extra y fluidez-listas-pestanas-y-grupo-desde-push (PR #751 y #754). Son arreglos chicos de animación; deja los vídeos en el PR para que Jürgen los vea.

## Qué se pide
0. Lee cada card con `tablero ver <id>` (contexto y siguiente paso) antes de tocar código.
1. Resuelve las cards del lote en este orden, con su test o su vídeo según pida cada «Hecha cuando».
2. Si una card resulta no reproducible, descártala con la evidencia (vídeo o test) escrita en la card y en el PR.

## Qué NO hay que tocar
Textos de la app, precios o paywall, marketing/, Web/, lógica de datos.

## Pie fijo (lanzar-sesion)
- Proyecto Yala, repo `jur211296/Yala`. Versión **2.2**. Base `origin/2.2`; el PR va a `2.2` con auto-merge.
- Una sesión Yala a la vez: no lances otras sesiones Yala ni trabajes en paralelo con otra. Un solo PR para todo este encargo y un solo cierre.
- Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Pipeline serial de la Mini: limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados (nunca las de un worktree vivo); build con `xcodebuild -jobs 2` sin sim booteado; bootear 1 sim; tests; apagar y borrar el sim. `limpiar-mac --apply` al cerrar.
- Pasa cada card a «in qa» (o «done» si no necesita ojos de Jürgen) al abrir el PR, con `--agente` de la sesión.
- Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog), y lista sus títulos en el PR y en el cierre.
- Cierre autónomo: se lanza con `--permission-mode bypassPermissions`. Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
- Al cerrar, Frank publica el digest y lanza el siguiente encargo de `~/Claude/flota/cola-yala/`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Cómo medir el «antes»**: base `origin/2.2` compilada aparte con `git archive` (DerivedData propio) y el mismo recorrido en el simulador con `simctl io recordVideo`; veredicto por tiempos de fotograma y luminosidad por fotograma, no a ojo.
2. **2dqj (el «+» de las subpestañas)**: se mide antes de tocar nada; si no pasa, se descarta con el vídeo. Medido: no pasa → descartada, sin código.
3. **0mzg (duplicados)**: el molde de 1jvv (`animatesEmptyStateSwap` en un `ZStack` de las dos ramas + `animatesRowEdits`). «Quitar repetidos» borra más filas de las que `RowListEditLogic` funde, así que se anima con un contador propio (`duplicateRemovalCount`) en la lista y en la cabecera. Opción conservadora: no se cambia `maxAnimatedChanges` (afectaría a todas las listas).
4. **ehsu (esqueletos y scrollTo)**: se toca solo lo que el vídeo dé por roto. Medido: el brillo estaba quieto → implícita en `ShimmerModifier`; los scrollTo ya animan → sin cambios.
5. **v84b (marcas de ayuda)**: implícitas en el contenedor de `CoachMarkOverlay` con `DS.Animation.appear` / `.selection` y Reducir movimiento, y fuera los `dsWithAnimation` muertos (patrón C2). Para grabar la guía del Panel en el simulador hace falta un seam DEBUG (`-uitest-pro-tour-panel`) que no escribe nada.
6. **n3iq (splash)**: con Reducir movimiento no se llama a `startParticleAnimation`. El pulso del logo y el brillo se quedan como están (con Reducir movimiento ya son un salto único, no movimiento continuo).
7. **Evidencia de animación que el simulador no discrimina** (esqueleto solo visible con el hilo principal ocupado): variante temporal por argumento (`-zzSkel`) en las dos builds, fuera del diff.
