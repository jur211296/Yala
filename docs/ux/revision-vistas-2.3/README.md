# Revisión por vistas 2.3 · Índice

Índice de la revisión de UX por vistas de Yala 2.3: qué zonas se revisaron, dónde abrir cada una, sus problemas
principales y lo que queda por decidir. **No añade conclusiones propias**: todo lo de abajo sale de la `ficha.md` de cada
zona, que manda si algo no cuadra. Ninguna zona cambia la app; cada una deja problemas priorizados, alternativas
maquetadas y una recomendación, y decide Jürgen.

> **Índice final (7-nov-2026).** Cierra la serie con lo que había en `origin/2.3` ese día: **3 de las 11 zonas
> revisadas** (Panel, Registros y Nuevo registro). Las otras 8 quedan **pendientes**: su ficha aún no estaba mergeada y
> ninguna tenía PR abierto. No se esperó por ellas; cuando aterricen, su ficha manda y este índice se puede ampliar.

El reparto de zonas sale del mapa de cobertura fijo del 6-nov-2026 (`~/Claude/flota/cobertura-vistas-yala-2.3.md`, en la
Mini), hecho desde las vistas de `Yala/**/Views/` en `origin/2.3`.

## Estado

| Zona | Estado | Abrir | Respaldo para el móvil |
|---|---|---|---|
| 30 · Panel | Revisada | [`30-panel/index.html`](30-panel/index.html) | [`revision-panel.pdf`](30-panel/revision-panel.pdf) |
| 31 · Registros, filtros, calendario y búsqueda | Revisada | [`31-registros/index.html`](31-registros/index.html) | [`revision-registros.pdf`](31-registros/revision-registros.pdf) |
| 32 · Nuevo registro, favoritos, voz y foto | Revisada | [`32-nuevo-registro/index.html`](32-nuevo-registro/index.html) | [`revision-nuevo-registro.pdf`](32-nuevo-registro/revision-nuevo-registro.pdf) |
| 34 · Planificación | Pendiente: ficha aún no mergeada al 7-nov | — | — |
| 35 · Estadísticas | Pendiente: ficha aún no mergeada al 7-nov | — | — |
| 36 · Reportes y Flujo de caja | Pendiente: ficha aún no mergeada al 7-nov | — | — |
| 37 · Grupos en el uso diario | Pendiente: ficha aún no mergeada al 7-nov | — | — |
| 38 · Bandeja, Yala IA, correo del banco, Apple Pay y Siri | Pendiente: ficha aún no mergeada al 7-nov | — | — |
| 39 · Cuentas, tarjetas, categorías, etiquetas y divisas | Pendiente: ficha aún no mergeada al 7-nov | — | — |
| 40 · Perfil, Más, Ajustes, Pro y ayuda | Pendiente: ficha aún no mergeada al 7-nov | — | — |
| 41 · Dónde viven tus datos | Pendiente: ficha aún no mergeada al 7-nov | — | — |

Cada `index.html` enlaza sus páginas y lleva las capturas al lado, en `capturas/`. El PDF de cada zona trae lo mismo en un
solo archivo.

---

## 30 · Panel

Ficha: [`30-panel/ficha.md`](30-panel/ficha.md).

**Vistas cubiertas.** PanelView, HeroMonthView, AccountsCarouselView, AccountCardView, FinancialScoreView, ScoreRingView,
TrendChartView, WidgetInfoChipView (hojas de ayuda) y PanelSectionsConfigView. Casos: mes típico, mes recién empezado,
montos ocultos, varias divisas, cargando, texto grande (AX3 y máximo) e iPad. 38 capturas del simulador con datos
ficticios. «Sin conexión» va documentado desde el código, sin verlo en pantalla.

**Problemas principales.**

