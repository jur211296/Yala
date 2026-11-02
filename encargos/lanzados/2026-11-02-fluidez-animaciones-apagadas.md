---
esfuerzo: high
release: no
---
# Animaciones que no animan: dentro de las pestañas, Ajustes desde Más y Reducir movimiento

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `fluidez-animaciones-apagadas` · Sesión cola **S35m** · al cerrar → **S35n** (`fluidez-hapticos-yala-ia`).

## Contexto
Estas cards salen de la auditoría de fluidez de `fluidez-animaciones-hapticos` (PR #720), que dejó el sistema común en `.claude/rules/swiftui-ds.md` («Fluidez: el sistema común»), `DS.Animation` y `DS.Haptic`. La auditoría completa está en `docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`: usa las filas marcadas C2, C5, C6.

Regla de Jürgen (2026-10-30): todo lo que sale de una sesión entra en 2.2 antes del barrido QA, nada a backlog.

Pantallas: las pestañas (Panel, filtros, calendario de Registros y Pagos, Insights, Estadísticas, presupuestos), Más → Ajustes y las vistas que ignoran Reducir movimiento.

Cards:
- `tablero ver tablero-fluidez-c2-animaciones-que-no-animan-den-s1ve` — Fluidez C2: animaciones que no animan dentro de las pestañas
  - Problema: Unos 40 withAnimation/dsWithAnimation dentro de pestañas no animan nada (ContentView apaga las transacciones que cruzan la TabView): píldoras del Panel, filtros, calendario de Registros y Pagos, secciones de Insights, flotantes de Estadísticas, gráficas de presupuesto, barra de progreso.
  - Hecha cuando: Cada sitio de la lista C2 de la auditoría anima con .animation(_:value:) implícita y DS.Animation, entra en TabImplicitAnimationsWiringTests y se ve en vídeo.
- `tablero ver tablero-fluidez-c5-ajustes-abierto-desde-mas-no-bbap` — Fluidez C5: Ajustes abierto desde Más no anima
  - Problema: MoreView.swift:122 pone .transaction { $0.animation = nil } a ProfileView solo cuando se abre desde Más; desde el Panel o Grupos sí anima. Averiguar por qué se puso (commit b080d8b62) y acotarlo.
  - Hecha cuando: La causa del apagado documentada y el apagado acotado a lo que lo motivó (o retirado), con las animaciones de Ajustes iguales desde Más que desde el Panel; XCUITest de Más y Ajustes en verde.
- `tablero ver tablero-fluidez-c6-animaciones-que-no-respetan-r-m1hw` — Fluidez C6: animaciones que no respetan Reducir movimiento
  - Problema: SetupChecklistCard, ScoreRingView, la barra de selección de Registros, GroupFormView, GroupSettingsView, AccountFormView, la columna de Yala IA y su panel de voz animan aunque esté activado Reducir movimiento.
  - Hecha cuando: Todas pasan por dsAnimation o reduceMotion ? nil y un source-scan lo fija.

## Qué se pide
1. Lee la auditoría (filas C2, C5, C6) y el sistema común. Resuelve cada fila con `DS.Animation`/`DS.Haptic`, respetando Reducir movimiento, sin inventar curvas ni hápticos nuevos.
2. Para cada card, cumple su «hecha cuando», con tests (unitarios, source-scan o XCUITest según la card) y vídeo o capturas antes y después en `capturas/` y en el digest.
3. Pasa las cards a «in qa» de Jürgen al abrir el PR (con `--agente` de la sesión).

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Filas de la auditoría de otras cards de Fluidez.
- La lógica de datos, la sincronización y el servidor.
- marketing/ ni Web/.
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando».
- No hay elementos duplicados en accesibilidad ni XCUITest rotos.
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge y vídeo o capturas.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 (Frank, 2026-11-02, auto-contestado en modo autónomo)

Medido antes de decidir: la auditoría (filas C2, C5, C6), `swiftui-ds.md` («Animar dentro de una pestaña» y «Fluidez: el
sistema común»), `TabImplicitAnimationsWiringTests`, y cada sitio en el código. C4 (hápticos) y C8 (Yala IA) están en
«ready to launch» para la sesión siguiente (S35n).

1. **Hápticos de las filas C2 («sin háptico»): fuera.** Son de C4, que va justo después. Aquí solo la animación.
2. **Cómo se arregla un sitio C2:** el estado cambia sin `withAnimation`/`dsWithAnimation` (no animaban nada) y el
   CONTENEDOR de lo que cambia lleva `.animation(reduceMotion ? nil : DS.Animation.<curva>, value: <estado>)` o
   `.dsAnimation(…)`. Curvas: `.selection` para píldoras, segmentos, chips, días elegidos; `.appear` para plegables,
   flotantes, tarjetas que se van; `.number` para la barra de progreso y el «≈ S/ X». Ninguna curva nueva.
3. **Lo que cambia la página entera sigue en seco**, como fija el sistema común: la lista ↔ calendario anima el selector
   y no funde la página (fundirla duplicaría el árbol de accesibilidad); quitar un filtro anima la fila de chips, no los
   widgets; el período del Panel anima la píldora (`titleMotion: .fade`), no el recálculo. Si la barra de filtros
   desaparece entera (último chip), la sección se va en seco: animarla movería todo el Panel con el recálculo.
4. **Mes del calendario de Registros:** el mes nuevo entra con `PeriodTitleMotion` (empuje con las flechas, fundido
   desde el menú) y el viejo se va en el acto. Un fundido en sitio solaparía los números de los días.
5. **Pausar y marcar pagado (Pagos):** la fila cambia de sección con `animatesRowEdits` (ids con su sección), molde de
   `GroupBalancesView`.
6. **Alcance de C2:** los sitios de la lista C2 y sus hermanos del mismo patrón en esos mismos ficheros. Los
   `withAnimation` muertos de otros ficheros de pestaña no listados van a una card nueva con su inventario.
7. **C5:** el apagado lo puso `c6d44bac8` (2026-01-15, «Intentar mitigar parpadeo en sheet de ProfileView»; su propio
   mensaje dice «el parpadeo persiste») en la vista Más de entonces; `b080d8b62` lo trasladó tal cual a `MoreView`. El
   parpadeo lo cubre el apagado de `ContentView` (`8787baba2`, el mismo día). Se retira; desde el Panel y Grupos Ajustes
   nunca lo llevó.
8. **C6:** los sitios de la card. En `ChatSheetView` solo el panel de voz (las otras animaciones del chat son de C8).
   Hojas (`GroupFormView`, `GroupSettingsView`, `AccountFormView`): `dsWithAnimation(reduceMotion, DS.Animation.…)`.
   Pestañas (checklist, anillo, barra de selección, columna de Yala IA): implícita con `reduceMotion ? nil`.
9. **Tests:** cada sitio C2 entra en `TabImplicitAnimationsWiringTests`; C5 y C6, en un source-scan nuevo
   (`ReduceMotionWiringTests`); el XCUITest de Más y Ajustes (`ProfileSettingsUITests`) en verde.
10. **Vídeo:** antes y después con un conductor XCUITest temporal en el mismo simulador: hero del Panel, calendario de
    Registros, plegable de Insights y Ajustes desde Más. El resto queda fijado por el source-scan.
