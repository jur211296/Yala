# Auditoría de fluidez 2.2: animaciones, transiciones y vibraciones

Card `tablero-fluidez-de-toda-la-app-animaciones-trans-pjum` · 2026-10-31 · Frank.

Jürgen, con TestFlight 2.2 (5): «faltan muchas animaciones, vibraciones y transiciones y la app se siente tosca». El caso
que puso de ejemplo fue Grupos: al cambiar a Gráficas o Saldos, primero cambia el chip y un segundo después la página
cambia de golpe.

## Cómo se hizo

- **Grupos y Estadísticas, en vídeo.** Hay grabaciones del simulador de antes y después
  (`capturas/antes-grupos-chips.mp4`, `capturas/despues-grupos-chips.mp4`), medidas con los tiempos de cada fotograma.
- **Lo demás, leyendo el código** vista por vista. **[V]** quiere decir que se vio en el código y **[I]** que es una
  inferencia, a confirmar en el aparato.
- **iPhone y Duo.** Los cambios no dependen del tamaño de pantalla, así que en el Duo valen igual. La regla del repo dice
  que el simulador del Duo no se puede conducir con axe ni con XcodeBuildMCP, y por eso la comprobación en el Duo está
  en el guion de QA.

## La causa del caso de Grupos

El desfase no venía de una carga lenta: estaba en el diseño. `NavigationChipButton.switchTab` (card yc6k) hacía el
cambio de chip en dos tiempos:

1. Animaba la fila de chips durante 0,25 s.
2. Al terminar, montaba la pestaña nueva, sin animación.

Ese orden existía porque montar Saldos o Estadísticas bloquea el hilo principal (0,12–0,27 s en el iPhone). Si chip y
página cambiaban a la vez, la animación del chip transcurría entera durante el bloqueo y la fila saltaba en un fotograma.

Lo medido en el simulador (`antes-grupos-chips.mp4`): tras el toque, la fila se anima unos 0,45 s. Después hay un hueco
sin fotogramas de 0,2 a 0,37 s, que es el montaje, y la página cambia de golpe. Es el orden que Jürgen describió.

**El arreglo: `StagedTabPages`** (`Yala/App/DesignSystem/StagedTabPages.swift`). Invierte el orden:

1. La página nueva se monta debajo de la que se ve, invisible. El bloqueo cae con la pantalla quieta.
2. Cuando ya está montada, la página cambia y la fila empieza a animarse **en el mismo fotograma**.

Medido en `despues-grupos-chips.mp4`: la página nueva sale en el primer fotograma de la animación del chip, que dura
unos 15 fotogramas, y el título grande no se mueve. Estadísticas, que usaba el mismo mecanismo, pasa a la misma pieza.

**Por qué la página no se funde.** Se probó y se retiró. En iOS 26 el título grande vive dentro del scroll de la
página, así que fundir la página fundía también «Viaje a Cusco», que desaparecía unos 0,3 s hasta que se desmontaba la
página vieja. La página cambia en seco, como con un control segmentado del sistema, y lo que se mueve es la cápsula.

## Sistema común

Está documentado en `.claude/rules/swiftui-ds.md`, en «Fluidez: el sistema común».

| Pieza | Qué es | Dónde |
|---|---|---|
| Curvas con nombre | `DS.Animation.selection` (chips, segmentos), `.appear` (lo que aparece o se va), `.number` (cifras) | `DesignTokens.swift` |
| Mapa de hápticos | selección → `selection()` · éxito → `success()` · aviso → `error()` (nuevo) · borrado → `warning()` | `DS.Haptic` |
| Cifras que ruedan | `AmountText(…, animatesValue: true)`: `numericText` con animación implícita; solo rueda lo que cambia con la cifra ya a la vista | `AmountText.swift` |
| Chip y página juntos | `StagedTabPages` + `StagedTabSelection` | `StagedTabPages.swift` |
| Reducir movimiento | Todo lo nuevo pasa por `dsAnimation` / `reduceMotion ? nil :` | — |

## Tabla por vista

**Estado:** ✅ quiere decir hecho en este PR. **C1–C8** remite a la card de 2.2 que lo recoge (lista al final).
«Impacto» es el que tiene para quien usa la app.

