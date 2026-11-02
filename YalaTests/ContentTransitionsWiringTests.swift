//
//  ContentTransitionsWiringTests.swift
//  YalaTests
//
//  Cards C1, C3 y C7 de la auditoría de fluidez (2026-11-01): source-scan de lo que un cambio inocente desharía sin que
//  ningún test de comportamiento lo note. Que se funda de verdad se vio en vídeo (capturas del PR); que el fundido del
//  esqueleto no duplique botones lo mide `SkeletonFadeAccessibilityUITests`.
//

import Foundation
import Testing

@Suite("Transiciones de contenido — esqueleto, filas y cargas (source-scan)")
struct ContentTransitionsWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Las líneas de código, sin comentarios, para que documentar el patrón no cuente como usarlo.
    private static func code(_ relativePath: String) throws -> [String] {
        try source(relativePath).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    // MARK: - La salida de una carga

    /// Lo que se va al terminar una carga deja de leerse y de tocarse desde el primer fotograma: sin eso, durante el
    /// fundido cada botón sale dos veces en el árbol de accesibilidad (lo que tumbó el primer intento, card pjum).
    @Test func loadingExit_hidesFromAccessibilityAndTouches() throws {
        let lines = try Self.code("Yala/App/DesignSystem/ContentTransitions.swift")
        #expect(lines.contains(".opacity(phase.isIdentity ? 1 : 0)"))
        #expect(lines.contains(".accessibilityHidden(!phase.isIdentity)"))
        #expect(lines.contains(".allowsHitTesting(phase.isIdentity)"))
        #expect(lines.contains(".asymmetric(insertion: .opacity, removal: AnyTransition(LoadingExitTransition()))"))
    }

    /// El esqueleto sale encima y con esa salida; los datos entran debajo ya opacos. Dos ramas: los datos se siguen
    /// montando de nuevo al cargar, como antes.
    @Test func skeleton_fadesOverTheDataWithTheLoadingExit() throws {
        let lines = try Self.code("Yala/App/Theme/ViewModifiers.swift")
        let start = try #require(lines.firstIndex(of: "struct YalaSkeletonModifier: ViewModifier {"))
        let body = Array(lines[start..<min(start + 30, lines.count)])
        let skeleton = try #require(body.firstIndex(of: ".shimmer()"))
        #expect(body[skeleton + 1] == ".transition(.loadingPlaceholder)")
        #expect(body[skeleton + 2] == ".zIndex(1)")
        #expect(body.contains(".transition(.identity)"), "Los datos entran fundiéndose: a mitad, el fondo de debajo asoma.")
        #expect(body.contains(".animation(reduceMotion ? nil : Self.fade, value: isLoading)"))
        #expect(body.contains { $0.contains("UITestHooks.skeletonFadeSeconds.map { .easeInOut(duration: $0) } ?? DS.Animation.appear") })
    }

    /// Los dos esqueletos de la card: el Panel y el detalle de grupo.
    @Test(arguments: [
        ("Yala/App/Views/Panel/PanelView.swift", ".yalaSkeleton(!viewModel.isReady)"),
        ("Yala/App/Views/Groups/GroupDetailView.swift", ".yalaSkeleton(!viewModel.isReady)"),
    ])
    func skeletonScreens_keepTheModifier(_ path: String, _ needle: String) throws {
        #expect(try Self.code(path).contains(needle), "\(path) ya no pasa por yalaSkeleton.")
    }

    /// Cada marcador de carga de la card C7 sale con la salida que no duplica.
    static let loadingPlaceholders: [(path: String, count: Int)] = [
        ("Yala/App/Views/Groups/GroupsContainerView.swift", 1),
        ("Yala/App/Views/Statistics/InsightsTabView.swift", 4),
        ("Yala/App/Views/Statistics/CategoriesTabView.swift", 1),
        ("Yala/App/Views/Statistics/TrendsTabView.swift", 1),
        ("Yala/App/Views/Chat/ChatGreetingBubble.swift", 1),
    ]

    @Test(arguments: loadingPlaceholders.indices)
    func eachLoadingPlaceholder_leavesWithTheLoadingExit(_ index: Int) throws {
        let (path, count) = Self.loadingPlaceholders[index]
        let found = try Self.code(path).filter { $0 == ".transition(.loadingPlaceholder)" }.count
        #expect(found == count, "\(path): \(found) marcadores con la salida de carga, se esperaban \(count).")
    }

    /// Las cinco tarjetas «Analizando…» de Estadísticas (Insights ×3, Distribución, Tendencias): todas con la salida.
    @Test func everyAIPlaceholder_isWired() throws {
        let paths = [
            "Yala/App/Views/Statistics/InsightsTabView.swift",
            "Yala/App/Views/Statistics/CategoriesTabView.swift",
            "Yala/App/Views/Statistics/TrendsTabView.swift",
        ]
        for path in paths {
            let lines = try Self.code(path)
            for (index, line) in lines.enumerated() where line.hasPrefix("AIInsightCardComponents.loadingPlaceholder(") {
                #expect(lines[index + 1] == ".transition(.loadingPlaceholder)", "\(path):\(index) «Analizando…» sin salida.")
            }
        }
    }

    // MARK: - Registros sin el destello de «Sin registros»

    @Test func records_doesNotShowEmptyBeforeTheFirstFilter() throws {
        let view = try Self.code("Yala/App/Views/Statistics/RecordsTabView.swift")
        let gate = try #require(view.firstIndex(of: "if !viewModel.hasAppliedFilters {"))
        #expect(view[gate + 2] == "} else if viewModel.groupedRecords.isEmpty {")
        #expect(view.contains(".animation(reduceMotion ? nil : DS.Animation.appear, value: viewModel.hasAppliedFilters)"))

        let viewModel = try Self.code("Yala/App/ViewModels/RecordsViewModel.swift")
        #expect(viewModel.contains("private(set) var hasAppliedFilters = false"))
        #expect(viewModel.contains("if !hasAppliedFilters { hasAppliedFilters = true }"))
    }

    // MARK: - Filas que entran o se van

    static let rowLists = [
        "Yala/App/Views/Statistics/RecordsTabView.swift",
        "Yala/App/Views/Groups/GroupRecordsView.swift",
        "Yala/App/Views/Groups/GroupBalancesView.swift",
        "Yala/App/Views/Planning/BudgetsListView.swift",
    ]

    @Test(arguments: rowLists)
    func eachList_animatesItsRowEdits(_ path: String) throws {
        #expect(try Self.code(path).contains { $0.hasPrefix(".animatesRowEdits(ids:") }, "\(path) ya no anima sus filas.")
    }

    /// Solo la edición pequeña, y nunca con Reducir movimiento.
    @Test func rowEdits_animateOnlySmallEditsAndRespectReduceMotion() throws {
        let lines = try Self.code("Yala/App/DesignSystem/ContentTransitions.swift")
        #expect(lines.contains(
            "guard !reduceMotion, let lastIDs, RowListEditLogic.isSmallEdit(from: lastIDs, to: ids) else { return }"))
        #expect(lines.contains("transaction.animation = DS.Animation.appear"))
    }

    // MARK: - El aviso de Deshacer

    @Test func undoNotice_fadesInAndOut_withoutBeingReadWhileLeaving() throws {
        let lines = try Self.code("Yala/App/Views/Inbox/DraftDiscardUndoNotice.swift")
        #expect(lines.contains("retire(window)"), "El aviso vuelve a irse en seco.")
        #expect(lines.contains("hide(animated: false)"), "Un aviso nuevo vuelve a fundirse sobre el de antes.")
        #expect(lines.contains("leaving.accessibilityElementsHidden = true"))
        #expect(lines.contains("leaving.hitArea.frame = .zero"))
        #expect(lines.contains("guard !UIAccessibility.isReduceMotionEnabled, let view = leaving.rootViewController?.view else {"))
        #expect(lines.contains("dsWithAnimation(reduceMotion, DS.Animation.appear) { hasEntered = true }"))
    }

    /// Deshacer un borrado, un descarte o una fecha saltada vibra como un éxito, y solo cuando de verdad se deshizo: el
    /// háptico va en quien deshace, no en el botón del aviso (que también lleva «Ver» o «Editar», que no deshacen nada).
    @Test(arguments: [
        ("Yala/App/Services/RecordPendingDeletion.swift", "self?.undoAll()"),
        ("Yala/App/Services/ScheduledPaymentPendingDeletion.swift", "self?.undoAll()"),
        ("Yala/App/Views/Inbox/InboxDraftEditSheet.swift", "try draftService.returnToPending(draft)"),
        ("Yala/App/Views/Inbox/InboxView.swift", "try draftService.returnToPending(draft)"),
    ])
    func undo_vibratesAfterUndoing(_ path: String, _ undo: String) throws {
        let lines = try Self.code(path)
        let index = try #require(lines.firstIndex(of: undo), "\(path): no está «\(undo)».")
        #expect(lines[index + 1] == "DS.Haptic.success()", "\(path): deshacer dejó de vibrar.")
    }

    @Test func undoSkippedDate_vibratesOnlyIfSaved() throws {
        let lines = try Self.code("Yala/App/Views/Planning/ScheduledPaymentDetailView.swift")
        #expect(lines.contains("if viewModel.unskipOccurrence(payment: payment, date: date) { DS.Haptic.success() }"))
        let notice = try Self.code("Yala/App/Views/Inbox/DraftDiscardUndoNotice.swift")
        #expect(!notice.contains { $0.contains("DS.Haptic") }, "El aviso vuelve a vibrar por su cuenta, también en «Ver».")
    }

    // MARK: - Hápticos de borrado en Grupos

    @Test func groupDeletions_vibrateAfterSucceeding() throws {
        let lines = try Self.code("Yala/App/ViewModels/GroupDetailViewModel.swift")
        for call in [
            "try GroupExpenseService.shared.deleteExpense(expense, in: group)",
            "try GroupExpenseService.shared.removeOpeningBalance(expense, in: group)",
        ] {
            let index = try #require(lines.firstIndex(of: call))
            #expect(lines[index + 1] == "DS.Haptic.warning()", "«\(call)» sin háptico de borrado detrás.")
        }
    }
}