| | Problema | Recomendada |
|---|---|---|
| PN-1 · alta | «Balance» (entró − salió) se lee como lo que tienes; el total de las cuentas no está a la vista | B: total en «Tus finanzas» |
| PN-2 · alta | La nota de salud da 99-100 con pocos datos y no ve un presupuesto pasado ni una cuenta en rojo | A + B: sin nota hasta tener datos, y decir lo que no ve |
| PN-6 · alta | Con texto grande la cifra principal es lo más pequeño de la pantalla; acciones y títulos cortados | A + B: la cifra escala y el hero se reordena |
| PN-3 · media | El día 1 del mes: nota 96, gráfica de un punto, −100 % | A + B: «Día 1 de 31» y ventana de 30 días |
| PN-4 · media | La gráfica exagera la caída; «+10.3 %» no dice contra qué, «PEN» y «x̄», eje «nov 24» = año | A + B: etiquetas claras, inicio y fin a la vista |
| PN-5 · media | Cuentas de una en una, sin total ni aviso de rojo; plegar oculta la nota; hueco en el iPad | C en iPhone + D en iPad |
| PN-7 · media | Con montos ocultos, la ayuda «?» de la gráfica dice el saldo exacto | A: la ayuda usa la máscara |
| PN-8 · baja | Configurar Panel: iconos sin texto, «Restablecer» sin aviso, dos sitios para lo mismo | A: botones con texto y confirmación |
| PN-9 · baja | Sin conexión la tasa cae a una tabla y el «≈» no lo dice (no validado en pantalla) | A: la conversión dice la fecha de la tasa |

**Decisiones pendientes para Jürgen.**

1. PN-1: ¿dónde vive «lo que tienes» (B en «Tus finanzas», C en el hero, D interruptor)? ¿Se renombra «Balance» (A)?
2. PN-2: ¿cuántas partes hacen falta para enseñar una nota? ¿Se reabre la escala (C) o los pesos (D)?
3. PN-6: ¿la cifra del hero escala con el texto y se reordena en tamaños de accesibilidad?
4. PN-3, PN-4 y PN-5: confirmar las recomendadas o elegir otra.
5. PN-7: ¿se corrige dentro del ticket del ojo que está en QA?
6. PN-9: ¿se prueba en el iPhone en modo avión antes de decidir?

---

## 31 · Registros, filtros, calendario y búsqueda

Ficha: [`31-registros/ficha.md`](31-registros/ficha.md).

**Vistas cubiertas.** RecordsStandaloneView, RecordRowView, RecordDateSectionView, RecordsCalendarView, RecordsFiltersView
+ FilterChipView, GlobalSearchView, el menú contextual y la edición en lote, con texto grande (AX3) e iPad.
TransactionSnippetView (la respuesta de Siri) va reconstruida del código: Siri no se puede conducir en el simulador.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Buscar desaparece justo en Registros y no entiende importes | Alta | B1 · campo de búsqueda dentro de Registros, con importe |
| 2 | Filtrar por cuenta y categoría pide 7 toques, dentro de «···» | Alta | F2 · chips rápidos encima de la lista |
| 3 | Con la lista vacía, el filtro culpable queda fuera de pantalla | Alta | L1 · banda «Filtrando por…» con «Quitar todo» |
| 4 | En «Todo el tiempo», la lista no dice el año ni deja saltar a un mes (9 deslizamientos hasta hace 3 semanas) | Media-alta | T2 · separador de mes fijo que lleva a otro mes (+ T1, año y total del día) |
| 5 | «Seleccionar todo» marca 2.334 registros y el lote no se puede deshacer | Alta | E1 · «Deshacer» también en lote (+ el texto de E2) |
| 6 | Al tocar un día del calendario, lo que cambia queda fuera de la pantalla | Media | C2 · el calendario se pliega a la semana |

Lo barato, según la ficha: B3, F1 + F3, L3, T1 y E2 son cambios de texto o de sitio y no cierran la puerta a lo anterior.

**Decisiones pendientes para Jürgen.**

1. ¿Registros tiene su propio campo de búsqueda (B1), y Buscar busca también por importe?
2. ¿Fila fija de chips sobre la lista (F2), o solo «Filtros» a la vista y arreglar la hoja de categorías (F1 + F3)?
3. ¿Los filtros siguen siendo de la sesión (los ven Panel y Estadísticas) o pasan a ser de cada pantalla (L4)?
4. ¿Separador de mes y año en la cabecera (T2 + T1)? ¿Registros sigue abriendo en «Todo el tiempo»?
5. ¿«Deshacer» en lote (E1)? Pide medir cuánto cuesta guardar el «antes» de miles de registros.
6. ¿Calendario plegado a la semana (C2) o el día en una hoja (C1)? ¿Se reabre L8-10 para poner moneda en la celda?