### Transversal

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Cambio de chip (Estadísticas, Grupos) | [V] Chip primero y página de golpe 0,25 s + montaje después | `NavigationChipsBar.swift` | alto | ✅ `StagedTabPages` |
| Háptico al cambiar de chip (las cuatro filas) | [V] Ninguno | `NavigationChipButton` | medio | ✅ |
| Cifras de `AmountText` | [V] Sin `numericText`; en Categorías, Tendencias y Pagos el `numericText` no tenía animación que lo disparara | `AmountText.swift` | alto | ✅ heros (ver abajo) |
| `GenericSegmentedPill` | [V] `dsWithAnimation` dentro de pestaña: la cápsula saltaba; sin háptico | `SegmentedPills.swift` | alto | ✅ |
| Esqueleto → datos (`yalaSkeleton`) | [V] if/else: los datos sustituyen al esqueleto de golpe | `ViewModifiers.swift` | alto | ✅ C1 (2026-11-01) |
| Háptico de aviso | [V] `warning()` (golpe rígido) se usaba también para errores | `DS.Haptic` | alto | ✅ `error()` nuevo |
| Ajustes abierto desde Más no anima | [V] `.transaction { $0.animation = nil }` en `ProfileView` solo desde Más | `MoreView.swift:122` | alto | C5 |
| Aviso «Deshacer» (borrar, descartar, saltar pago) | [V] Aparece y se va sin transición; sin háptico al deshacer | `DraftDiscardUndoNotice.swift` | medio | ✅ C3 (2026-11-01) |
| Inserción y borrado de filas | [V] `LazyVStack` sin transición en Registros, Grupos y Presupuestos | varios | alto | ✅ C3 (2026-11-01) |

### Panel

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Cifra del hero | [V] Sin `numericText` | `HeroMonthView.swift` | alto | ✅ |
| Plegar «Tu panorama» | [V] Transiciones sin animación: saltaba la columna entera | `PanelPanoramaSection.swift` | alto | ✅ implícita en el contenedor |
| Píldoras Entró/Salió, chip «solo gastos» | [V] Háptico sí; `dsWithAnimation` en pestaña: el atenuado salta | `HeroMonthView.swift:211,263` | medio | C2 |
| Quitar chips de filtro | [V] 8 `dsWithAnimation` que no animan; sin háptico | `PanelFilterControlBar.swift` | medio | C2 |
| Período del hero | [V] Cambia de golpe; sin háptico | `PanelHeroSection.swift:31` | medio | C2 |
| Widgets: filtro de pagos, métrica de tendencias, tipo de cambio, presupuesto elegido | [V] Píldoras que saltan; sin háptico | widgets | medio | C2 |
| Tartas: seleccionar sector, recorrer gráficas | [V] Sin háptico al cambiar de sector o de barra | `CategoriesPieWidget`, `CashFlowWidget`, `TrendChartView` | medio | C4 |
| Esqueleto inicial | [V] De golpe | `PanelView.swift:308` | alto | ✅ C1 (2026-11-01) |
| Checklist de configuración, anillo de puntuación | [V] Animaciones sin Reducir movimiento | `SetupChecklistCard`, `ScoreRingView` | medio | C6 |
| Avisos y flotantes | [V] Implícitas con Reducir movimiento | `PanelView` | — | ya bien |

### Registros

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Totales del hero (saldo, entradas, salidas) | [V] Sin `numericText` | `RecordsTabView.swift` | medio | ✅ |
| Selección de filas | [V] Háptico doble (explícito y `sensoryFeedback`) | `RecordRowView.swift` | medio | ✅ uno |
| Lista ↔ Calendario, mes, día | [V] `dsWithAnimation` en pestaña; sin háptico | `RecordsTabView`, `RecordsCalendarView` | medio | C2 |
| Filas que entran o se borran | [V] Sin transición; el deshacer las devuelve de golpe | `RecordsTabView.swift:424` | alto | ✅ C3 (2026-11-01) |
| Confirmar borrado, borrado en lote, deshacer | [V] Sin háptico al confirmar | `RecordRowContextMenu`, `RecordsSelectionBar` | medio | C4 |
| Barra de selección | [V] Spring sin Reducir movimiento | `RecordsStandaloneView.swift:315` | medio | C6 |

### Bandeja (es una hoja, y ahí `withAnimation` sí anima)

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Aprobar desde el editor | [V] Sin háptico | `InboxDraftEditSheet.swift` | medio | ✅ éxito |
| Deslizar para descartar, borrar o aprobar | [V] Animado; hápticos con `UIImpactFeedbackGenerator` crudo | `InboxView.swift` | bajo | C4 |
| Selección múltiple, descartar desde el editor | [V] Sin háptico | `InboxView`, `InboxDraftEditSheet` | medio | C4 |

