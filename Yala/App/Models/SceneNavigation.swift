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
    var selectedReportTab: ReportTab = .comparativa

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

    // MARK: - Destinos pendientes

    /// Pending group ID for deep link navigation to specific group.
    /// Set by AppRouter.navigate(.groupDetail) handler, read by GroupsContainerView.
    var pendingGroupID: String?

    /// Registro que esta ventana debe abrir al llegar a Registros (una ventana abierta con «Abrir en una ventana
    /// nueva» desde la fila). Lo consume `RecordsStandaloneView` cuando sus datos ya cargaron.
    var pendingRecordID: PersistentIdentifier?

    /// Set por el FAB del Panel ("Grupo") para abrir el composer "Nuevo gasto" al
    /// llegar al tab Grupos. Consumido por GroupsContainerView cuando haya un grupo
    /// elegible (espeja el patrón de `pendingGroupID`).
    var pendingNewGroupExpense: Bool = false

    /// G3 · último paso de la rama organizador del Welcome: abrir el FORMULARIO de grupo nuevo al aterrizar
    /// en el tab. Espeja `pendingNewGroupExpense` —mismo molde, mismo consumidor— pero es su hermano y no
    /// el mismo flag: aquel exige un grupo elegible para consumirse y este existe precisamente porque
    /// todavía no hay ninguno. Lo consume `GroupsContainerView` al montar.
    var pendingNewGroupForm: Bool = false

    /// ⌘K y ⌘, (iPad con teclado): lo que el Panel debe abrir al estar delante. Lo consume `PanelView`, que es quien
    /// tiene Yala IA y Ajustes en una hoja propia; `RootCommandPerformer` lo pone junto con la selección del Panel.
    var pendingKeyboardPanelRequest: KeyboardPanelRequest?

    /// ⌘F: cada pulsación lo incrementa y `GlobalSearchView` enfoca su campo. Un contador y no un flag: la segunda
    /// pulsación con Buscar ya delante también tiene que enfocar.
    var keyboardSearchRequest: Int = 0

    /// URL of a shared image captured from the Share Extension. Not a flag —
    /// it's the payload that ImageSelectionView consumes once opened. The
    /// .presentSharedImage router intent sets this alongside the sheet.
    var pendingSharedImageURL: URL?

    /// Prefill payload del chat para abrir NewTransactionView con datos pre-llenados.
    /// El `.presentNewTransactionFromChatDraft(...)` router intent setea este payload
    /// junto con `showNewTransactionFromChat = true`.
    var pendingChatDraftPrefill: ChatDraftPrefill?

    /// Flag transient que el PanelShell observa para presentar NewTransactionView
    /// con prefill desde chat. La vista lo limpia tras consumir el payload.
    var showNewTransactionFromChat: Bool = false

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

    /// True mientras MainTabView tiene un sheet propio presentado (downgrade /
    /// trialExpired / milestone). Escrito SOLO por MainTabView. Consultado por
    /// el guard de `.panel` y por la matriz de readiness del shell (cross-node:
    /// el cover del inbox alert no debe montarse encima de un sheet de MainTab).
    var isMainTabModalVisible: Bool = false
}