---

## 32 · Nuevo registro: gasto, ingreso, transferencia, favoritos, voz y foto

Ficha: [`32-nuevo-registro/ficha.md`](32-nuevo-registro/ficha.md).

**Vistas cubiertas.** NewTransactionView, TransactionTypeSelectorView, TransferAmountInputView, TransactionSuccessView,
FavoritesListView + FavoriteRowView + FavoriteEditorView, VoiceRecordingView e ImageSelectionView (recibo), con texto
grande (AX3) e iPad. TransactionAmountInputView no tiene captura: no se usa en ninguna parte (código muerto). La pantalla
«Sin conexión» de voz y foto va reconstruida del código; la cámara no existe en el simulador.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Con el teclado abierto, lo que falta y «Guardar» quedan debajo: el café cuesta 6 toques + 4 teclas | Alta | G1 · barra sobre el teclado con lo que falta y «Guardar» |
| 2 | Para un café hay que adivinar la categoría: sin recientes al empezar y «café» no encuentra nada | Alta | C2 · las 3 categorías más usadas a la vista (+ C3, palabras en el buscador) |
| 3 | Con texto grande, la zona fija de «Guardar» se monta sobre el formulario; 2.2 ya lo arregló y 2.3 no lo tiene | Alta | Z2 · el botón dice lo que falta, sobre Z1 · traer el arreglo de 2.2 |
| 4 | El importe escrito en soles pasa a dólares al elegir la cuenta, sin aviso | Media-alta | M1 · decirlo con palabras (+ M4, la cuenta en soles primero) |
| 5 | Cuando voz o foto fallan, «a mano» empieza de cero; el muro de Pro promete «a mano» sin botón | Media-alta | V1 · «Apuntarlo a mano» trae lo entendido (+ V3, el botón del muro) |
| 6 | Transferencia entre monedas: dos importes sin nombre y las cuentas lejos | Media-alta | T1 · cada importe con su cuenta (+ T2, «¿cuánto llegó?») |
| 7 | Repetir un favorito no es «un toque»: rellena 12.00 y hay que borrarlo; solo vive en el formulario | Media | F1 · el importe del favorito viene seleccionado (+ F2, favoritos en el Panel) |

Lo barato, según la ficha: Z1, V3, F4, M1 y C3. La ficha avisa además de que `origin/2.3` no tiene seis arreglos de 2.2
que tocan esta zona; la revisión es de 2.3 tal como está.

**Decisiones pendientes para Jürgen.**

1. ¿Barra sobre el teclado (G1)? ¿El formulario abre con el teclado en el importe por defecto (hoy «No abrir»)?
2. ¿Fila de categorías frecuentes (C2)? ¿Cuáles son las 3 de arranque para quien empieza?
3. ¿El botón dice lo que falta (Z2, reabre L2-2)? ¿Cuándo se integra 2.2 en 2.3 (trae el arreglo de la zona fija, Z1)?
4. ¿Aviso al cambiar de moneda (M1) y la hoja de cuentas con la moneda principal primero (M4)?
5. ¿«Apuntarlo a mano» precarga lo entendido (V1)? ¿Y el muro de Pro suma ese botón (V3)?
6. ¿Importes con su cuenta en la transferencia (T1) y «¿cuánto llegó?» (T2)?
7. ¿Importe seleccionado al aplicar un favorito (F1)? ¿Fila de favoritos en el Panel (F2)?

---

## Zonas sin revisar

Ninguna de estas zonas tiene ficha en `origin/2.3` al cerrar este índice (7-nov-2026), y ninguna tenía PR abierto. El
motivo es el mismo para todas: **ficha aún no mergeada al 7-nov**. Sin ficha no hay problemas ni decisiones que
resumir: este índice no los inventa.