### Grupos

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Cambio de pestaña Gastos / Saldos / Estadísticas | [V] Desfasado (ver la causa) | `GroupDetailView.swift` | alto | ✅ |
| Saldo grande del grupo | [V] Sin `numericText` | `GroupBalanceHero.swift` | medio | ✅ |
| Confirmar liquidación | [V] Háptico doble (botón y ViewModel), también si fallaba | `GroupBalancesView.swift` | medio | ✅ uno, al confirmar |
| Carga de la lista | [V] `ProgressView` → lista de golpe | `GroupsContainerView.swift:106` | medio | ✅ C7 (2026-11-01) |
| Archivados, tarjeta de avisos | [V] `withAnimation` en pestaña: de golpe | `GroupsContainerView`, `GroupNotificationsOptInCard` | medio | C2 |
| Borrar gasto, quitar saldo inicial | [V] Sin háptico de éxito; la fila se va de golpe | `GroupDetailViewModel`, `GroupRecordsView` | alto | ✅ C3 (2026-11-01) |
| Tipo de reparto, participantes y pagador | [V] Sin háptico; la cápsula se funde | `SplitTypeSegmentedSelector`, `GroupSplitEditorCard` | medio | C4 |

### Estadísticas

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Chips de pestaña | [V] Igual que Grupos | `DetailContainerView.swift` | alto | ✅ |
| Hero de Categorías, Tendencias e Insights | [V] `numericText` sin animación (no rodaba) o sin `numericText` | `CategoriesTabView`, `TrendsTabView`, `InsightsTabView` | alto | ✅ |
| Detalle/Gráficas, modo de Insights | [V] Píldora que saltaba | `GenericSegmentedPill` | alto | ✅ |
| Período (flechas y menú) | [V] Implícita bien hecha; sin háptico | `StatisticsPeriodControl.swift` | medio | C4 |
| Secciones plegables de Insights, «Ver período anterior», Sankey | [V] `dsWithAnimation` en pestaña | `InsightsTabView`, `TrendsTabView`, `CategoriesTabView` | medio | C2 |
| Flotantes al desplazar | [V] Sin implícita: de golpe (en el Panel sí se funden) | `DetailContainerView.swift:365` | medio | C2 |
| Carga de Insights y de la IA | [V] `ProgressView` → contenido de golpe | `InsightsTabView.swift:77,325` | medio | ✅ C7 (2026-11-01) |

### Presupuestos y Pagos

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Guardar y borrar presupuesto | [V] Sin háptico | `BudgetEditorView.swift` | medio | ✅ |
| Hero «Por pagar» | [V] `numericText` sin animación | `ScheduledPaymentsListView.swift` | medio | ✅ |
| Pago: falta un campo al guardar | [V] Golpe ligero | `ScheduledPaymentEditorView.swift` | medio | ✅ `error()` |
| Pago: scroll al campo y «Más opciones» | [V] `dsWithAnimation(false)` fijo: ignoraba Reducir movimiento | `ScheduledPaymentEditorView.swift:220,369` | medio | ✅ |
| Barra de progreso del presupuesto | [V] El ancho no anima | `BudgetProgressBar.swift` | medio | C2 |
| Lista/Calendario de pagos, pausar, marcar pagado | [V] Sin animación ni háptico | `ScheduledPaymentsListView`, `ScheduledPaymentPaidSheet` | medio | C2 · C4 |
| Gráficas del presupuesto | [V] `dsWithAnimation` / `withAnimation` en pestaña | `BudgetChartsView.swift` | medio | C2 |

### Yala IA

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Aparición de mensajes | [V] De golpe | `ChatSheetView.swift` | alto | ✅ suben y se funden |
| Indicador «escribiendo» | [V] Entra y sale en seco | `ChatSheetView.swift` | alto | ✅ fundido |
| Enviar pregunta | [V] Sin háptico | `ChatSheetView.swift` | medio | ✅ ligero |
| Guardar borrador desde el chat | [V] Sin háptico | `ChatAssistantViewModel.swift` | alto | ✅ éxito |
| Tarjeta del borrador: pendiente → guardado / descartado | [V] `switch` sin transición | `ChatTransactionDraftCard.swift` | alto | C8 |
| Banner de error, panel de voz, nueva conversación | [V] Sin transición ni háptico; voz sin Reducir movimiento | `ChatSheetView`, `VoiceListeningPanel` | medio | C8 |

