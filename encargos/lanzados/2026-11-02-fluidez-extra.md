# Fluidez extra: Grupos sin deslizarse al entrar, el «+» sin asomarse ni quedar fijo, Activar Yala completo sin golpes y README de marca sin brillos

Cierre: **cierra-sola** → al terminar, `/cerrar-total`. Esfuerzo: high.
Versión **2.2**. Base `origin/2.2`.
Slug: `fluidez-extra` · Encargo 01 de la cola Yala (antes S35r) · al cerrar → encargo 02.

## Contexto
Jürgen aprobó este plan el 31-oct a las 22:03 (Lima): «Sí, aplícalo así». Su regla del 2026-10-30 es que todo entra en 2.2 antes del barrido QA, nada a backlog.

Zona: Grupos, Registros, Activar Yala completo y el README de marca.

Cards:
- `tablero ver tablero-grupos-la-primera-vez-que-entras-tras-ab-hsqm` — Grupos: la primera vez que entras tras abrir la app, el contenido se desliza ~44 pt
  - Problema: Hallazgo del PR #703. Tras abrir la app, el primer toque en Grupos deja la pantalla quieta ~0,8 s y luego el resumen sube ~44 pt animado en 0,3 s. Pasa con y sin el arreglo del buscador; colgar .searchable del ZStack no lo cambia. Ticket: tickets/backlog/groups-first-entry-after-launch-slides-content.md
  - Hecha cuando: La primera entrada tras abrir la app pinta el resumen en su sitio desde el primer fotograma, verificado en vídeo.
- `tablero ver tablero-el-flotante-asoma-0-2-s-al-entrar-a-la-p-2m2r` — El «+» flotante asoma ~0,2 s al entrar a la pestaña Grupos y se va
  - Problema: Hallazgo del PR #703, visible también en el vídeo de Jürgen del 30-oct. Con la pestaña oculta, revealsFloatingActionWhenScrolledAway deja el flotante encendido y al volver se ve 2-3 fotogramas. Comprobar Panel, Presupuestos y Pagos, que usan el mismo modificador. Ticket: tickets/backlog/floating-plus-flashes-when-entering-a-tab.md
  - Hecha cuando: Al entrar a una pestaña con los botones de arriba a la vista, el flotante no aparece en ningún fotograma, y sigue apareciendo si se vuelve con la lista desplazada.
- `tablero ver tablero-activar-yala-completo-al-cambiar-de-pant-p48h` — Activar Yala completo: al cambiar de pantalla, la que sale puede desaparecer de golpe (pila por pantalla)
  - Problema: Hallado en el encargo welcome-transiciones-pasos (card feer, 28-oct). FullModeActivationView reusa WelcomeNewChooserView y WelcomePrivateICloudGateView, que fuera del cover del Welcome siguen montando su propia NavigationStack (welcomeBackButton). En el Welcome eso hacía que la pantalla que sale desapareciera en un fotograma y, en el iPhone, que la nueva creciera desde la esquina con negro. Aquí no se midió: la activación intercala onboarding y restaurar, con pila propia, y no cabe el mismo arreglo (una pila para todo).
  - Hecha cuando: Medido en vídeo; si el salto corta, fundido sin negro entre chooser y puerta; si no, descartada con el vídeo.
- `tablero ver tablero-readme-de-marca-todavia-trae-brillos-y-d-cisf` — README de marca todavía trae brillos y degradados (choca con la regla nueva)
  - Problema: Lote 2.2 · Accesibilidad, contraste y diseño

Hallazgo del cierre de «Propuestas nuevas de capturas App Store» (PR #487). Regla de Jürgen 2026-10-13: sin degradados ni glows.
  - Hecha cuando: el README de marca ya no recomienda brillos, glows ni degradados y cuadra con la regla de Jürgen del 2026-10-13 (la card no trae criterio propio; este es el conservador). Ojo: el encargo 05 (widgets con glass) pide profundidad en widgets; aquí solo se limpia el README, sin prohibir el material glass del sistema en widgets.

## Qué se pide
1. Lee cada card y su ticket, si tiene. Busca la causa raíz antes de tocar código.
2. Cumple el «hecha cuando» de cada card, con tests (unitarios, source-scan o XCUITest según el caso) y, si es visual, vídeo o capturas antes y después en `capturas/` y en el digest.
3. Pasa las cards a «in qa» de Jürgen al abrir el PR (con `--agente` de la sesión).

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Nada fuera de las cards de esta sesión.
- marketing/ ni Web/ (salvo el README de marca, si está en las cards).
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando».
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge.

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

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué hace de «antes» y cómo se mide lo visual?** → Un build del árbol sin tocar (`origin/2.2` de hoy) y un
conductor XCUITest temporal que recorre las pestañas con pausas mientras `simctl io recordVideo` graba; el veredicto sale
de los fotogramas (`ffmpeg`), antes y después. El conductor no se commitea.
Por qué: los tres hallazgos visuales duran 2-20 fotogramas y un XCUITest consulta cada 1 s. Alternativa descartada:
afirmarlos en XCUITest, que no ve un fotograma.

**D2 · Grupos, primera entrada: ¿qué se arregla?** → La causa que el vídeo y la instrumentación confirmen; la hipótesis de
partida es que la lista sustituye al indicador de carga con la barra ya visible. Se prefiere cargar o montar la lista
antes de que la pestaña se vea frente a esconder la animación.
Por qué: el criterio es «en su sitio desde el primer fotograma», no «sin animación». Alternativa descartada: quitar la
animación de la primera carga (C7), que dejaría el salto seco.

**D3 · El «+» flotante: ¿dónde va el arreglo?** → En el modificador común `revealsFloatingActionWhenScrolledAway`, para
las cuatro páginas que lo usan (Grupos, Presupuestos, Pagos, Estadísticas): lo que diga la visibilidad mientras la página
no está a la vista no enciende el flotante, y al volver con la lista desplazada sigue saliendo. El Panel decide por
desplazamiento (otro mecanismo): se graba y solo se toca si también asoma.
Por qué: el modificador es el único sitio común y la card pide comprobar los demás. Alternativa descartada: arreglarlo
solo en Grupos.

**D4 · Activar Yala completo: ¿arreglo o descarte?** → Lo decide el vídeo (chooser → puerta privada → volver). Si la
pantalla que sale corta, fundido sin negro con el molde de la card feer que quepa aquí (`zIndex` + fondo común), sin
juntar las pilas de navegación; si no corta, se descarta con el vídeo.
Por qué: la card lo pide así y el arreglo del Welcome (una pila para todo) no cabe en la activación.

**D5 · README de marca: ¿cuánto se toca?** → Solo `marketing/marca/README.md`: el fondo pasa a navy liso, los brillos
salen como pieza del sistema (formas planas sólidas, sombra solo negra) y el destello del logo se queda, porque es la
marca (lo dejó así la propuesta de capturas del 13-oct). No se toca `render-post.mjs` ni nada de Lola: el README avisa de
que ese render es anterior a la regla. No se dice nada de widgets ni del glass del sistema.
Por qué: la card no trae criterio propio y el encargo pide el conservador. Alternativa descartada: reescribir el render
del post diario, que es pieza de Lola y no está en las cards.

**D6 · Cards que salgan por el camino** → A 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank.