| Zona | Vistas que le tocan, según el mapa | Motivo |
|---|---|---|
| 34 · Planificación: presupuestos y pagos planificados | PlanningView, BudgetsListView, BudgetRowView, BudgetDetailView, BudgetEditorView, BudgetChartsView, ScheduledPaymentsView, ScheduledPaymentsListView, ScheduledPaymentRowView, ScheduledPaymentDetailView, ScheduledPaymentEditorView | Ficha aún no mergeada al 7-nov |
| 35 · Estadísticas | StatisticsView, CategoriesTabView, TrendsTabView, RecordsTabView, InsightsTabView, DetailContainerView, PeriodComparisonChartView, SankeyChartView | Ficha aún no mergeada al 7-nov |
| 36 · Reportes y Flujo de caja/proyectado | FinancialReportView, NetFlowSummaryView, PivotRowView, CashFlowSetupView, CashFlowTableView, CashFlowMonthDetailView y «Ver proyectado» en Tendencias, Panel y widgets | Ficha aún no mergeada al 7-nov. El mapa la pone después de la mejora de flujo de caja, cuyo PR seguía abierto ese día |
| 37 · Grupos en el uso diario | GroupsContainerView, GroupCardView, GroupDetailView, GroupRecordsView, GroupBalancesView, GroupStatsView, GroupMembersView, GroupSettingsView, GroupsGlobalSettingsView, GroupFormView, GroupExpenseComposerView, GroupExpenseFormView, GroupExpenseSuccessView, GroupSplitSelectorView, GroupTwoPersonSplitView, GroupReceiptSplitView, MemberPickerView, SettlementFormView, GroupOpeningBalanceFormView | Ficha aún no mergeada al 7-nov |
| 38 · Bandeja, Yala IA, correo del banco, Apple Pay y Siri | InboxView, InboxDraftRowView, InboxApproveSuccessView, InboxBulkApproveSuccessView, GroupDraftLinkCandidatesView, ChatSheetView, ChatAttachmentsView, BankEmailForwardingView, ApplePayAutomationGuideView, SiriShortcutsView | Ficha aún no mergeada al 7-nov |
| 39 · Cuentas, tarjetas, categorías, etiquetas y divisas | AccountFormView, AdjustmentModeSelectorView, AccountsSettingsListView, CategoriesSettingsListView, CategoryDetailView, SubcategoryDetailView, SubcategoryNeedSelectorView, TagsSettingsListView, TagFormView, CurrencySettingsView | Ficha aún no mergeada al 7-nov |
| 40 · Perfil, Más, Ajustes generales, Pro y ayuda | ProfileView, PersonalDetailsView, YalaAccountView, MoreView, PersonalizationSettingsView, ThemeSettingsView, AppIconSettingsView, TabBarConfigView, NotificationsSettingsView, PermissionsSettingsView, SmartInsightsSettingsView, AIPrivacySettingsView, BudgetsFavoritesSettingsView, UsageModeSettingsView, FaceIDProtectionGuideView, SubscriptionView + SubscriptionSuccessView, FAQView, TutorialsListView + TutorialDetailView + TutorialCompletionView, ExportRecordsView, GroupsExportView, UserDataResetView | Ficha aún no mergeada al 7-nov |
| 41 · Dónde viven tus datos: nube, iCloud y cierre de sesión (solo comprensión) | StorageSettingsView, iCloudSyncSettingsView, CloudConsentView, CloudProgressStepsView, StorageSignInChooserView, StorageMigrationBlockedView, ReturnToFullYalaView, SignOutRelaunchView, GroupBatchLeaveView (CloudSyncDebugView solo si es visible al usuario) | Ficha aún no mergeada al 7-nov |

**Fuera de la serie, a propósito** (según el mapa): Onboarding y alta (Welcome, invitación, consentimiento de Grupos,
entrada a Grupos), que cubre la guía visual del usuario nuevo; los componentes compartidos se miran dentro de la zona que
los usa; SplashScreenView y WidgetNoDataInviteView entran en Panel solo si salen en su caso. El mapa no tiene zona 33.