### Ajustes, Perfil y Más

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Elegir tema | [V] Sin háptico | `ThemeSettingsView.swift` | medio | ✅ |
| Animaciones de Ajustes abierto desde Más | [V] Apagadas por un `.transaction` | `MoreView.swift:122` | alto | C5 |
| Hojas de selección (período, decimales, idioma…) | [V] Sin háptico | `PersonalizationSettingsView` | medio | C4 |
| Borrar categoría, notificación; guardar notificación, datos personales | [V] Sin háptico | varios | medio | C4 |
| Reordenar listas | [V] Sin háptico al soltar | varios | bajo | C4 |

### Onboarding y Welcome

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Pasos, contador, confeti, restaurar | [V] Bien: transiciones con Reducir movimiento | `OnboardingView`, `WelcomeFlowContainer` | — | ya bien |
| Avanzar paso, elegir opción, terminar | [V] Ni un háptico en `OnboardingView` | `OnboardingView.swift` | medio | C4 |

### Formularios y hojas

| Interacción | Estado antes | Dónde | Impacto | Estado |
|---|---|---|---|---|
| Gasto / Ingreso / Transferencia | [V] La cápsula se fundía; sin háptico | `TransactionTypeSelectorView.swift` | alto | ✅ se desliza y vibra |
| «Hacer recurrente» con el formulario incompleto | [V] Aviso sin háptico | `NewTransactionView.swift` | medio | ✅ `error()` |
| Guardar cuenta, categoría, etiqueta | [V] Sin háptico | `AccountFormView`, `CategoryDetailView`, `TagFormView` | alto | ✅ éxito |
| Borrar categoría, etiqueta | [V] Sin háptico | ídem | medio | ✅ borrado |
| Categoría nueva sin subcategorías | [V] Alerta sin háptico | `CategoryDetailView.swift` | bajo | ✅ `error()` |
| Chips de cuenta, categoría y necesidad; etiquetas; selectores | [V] Sin háptico | `SelectionChip`, `TagSelectorSheet`… | medio | C4 |
| Equivalente «≈ S/ X» | [V] `numericText` sin animación | `NewTransactionView.swift:1011` | medio | C2 |
| Errores al guardar (alertas) | [V] Sin háptico | `NewTransactionView`, `AccountFormView`… | medio | C4 |
| Más opciones y modos de cuenta, grupo y ajustes del grupo | [V] `withAnimation` sin Reducir movimiento | `AccountFormView`, `GroupFormView`, `GroupSettingsView` | bajo | C6 |

## Cards para lo que no entró (2.2, «ready to launch», `cierra-sola`, frank)

- **C1** (`0qhn`): el esqueleto se funde con los datos sin duplicar el árbol de accesibilidad.
- **C2** (`s1ve`): animaciones que no animan dentro de las pestañas (los `withAnimation` / `dsWithAnimation` muertos).
- **C3** (`fb1j`): las filas entran y se van con transición (Registros, Grupos, Presupuestos) y el aviso de Deshacer también.
- **C4** (`86b1`): segunda tanda de hápticos (selectores, borrados, gráficas, Bandeja, onboarding, `DS.Haptic` en la Bandeja).
- **C5** (`bbap`): Ajustes abierto desde Más no anima.
- **C6** (`m1hw`): animaciones que no respetan Reducir movimiento.
- **C7** (`tyh9`): cargas que aparecen de golpe (lista de Grupos, Insights, IA, saludo del chat).
- **C8** (`6sld`): Yala IA, con la tarjeta del borrador, el banner de error y el panel de voz.

**Por qué C1 quedó fuera.** Se probó en este PR y se retiró. Mientras dura el fundido conviven dos copias de la
pantalla, y cada botón sale dos veces en el árbol de accesibilidad. Un XCUITest que toque justo en ese momento falla con
«varios elementos». La card pide resolverlo antes de aplicarlo al Panel.

**C1, C3 y C7 resueltas el 2026-11-01** (sesión S35l): `ContentTransitions.swift` y la regla de `swiftui-ds.md`. El
esqueleto se funde encima de los datos y su salida no se lee ni se toca; con el esqueleto redactado no se midió ningún
duplicado, ni siquiera con las dos copias montadas a la vez.
