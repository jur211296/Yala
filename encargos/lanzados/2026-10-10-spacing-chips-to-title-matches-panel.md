---
esfuerzo: medium
---
# Hay un vacío sobrante entre los chips y el título en las vistas que no son el Panel

**Card:** tablero-hay-un-vacio-sobrante-entre-los-chips-y-pxmv · **Prioridad:** medium · Reporte de Jürgen (10-oct 07:28). Captura: `~/Claude/referencias-ui/2026-10-10-estadisticas-vacio-entre-chips-y-titulo.png` (Estadísticas › Resumen: hueco grande entre los chips Resumen/Tendencias/Distribución y «Neto del período»).

## Qué se pide
1. Encontrar de dónde sale el espacio: el contenedor de los chips (padding o spacing del VStack, un `Spacer`, `safeAreaInset`, un header reservado, `.padding(.bottom)`) en Estadísticas y en todas las demás pestañas o vistas con chips (Registros, Grupos y las que haya).
2. Medir el espaciado del Panel (chips → primer título o segmentador) y usar ese valor en todas, de preferencia con un token o componente compartido, no con números sueltos.
3. Es un ajuste de espaciado, no un rediseño: no cambies tipografía, colores ni orden. Si alguna vista necesita una decisión de diseño, anótala y no la toques.
4. Capturas antes y después de cada vista tocada, más el Panel como referencia, en `~/Claude/worktrees/_capturas/`, en claro y oscuro y con texto grande (una sola corrida de simulador).
5. Hecha cuando: el mismo espaciado que el Panel en todas las vistas, con capturas antes y después. Sin device-QA, salvo que algo cambie en iPad.

## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir** (iPhone 17 Pro, `Yala Dev`, tamaño de texto normal):
- El Panel no tiene chips: encima del hero solo está la barra de navegación. Su contenido arranca
  `DS.Spacing.lg` (16 pt) por debajo de la barra (`PanelView`, `.padding(.top, DS.Spacing.lg)`).
  Visualmente, del borde inferior de los botones de arriba a la píldora del período: 26 pt.
- Estadísticas: del borde inferior de los chips a la píldora del período: 37 pt, igual en la
  captura de Jürgen. Se suman cuatro piezas: 8 pt bajo los chips (`safeAreaInset`), 4 pt de la guía
  contextual aunque no se vea, 8 pt de margen del scroll y 12 pt del hero (`summaryVerticalPadding`,
  `@ScaledMetric`, que además crece con el texto grande).
- Vistas con barra de chips: Estadísticas (4 pestañas), Planificación (2), detalle de grupo (3) y
  Reportes (2). Registros no tiene chips de navegación.

**D1 · ¿Qué es «el espaciado del Panel» si el Panel no tiene chips?** → lo que separa la barra de
arriba del primer contenido: la barra termina y el contenido empieza `DS.Spacing.lg` después.
Por qué: es el único valor que el Panel define en código; la barra de chips hace aquí el papel de
la barra de navegación. Alternativa descartada: clavar los 26 pt visuales, que incluyen 10 pt de
cromado del sistema bajo los botones y no corresponden a ningún token.

**D2 · ¿Cómo se comparte?** → un modificador único para la barra de chips con su aire fijo
(los 8 pt de la barra + `DS.Spacing.lg` hasta el contenido), usado por las cuatro vistas, y el
contenido de debajo sin margen superior propio.
Por qué: el encargo pide token o componente compartido; hoy cada vista suma sus piezas y por eso
divergen. Alternativa descartada: retocar números en cada vista.

**D3 · Texto grande.** → el aire de arriba NO escala con el texto, como en el Panel. El margen
inferior del hero (hasta los filtros) sigue escalando como hoy.
Por qué: con AX el `@ScaledMetric` de arriba agranda justo el hueco que se quiere quitar.

**D4 · La guía contextual cuando se ve.** → sigue entre los chips y el contenido, sin cambiar su
aspecto; su margen deja de sumarse cuando no se ve.

**D5 · Alcance.** → solo el espacio vertical chips → primer contenido. No se toca tipografía,
color, orden ni el resto de márgenes. Lo que pida diseño se anota en el PR y no se toca.

**D6 · Capturas y medida.** → un XCUITest temporal (no se commitea) recorre las vistas en claro,
oscuro y claro con texto AX3, y guarda antes/después en `~/Claude/worktrees/_capturas/<slug>/`.
