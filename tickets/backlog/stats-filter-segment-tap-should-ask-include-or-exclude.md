---
id: stats-filter-segment-tap-should-ask-include-or-exclude
status: backlog
priority: medium
area: "statistics, filters, ux"
created: 2026-09-17
updated: 2026-10-08
source: "UX Jürgen 2026-09-17 (bugs de experiencia sin ticket)"
---

# Al tocar un segmento con filtros activos, preguntar si filtrar o excluir (no asumir excluir)

## Qué pasa hoy (experiencia)

Si el usuario ya está usando **excluir** (p. ej. excluir una cuenta) y luego toca un segmento de una gráfica, la app **asume excluir** ese segmento. No ofrece la alternativa de **filtrar/incluir** solo ese segmento.

## Qué quiere Jürgen

Revisar a fondo la integración de filtros **entre vistas** y **dentro de una misma vista**. Al tocar un segmento, **preguntar**: ¿excluir o filtrar ese segmento? Así se puede **combinar incluir y excluir** con más flexibilidad.

## Alcance

- Estadísticas (gráficas / segmentos) y cómo el gesto escribe en el modelo de filtros de sesión.
- Consistencia al navegar entre subvistas (Distribución, Tendencias, Registros, etc.): el mismo gesto no debe mutar el filtro de formas distintas sin aviso.
- No es solo copy: es el modelo de composición include∪exclude.

## Nota

Ticket de producto/UX gordo: conviene `/spec` corto antes de implementar el diálogo y la composición.

## Pregunta para Jürgen (triage 2026-10-08)

El modelo de hoy no puede combinar incluir y excluir: tiene un solo interruptor de modo, y cambiarlo vacía los filtros.

- **A.** Diálogo al tocar un segmento, solo con el modo excluir activo: «Excluir» o «Ver solo esto». La segunda opción cambia de modo y avisa de que se pierden las exclusiones. Barato, pero no combina.
- **B.** Composición real: cada dimensión guarda un conjunto de incluidos y otro de excluidos, y tocar un segmento pregunta siempre. Es lo que pediste («combinar incluir y excluir»), pero toca `SessionState`, `FilterService` y todas las barras de filtros. Necesita un `/spec`.
- **C.** El tap mantiene el modo actual, y una pulsación larga abre un menú con las dos acciones. Además de A o de B.

**Recomendación: B, con `/spec` antes.** A no da la combinación que pediste, y hacerlo después obligaría a rehacer el diálogo. Con B la prioridad queda en `medium`.

## Medido en 2.1 (triage 2026-10-08)

- `SessionState.isExcludeMode` (`SessionState.swift:229`) es un solo interruptor para todas las dimensiones, y su `didSet` (`:232-245`) vacía todas las selecciones al cambiar. Por eso, estando en excluir, «ver solo este segmento» obliga hoy a perder las exclusiones.
- Los taps de `CategoriesTabView.swift:541` y `:723-731` (Sankey) escriben en el modo activo, sin preguntar.
- Ningún commit de Estadísticas posterior al 2026-09-17 toca la composición de filtros.

Triage 2026-10-08: abierto · medium → medium · El modo excluir sigue siendo un único interruptor global que vacía todas las selecciones al cambiar, y tocar un segmento no ofrece elegir; sin commits que lo toquen desde el 2026-09-17

## /spec — opción B (lote 12.5, 2026-10-25)

Jürgen eligió B el 2026-10-12: cada dimensión guarda **incluidos y excluidos a la vez**, y tocar un segmento pregunta.
Medido en `2.2` (`241bd9167`) antes de escribir esto.

### Lo que hay hoy

- Un solo interruptor global, `SessionState.isExcludeMode` (`SessionState.swift:374`). Su `didSet` vacía todas las
  selecciones al cambiar, y `resetExcludeModeIfNeeded` (`:426`) lo apaga solo cuando no queda nada marcado.
- Seis conjuntos por dimensión: cuentas, categorías, subcategorías, etiquetas, necesidades y monedas. Su significado
  depende del interruptor (`session-filters.md`, «`isExcludeMode` viaja con el conjunto»).
- **239 lecturas de `isExcludeMode` en 45 ficheros**: calculadores (`LiveBalanceCalculator`, `PanelBalanceScopeLogic`,
  `PanelTotalAccountsLogic`, `PanelAccountCardLogic`), `FilterService`, los ViewModels de Panel, Estadísticas,
  Registros, Informe y Exportar, las barras de filtros (`FilterControlBar`, `PanelFilterControlBar`, `FilterChipView`),
  la hoja de filtros de Registros (`RecordsFiltersView`, con su segmento «Mostrar solo / Ocultar») y las tartas y tops
  del Panel.
