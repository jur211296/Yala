# Widgets de Yala con fondo con profundidad y glass, en vez del gris plano

Cierre: **cierra-sola**. Al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `widgets-fondo-glass` · Encargo 05 de la cola Yala (antes S35l4) · al cerrar → encargo 06. Esfuerzo: high.

## Cards y criterio de hecho
- `tablero-widgets-de-yala-fondo-con-profundidad-y-c0nl` — Widgets de Yala: fondo con profundidad y efecto glass en lugar del gris plano
  - Hecha cuando: Todos los widgets de Yala tienen fondo con profundidad (degradado o material glass y borde sutil) comparable a las referencias, en claro, oscuro y tintado; capturas antes y después en el PR y el digest.

## Contexto
Jürgen (2026-11-02 20:30 Lima) mandó una captura de su pantalla de inicio: `~/Claude/tmp-frank/adjuntos/widgets-referencia-2026-11-02.png`. El widget de Yala «Entradas y salidas» se ve gris, plano, sin profundidad ni efecto glass. Le gustan el widget de batería de Apple (oscuro translúcido con borde suave) y el de Gentler Streak (oscuro con degradado y profundidad). Mira la captura antes de empezar. **Jürgen 20:33: prefiere el de batería al de Gentler Streak; el de batería es la referencia principal** (oscuro translúcido, glass, borde suave). Gentler Streak es solo secundario.

## Qué se pide
1. Rediseñar el fondo (`containerBackground`) de **todos** los widgets de Yala para que tengan profundidad: degradado sutil y/o material glass con borde fino iluminado, a la altura de las referencias. Que no compita con los números.
2. Que funcione en claro, oscuro, tintado y transparente (Liquid Glass de iOS 26/27) y en StandBy; en tintado, deja que iOS lo trate bien (widgetAccentable, sin fondos que se vuelvan bloques grises).
3. Mantén colores de marca, legibilidad y contraste (VoiceOver y letra grande sin romper).
4. Capturas antes y después (claro, oscuro, tintado) de cada tamaño en el PR y en el resultado del encargo.

Nota: el encargo 01 limpió los brillos y degradados del README de marca (regla de Jürgen del 2026-10-13). Este pedido de Jürgen del 2026-11-02 es posterior y específico de widgets: usa material glass del sistema y degradado muy sutil, sin glows; si choca con el README, documenta la excepción para widgets en el PR.

## Qué NO hay que tocar
Datos, lógica ni timelines de los widgets; marketing/, Web/, ficha App Store.

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

## Paso 0 (Frank, 2026-11-03, auto-contestado: MODO AUTÓNOMO)

Medido antes de decidir:
- En la captura de Jürgen, el widget de batería es casi el fondo de pantalla: #15152F arriba, #0D0D16 en medio, borde
  #252540. El de Yala es gris #454547 → #373738. Ese gris es `secondarySystemGroupedBackground` resuelto en nivel
  «elevado» (#3A3A3C), no el #1C1C1E que pinta el banco.
- El SDK de iOS 27.2 no da a un widget de terceros un glass real: `WidgetTexture.glass` es solo de visionOS y un
  `Material` no ve el fondo de pantalla. En tintado y transparente el sistema ya quita nuestro fondo y pone el suyo.

Decisiones:
1. **Fondo = degradado vertical muy sutil + borde fino iluminado**, en una sola vista (`WidgetCardBackground`) que
   usan todos los widgets del sistema. Oscuro: casi negro con un punto de índigo, como la batería. Claro: blanco que
   baja a un gris perla, con un borde gris muy tenue. Sin glows ni brillos.
2. **Colores fijos, no de sistema**: así el oscuro no sube al gris elevado.
3. **Tintado, transparente y StandBy**: el fondo sigue siendo `containerBackground` removible, así que iOS lo quita y
   pone su glass. No se toca nada más ahí.
4. **Entrada rápida pequeña** conserva su relleno de marca: gana el mismo borde y un degradado que solo OSCURECE hacia
   abajo (el blanco del texto no pierde contraste).
5. **Pantalla bloqueada** (accesorios) fuera: no tiene fondo propio (`.clear`), lo pinta el sistema.
6. **Contraste**: los tres textos de color (`incomeText`, `alertText`, `accentText`) se miden contra el punto más
   desfavorable del degradado nuevo; si alguno baja de 4,5:1, se ajusta el degradado, no el texto.
7. **README de marca**: la regla de 2026-10-13 (sin degradados) sigue para la app; la excepción de widgets se escribe
   en `.claude/rules/widgets.md` y en el PR.
