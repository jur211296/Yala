//
//  SceneNavigation.swift
//  Yala
//
//  Estado de navegación de UNA ventana (fase 4 del carril adaptativo).
//

import Foundation
import SwiftData

/// La navegación de una ventana: qué pestaña tiene delante, qué tiene pedido abrir y qué la tapa.
///
/// **Por qué vive aquí y no en `SessionState`.** Con una sola ventana daba igual; con dos, cambiar de pestaña en
/// una la cambiaba en la otra y una hoja abierta en una bloqueaba la navegación de la otra (ticket
/// `ipad-multiple-windows-share-one-navigation-state`). Cada ventana crea la suya en su raíz (`SceneRoot`) y la
/// inyecta en el entorno; el código que no es una vista —el arranque, los comandos de teclado, el router— llega a la
/// de la ventana que toca por `SceneRegistry`.
///
/// **Lo que NO está aquí, a propósito:** filtros y período siguen en `SessionState` porque ya eran estado global
/// compartido entre Panel y Estadísticas por diseño.
@Observable @MainActor
final class SceneNavigation: Identifiable {

    /// Identidad de la ventana para el registro y el router. Estable durante la vida de la escena.
    let id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }

    // MARK: - Pestañas

    /// Currently selected main tab (Panel, Statistics, etc.)
    var selectedMainTab: AppTab = .panel {
        didSet {
            if oldValue != selectedMainTab, let screen = LoadTimeMarks.screen(for: selectedMainTab) {
                LoadTimeMarks.begin(screen)
            }
            // Al salir de Estadísticas vuelve el período que tenía la persona antes de que un informe pusiera el suyo
            // (UX 2.2 · L11-2). Sin visita en curso no hace nada.
            if oldValue == .statistics && selectedMainTab != .statistics {
                SessionState.shared.endVisitPeriod()
            }
            // Clear temporary tab when navigating to a permanent tab
            if selectedMainTab != temporaryTab?.appTab && selectedMainTab != .more {
                temporaryTab = nil
            }
        }
    }

    /// Temporary tab shown from "More" - cleared when navigating to another tab
    var temporaryTab: ConfigurableTab?

    /// Currently selected detail tab within Statistics (Trends, Categories, Records)
    var selectedDetailTab: DetailViewTab = .insights

    /// Currently selected tab within Planning (Budgets, Scheduled Payments)
    var selectedPlanningTab: PlanningTab = .budgets

    /// Currently selected tab within Reports (Comparativa, Flujo de caja).
    /// SSOT de la ventana para que el «Más» del dashboard pueda enlazar a una sub-pestaña de Informes.
    var selectedReportTab: ReportTab = .comparativa {
        didSet {
            if oldValue != selectedReportTab, selectedReportTab == .flujoDeCaja { LoadTimeMarks.begin(.cashFlow) }
        }
    }

    /// Pending Task that finalizes a deferred main tab selection (when the
    /// destination tab is hidden in "More" and we need to mount it via
    /// `temporaryTab` first). Cancelled if a new selection comes in while a
    /// previous one is still waiting for the runloop tick — prevents the
    /// `didSet` of a concurrent mutation from clearing `temporaryTab` before
    /// the deferred selection lands.
    @ObservationIgnored private var pendingTabSelectionTask: Task<Void, Never>?

    /// Single entry point to change `selectedMainTab` safely. Centralizes the
    /// "mount-then-select" rule required by iOS 18+ TabView when the target
    /// tab is hidden in "More": adding it via `temporaryTab` and waiting one
    /// runloop tick (50 ms) before assigning `selectedMainTab`. If the tab is
    /// already visible, assigns directly with no latency.
    ///
    /// Honors GC-08 invariant: en la shell de solo grupos únicamente `.groups`, `.more`
    /// y `.search` son alcanzables; el resto se rechaza en silencio. El eje se lee del espejo
    /// global (`SessionState.shared`): es del teléfono, no de la ventana.
    func selectMainTab(_ tab: AppTab) {
        let isGroupsFocusedShell = SessionState.shared.isGroupsFocusedShell
        // GC-08: en la shell reducida solo `.groups`/`.more`/`.search` son alcanzables —
        // consistente con `visibleTabs`.
        if isGroupsFocusedShell {
            let allowed: Set<AppTab> = [.groups, .more, .search]
            guard allowed.contains(tab) else { return }
        }

        let stored = TabBarConfiguration.loadFromStandardDefaults()
        let config = TabBarConfiguration.forMode(
            stored: stored,
            reduceToGroupsOnly: isGroupsFocusedShell)
        let decision = MainTabSelectionLogic.decide(requested: tab, config: config)
        UITestHooks.shared.traceLifecycle("pestaña \(decision.selectedTab)")

        pendingTabSelectionTask?.cancel()
        if decision.requiresDelay, let temp = decision.temporaryTab {
            temporaryTab = temp
            pendingTabSelectionTask = Task {
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    return  // Cancelada por una selección más nueva.
                }
                selectedMainTab = decision.selectedTab
            }
        } else {
            selectedMainTab = decision.selectedTab
        }
    }

    /// Navigate to a specific detail view from any tab
    func navigateToDetail(_ tab: DetailViewTab) {
        selectedDetailTab = tab
        selectMainTab(.statistics)
    }

    /// Navigate to Scheduled Payments in Planning
    func navigateToScheduledPayments() {
        selectedPlanningTab = .scheduledPayments
        selectMainTab(.planning)
    }

    /// Navigate to Budgets in Planning
    func navigateToBudgets() {
        selectedPlanningTab = .budgets
        selectMainTab(.planning)
    }

    /// Navigate to a specific Reports sub-tab (Comparativa / Flujo de caja).
    func navigateToReport(_ tab: ReportTab) {
        selectedReportTab = tab
        selectMainTab(.reports)
    }

    /// Navigate to Groups tab
    func navigateToGroups() {
        selectMainTab(.groups)
    }

    /// Atajo desde el FAB del Panel: navega al tab Grupos y pide abrir el composer
    /// "Nuevo gasto" al montar (GroupsContainerView observa `pendingNewGroupExpense`).
    func navigateToGroupsAndComposeExpense() {
        pendingNewGroupExpense = true
        selectMainTab(.groups)
    }

    /// L13-8 · «Crear grupo» de la hoja «Para dividir un gasto, primero crea un grupo»: el formulario de grupo en la
    /// pestaña y, al crearlo, el gasto.
    func navigateToGroupsAndCreateGroupForExpense() {
        pendingExpenseAfterNewGroup = true
        pendingNewGroupForm = true
        selectMainTab(.groups)
    }

    // MARK: - Destinos pendientes

    /// Pending group ID for deep link navigation to specific group.
    /// Set by AppRouter.navigate(.groupDetail) handler, read by GroupsContainerView.
    var pendingGroupID: String?

    /// Zona del grupo cuyos AJUSTES debe abrir esta ventana: el botón de cada grupo que «necesita tu decisión» al
    /// salir de varios grupos (auditoría UX 2.2 · L19-13). Lo consume `GroupsContainerView` (abre el detalle) y el
    /// detalle de ese grupo (abre sus ajustes).
    var pendingGroupSettingsZoneID: String?

    /// Presupuesto que esta ventana debe abrir al llegar a Presupuestos: el de la alerta tocada (UX 2.2 · L9-5). Lo pone
    /// `ContentView.handleMainTabIntent` al drenar `.navigate(.budgets)` y lo consume `BudgetsListView`.
    var pendingBudgetID: UUID?

    /// Pago planificado que esta ventana debe abrir al llegar a Pagos planificados: el del recordatorio tocado (UX 2.2 ·
    /// L10-13). Lo pone `ContentView.handleMainTabIntent` y lo consume `ScheduledPaymentsView`.
    var pendingScheduledPaymentID: UUID?

    /// La parte de Estadísticas que esta ventana debe poner a la vista al llegar (UX 2.2 · L15-3: «Entradas y salidas»
    /// en Tendencias, las subcategorías en Distribución). Lo pone `ContentView.handleMainTabIntent` y lo consume la
    /// pestaña de esa parte (`TrendsTabView`, `CategoriesTabView`).
    var pendingStatisticsFocus: StatisticsDeepLink.Focus?

    /// Cuenta (`shortcutID`) cuya ficha debe abrir el Panel de esta ventana: la tarjeta del aviso de pago (L10-14). Lo
    /// pone `ContentView.handleMainTabIntent` y lo consume `PanelView`.
    var pendingAccountID: UUID?

    /// Registro que esta ventana debe abrir al llegar a Registros (una ventana abierta con «Abrir en una ventana
    /// nueva» desde la fila). Lo consume `RecordsStandaloneView` cuando sus datos ya cargaron.
    var pendingRecordID: PersistentIdentifier?

    /// Set por el FAB del Panel ("Grupo") para abrir el composer "Nuevo gasto" al
    /// llegar al tab Grupos. Consumido por GroupsContainerView cuando haya un grupo
    /// elegible (espeja el patrón de `pendingGroupID`).
    var pendingNewGroupExpense: Bool = false

    /// El grupo con el que debe abrirse ese composer (UX 2.2 · L12-18: «Apuntar un gasto» al entrar en un grupo). `nil` =
    /// el primero elegible, como el FAB del Panel. Lo consume `GroupsContainerView` junto con `pendingNewGroupExpense`.
    var pendingNewGroupExpenseGroupID: UUID?

    /// L12-18 · lo que pidió «Ya estás en «X»» al cerrarse: apuntar un gasto en ese grupo o abrirlo. Lo deja la hoja de
    /// invitación y lo aplica el `onDismiss` de su cover (`ContentView`), cuando el ancla ya está libre: pedir el
    /// formulario de gasto con el cover aún bajando son dos presentaciones a la vez (review adversarial del 2026-10-21).
    var pendingInviteFollowUp: InviteFollowUp?

    enum InviteFollowUp: Equatable {
        case addExpense(groupID: UUID)
        case viewGroup(groupID: UUID)
    }

    /// G3 · último paso de la rama organizador del Welcome: abrir el FORMULARIO de grupo nuevo al aterrizar
    /// en el tab. Espeja `pendingNewGroupExpense` —mismo molde, mismo consumidor— pero es su hermano y no
    /// el mismo flag: aquel exige un grupo elegible para consumirse y este existe precisamente porque
    /// todavía no hay ninguno. Lo consume `GroupsContainerView` al montar.
    var pendingNewGroupForm: Bool = false

    /// UX 2.2 · L12-11 (decisión B de Jürgen): la persona tocó «Crear grupo» y antes hubo que mandarla a la cuenta o al
    /// consentimiento. Lo arma `GroupsContainerView.requestCreateGroup` al ceder el anchor y lo consume la cadena de
    /// `GroupsBackendInviteModifier` al terminar, que vuelve a pedir el formulario; cancelar cualquier paso lo retira.
    /// Sin esto la cadena terminaba en la pestaña y la persona creía que algo había fallado.
    var pendingCreateGroupAfterIdentity: Bool = false

    /// UX 2.2 · L13-8 (decisión B de Jürgen): «Grupo» del botón + sin ningún grupo pidió crear uno PARA apuntar un gasto.
    /// Al crearlo, la pestaña abre el gasto con el aviso «Ahora apunta el gasto»; cancelar el formulario lo retira, para
    /// que el gasto no salte horas después. Distinto de `pendingNewGroupExpense`, que espera a un grupo que ya existe.
    var pendingExpenseAfterNewGroup: Bool = false

    /// UX 2.2 · L12-12: el grupo (su id) que acaba de crear el formulario de la rama «Crear mi primer grupo» de la
    /// bienvenida, para que la pestaña proponga invitar al aterrizar (L12-10), como tras crear desde ella misma.
    var pendingCreatedGroupInviteID: String?

    /// L12-12 · el formulario de la rama de bienvenida está encima de todo. Mientras lo esté, la pestaña (que ya se montó
    /// debajo al escribirse el alta) no presenta nada propio: ni la hoja de invitar ni el aviso de notificaciones, que
    /// chocarían con el cover y entre sí. Lo pone y lo quita `ContentView`.
    var isWelcomeGroupFormOpen: Bool = false

    /// ⌘K y ⌘, (iPad con teclado): lo que el Panel debe abrir al estar delante. Lo consume `PanelView`, que es quien
    /// tiene Yala IA y Ajustes en una hoja propia; `RootCommandPerformer` lo pone junto con la selección del Panel.
    var pendingKeyboardPanelRequest: KeyboardPanelRequest?

    /// UX 2.2 · L16-5 (opción B de Jürgen, 2026-10-23): el ajuste al que vuelve Ajustes tras cambiar el idioma con el
    /// selector de Yala. Cambiar el idioma reconstruye la app (`.languageDidChange`) y cierra la hoja de Ajustes; el
    /// Panel recién montado la reabre aquí (`PanelSettingsReturnOpening`). Solo lo consume un Panel que APARECE o queda
    /// delante, no uno que ya lo estaba: ése tiene la hoja de Ajustes encima.
    var pendingSettingsReturn: ProfileDestination?

    /// ⌘F: cada pulsación lo incrementa y `GlobalSearchView` enfoca su campo. Un contador y no un flag: la segunda
    /// pulsación con Buscar ya delante también tiene que enfocar.
    var keyboardSearchRequest: Int = 0

    /// URL of a shared image captured from the Share Extension. Not a flag —
    /// it's the payload that ImageSelectionView consumes once opened. The
    /// .presentSharedImage router intent sets this alongside the sheet.
    var pendingSharedImageURL: URL?

    /// Lo soltado en el iPad que no se pudo abrir (PDF vacío o protegido, imagen dañada): el registro por imagen se abre
    /// en este fallo en vez de en Elegir. Lo pone `AppBootstrapper.presentDroppedReceiptFailure` junto con el intent que
    /// abre la hoja, y lo consume `ImageSelectionView` al aparecer. Si el usuario no acepta el consentimiento de IA, lo
    /// retira `PanelSheetsModifier`: si no, la próxima vez que abriera el registro por imagen vería un fallo viejo.
    var pendingImageEntryFailure: ImageEntryFailure?

    /// Prefill payload del chat para abrir NewTransactionView con datos pre-llenados.
    /// El `.presentNewTransactionFromChatDraft(...)` router intent setea este payload
    /// junto con `showNewTransactionFromChat = true`.
    var pendingChatDraftPrefill: ChatDraftPrefill?

    /// Flag transient que el PanelShell observa para presentar NewTransactionView
    /// con prefill desde chat. La vista lo limpia tras consumir el payload.
    var showNewTransactionFromChat: Bool = false

    /// El registro por imagen está abierto en «elige una foto»: nada leído ni elegido todavía. Lo escribe
    /// `ImageSelectionView` al aparecer, al cambiar de fase y al desaparecer. Una foto compartida que llega con la hoja
    /// así puede cerrarla y empezar la lectura (`SharedPhotoPanelSheetLogic`, decisión de Jürgen del 2026-10-12).
    var isImageEntryChoosing: Bool = false

    /// El «?» de un widget del Panel está abierto sin un tamaño cambiado por guardar. Lo escribe `WidgetInfoSheet` (solo
    /// con el VM del Panel), y `PanelShell` lo baja al pedir que se cierre. Ninguna bandera de `PanelSheetState` lo
    /// publica: la hoja es de cada widget.
    var isCleanPanelWidgetInfoVisible: Bool = false

    /// Petición de cerrar el «?» del Panel para que se lea una foto compartida: `WidgetInfoSheet` lo observa y se cierra
    /// si sigue sin cambios. Contador, para que dos peticiones seguidas se vean.
    var panelWidgetInfoCloseRequest: Int = 0

    // MARK: - Lo que tapa esta ventana

    /// Mirrors PanelShell `sheets.showInbox` so the RouterEntryGate can drop
    /// incoming `.showInboxAlert` while the Inbox sheet is already presenting.
    /// Without this, the original bug (notif arrives → fullScreenCover queued
    /// behind the open sheet → surfaces "tardío") could resurrect via a fresh
    /// `.showInboxAlert` raised AFTER the sheet opened.
    var isInboxSheetVisible: Bool = false

    /// Blocker de nivel shell activo en ESTA ventana, `nil` si está libre. En la ventana líder lo escribe SOLO
    /// `ContentView.updateContentViewReadiness` (choke point único); en una seguidora, `FollowerWindowRoot` con el
    /// motivo por el que no deja operar. Los consumidores inferiores (.mainTab/.panel) lo consultan como guard de
    /// drain: con el shell tapado, un intent que setee un sheet propio ESPERA en cola en vez de consumirse tapado
    /// (Clase D). Default "splash": el splash siempre cubre el boot antes del primer recompute.
    var shellModalBlocker: String? = "splash"

    /// True mientras el editor de Más (desde donde se elige la barra de pestañas) está abierto en esta ventana. Lo
    /// escribe SOLO `MoreView`, y `MainTabView` lo baja al desmontarse. Mientras dura, la barra sigue con la
    /// configuración que tenía montada y se vuelve a montar con la nueva al cerrarse el editor (card fozu): montarla
    /// en caliente cerraba la app o dejaba pestañas en negro, y montarla con el editor abierto lo cerraba de golpe.
    var isEditingTabBarLayout: Bool = false

    /// True mientras MainTabView tiene un sheet propio presentado (downgrade /
    /// trialExpired / milestone). Escrito SOLO por MainTabView. Consultado por
    /// el guard de `.panel` y por la matriz de readiness del shell (cross-node:
    /// el cover del inbox alert no debe montarse encima de un sheet de MainTab).
    var isMainTabModalVisible: Bool = false
}