- Los toques de Distribución (`CategoriesTabView`: categorías `:605`, subcategorías `:643`, etiquetas `:681`, necesidades
  `:853/:881`, el Sankey) escriben en el modo activo sin preguntar.

### Modelo nuevo

1. Por dimensión, dos conjuntos: `included` y `excluded` (`EntityFilter<ID>` con los dos `Set` y una regla
   `matches(_ id:)`: si `included` no está vacío, el id tiene que estar; y nunca puede estar en `excluded`). Un mismo id no
   puede estar en los dos: marcarlo en uno lo quita del otro.
2. `isExcludeMode` desaparece como estado. Lo sustituye, solo para la hoja de Registros, el modo de **edición** del
   segmento (qué conjunto escribes al tocar un chip), que ya no vacía nada al cambiar.
3. Migración: al arrancar, si había `isExcludeMode = true`, los conjuntos de hoy pasan a `excluded`; si no, a `included`.
   Los filtros de sesión no se sincronizan, así que no hay cruce entre dispositivos (comprobar el App Group de widgets,
   que lee filtros con `expensesOnlyMode`).
4. `FilterService.matchesEntityFilter` pasa a `EntityFilter.matches`. Los calculadores que reciben «conjunto + modo»
   reciben el `EntityFilter` entero; `PanelViewModel.computeEligibleAccounts` y `StatisticsViewModel.computeEligibleAccounts`
   cambian a la vez (`BalanceKPIParityTests`).

### Gesto

- Tocar un segmento de una gráfica (tartas, barras de necesidad, Sankey, lista de Detalle) **pregunta** «Ver solo esto» /
  «Ocultar esto», con salida de cancelar visible. Si el segmento ya está filtrado, la pregunta ofrece «Quitar el filtro».
- Sin ningún filtro activo también pregunta (B dice «siempre»); ver la propuesta 2 para la alternativa sin pregunta.

### Pantallas que cambian

Barras de chips (un chip por id, con el estilo de «oculto» —contorno rojo, `FilterChipView`— para los excluidos), la
hoja de Registros (las dos listas a la vez), el resumen de filtros activos del Panel y las tartas y tops que atenúan lo
no elegido. Copy nuevo en los 16 locales.

### Riesgos

- Es cálculo financiero de saldo y totales: review adversarial y los tests de paridad (`IncomeExpenseScreenParityTests`,
  `BalanceKPIParityTests`, `ExcludedAccountSelectionTests`) con un fixture que tenga incluidos Y excluidos a la vez.
- 45 ficheros: un PR propio, no mezclado con otro lote.

### Diferidos

- Exportar e Informe pueden seguir leyendo «conjunto + modo» con un adaptador durante una versión.

### Lo que falta decidir (espera decisión de Jürgen)

Cómo pregunta el gesto y cómo se ven incluidos y excluidos juntos: dos propuestas con capturas en la card.

### Las dos propuestas (capturas del PR del lote 12.5: `capturas/card1-propuesta-a.png` y `-b.png`)

- **A · Pregunta al tocar.** Tocar un segmento abre «Ver solo Comida» / «Ocultar Comida» con «Cancelar» a la vista
  (con el importe del segmento arriba). Los filtros conviven en la barra: «Solo Comida» en lila y «Sin Uber» con el
  contorno rojo de lo oculto, cada uno con su ✕.
- **B · Tocar filtra y el aviso deja cambiarlo.** Tocar deja «Solo Comida» al momento, sin pregunta; un aviso de unos
  segundos ofrece «Ocultarla», y después la cápsula del filtro abre su menú «Ver solo / Ocultar / Quitar filtro».

**Recomendación: A.** Es lo que pediste («preguntar») y deja ocultar desde la gráfica en un toque; B ahorra un toque al
ver solo, pero ocultar pasa a ser un gesto escondido (el aviso o la cápsula). Con A, el diálogo es un menú de acciones
con «Cancelar» visible (no un `confirmationDialog` anclado al segmento, que en iOS 26 no pinta el «Cancelar»:
`swiftui-ds.md`).

## Decidido por Jürgen (2026-10-25): propuesta A

«Pregunta al tocar»: tocar un segmento abre «Ver solo X» / «Ocultar X» con «Cancelar» a la vista (menú de acciones, no
`confirmationDialog` anclado), y la barra pinta los dos tipos de filtro a la vez (lila / contorno rojo, cada uno con su
✕). Se implementa con el modelo de la opción B de arriba, en una sesión y un PR propios: siguiente paso, lanzar esa
sesión con este `/spec`.
