//
//  FluidezHapticosWiringTests.swift
//  YalaTests
//
//  Cards C4 (segunda tanda de hápticos) y C8 (Yala IA: borrador, error y voz) de la auditoría de fluidez
//  (`docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`), 2026-11-02. Source-scan: un háptico no se ve en un XCUITest, y lo que
//  fija este fichero es el CABLEADO que un cambio inocente desharía (que vibre al confirmar y no al abrir la pregunta,
//  que la Bandeja no vuelva a los generadores sueltos, que el estado del borrador se funda). Que animan de verdad se
//  vio en vídeo (capturas del PR).
//

import Foundation
import Testing

@Suite("Fluidez C4 y C8 — hápticos, borrador, error y voz (source-scan)")
struct FluidezHapticosWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Las líneas con código, sin espacios delante ni comentarios de línea entera.
    private static func code(_ relativePath: String) throws -> [String] {
        try source(relativePath).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    /// Todos los `.swift` de `Yala/App`, con su ruta relativa.
    private static func appSwiftFiles() throws -> [String] {
        let base = repoRoot.appending(path: "Yala/App")
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
            throw CocoaError(.fileReadUnknown)
        }
        return walker.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map { String($0.path.dropFirst(repoRoot.path.count + 1)) }
    }

    /// Índice de la primera línea que contiene `needle`, o `nil`.
    private static func index(of needle: String, in lines: [String]) -> Int? {
        lines.firstIndex { $0.contains(needle) }
    }

    // MARK: - C4 · la Bandeja (y el resto) pasan por DS.Haptic

    /// Un generador suelto es deuda (regla «Fluidez: el sistema común»). Solo `DS.Haptic` los construye.
    @Test func noRawFeedbackGenerators_outsideDSHaptic() throws {
        let offenders = try Self.appSwiftFiles()
            .filter { !$0.hasSuffix("Theme/DesignTokens.swift") }
            .filter { path in
                try Self.code(path).contains { line in
                    line.contains("UIImpactFeedbackGenerator(") || line.contains("UINotificationFeedbackGenerator(")
                        || line.contains("UISelectionFeedbackGenerator(")
                }
            }
        #expect(offenders.isEmpty, "Generadores sueltos fuera de DS.Haptic: \(offenders)")
    }

    /// Aprobar deslizando vibra éxito DESPUÉS de aprobar: antes vibraba al deslizar, también si fallaba.
    @Test func inboxSwipeApprove_vibratesAfterTheApprovalSucceeded() throws {
        let lines = try Self.code("Yala/App/Views/Inbox/InboxView.swift")
        guard let start = Self.index(of: "private func approveDraft(_ draft: InboxDraft", in: lines),
              let approve = lines[start...].firstIndex(where: { $0.contains("try draftService.approveDraft(") }),
              let success = lines[start...].firstIndex(where: { $0.contains("DS.Haptic.success()") })
        else {
            Issue.record("No se encontró la aprobación deslizando o su éxito.")
            return
        }
        #expect(success > approve, "El éxito vuelve a ir antes de que la aprobación salga bien.")
    }

    @Test func inboxSelection_andDiscardFromEditor_vibrate() throws {
        let inbox = try Self.code("Yala/App/Views/Inbox/InboxView.swift")
        guard let toggle = Self.index(of: "private func toggleSelection(_ draft: InboxDraft)", in: inbox) else {
            Issue.record("Sin toggleSelection en la Bandeja.")
            return
        }
        #expect(inbox[toggle + 1] == "DS.Haptic.selection()", "Marcar un borrador en selección múltiple ya no vibra.")

        let editor = try Self.code("Yala/App/Views/Inbox/InboxDraftEditSheet.swift")
        for call in ["try draftService.rejectDraft(draft)", "try draftService.deleteDraft(draft)"] {
            guard let at = Self.index(of: call, in: editor) else {
                Issue.record("Sin \(call) en el editor de la Bandeja.")
                continue
            }
            #expect(editor[at + 1] == "DS.Haptic.warning()", "\(call) ya no vibra al hacerse.")
        }
    }

    // MARK: - C4 · borrar vibra al CONFIRMAR, no al abrir la pregunta

    @Test func recordDeletes_vibrateOnConfirm_notOnTheTrashButton() throws {
        let bar = try Self.code("Yala/App/Views/Records/Components/RecordsSelectionBar.swift")
        #expect(!bar.contains("DS.Haptic.warning()"),
                "La papelera de la barra de selección vuelve a vibrar al abrir la pregunta, no al confirmar.")

        let menu = try Self.code("Yala/App/Views/Records/Components/RecordRowContextMenu.swift")
        #expect(menu.filter { $0 == "DS.Haptic.warning()" }.count == 2,
                "Los dos «Eliminar» de las alertas (uno y en lote) vibran al confirmar.")

        let detail = try Self.code("Yala/App/Views/Records/TransactionDetailSheet.swift")
        guard let open = Self.index(of: "isConfirmingDelete = true", in: detail) else {
            Issue.record("Sin la pregunta de borrado en el detalle.")
            return
        }
        #expect(detail[open - 1] != "DS.Haptic.warning()", "El detalle vuelve a vibrar al abrir la pregunta.")
        #expect(detail.contains("DS.Haptic.warning()"), "El detalle ya no vibra al confirmar el borrado.")
    }

    // MARK: - C4 · errores al guardar: `error()`, no el golpe de borrado

    @Test func groupForms_reportErrorsWithError_notWarning() throws {
        for path in [
            "Yala/App/Views/Groups/GroupFormView.swift",
            "Yala/App/Views/Groups/GroupExpenseFormView.swift",
            "Yala/App/Views/Groups/SettlementFormView.swift",
            "Yala/App/Views/Groups/GroupOpeningBalanceFormView.swift",
        ] {
            let lines = try Self.code(path)
            #expect(!lines.contains("DS.Haptic.warning()"), "\(path) vuelve a usar el golpe de borrado para un error.")
            #expect(lines.contains("DS.Haptic.error()"), "\(path) ya no vibra al fallar.")
        }
    }

    /// Las alertas de error de la cuenta vibran al aparecer, quien sea que las levante.
    @Test func accountForm_errorAlertsVibrateWhenTheyAppear() throws {
        let lines = try Self.code("Yala/App/ViewModels/Accounts/AccountFormViewModel.swift")
        for flag in ["isShowingLineActionError", "isShowingDeleteError", "isShowingSaveError"] {
            #expect(lines.contains("didSet { Self.vibrateIfErrorAppeared(\(flag), was: oldValue) }"),
                    "\(flag) ya no vibra al aparecer.")
        }
        #expect(lines.contains("if isShowing && !was { DS.Haptic.error() }"))
    }

    @Test func newTransaction_saveErrorAndFutureDate_vibrateError() throws {
        let lines = try Self.code("Yala/App/ViewModels/NewTransactionViewModel.swift")
        for flag in ["showFutureDateAlert = true", "saveError = L10n.Common.saveError"] {
            guard let at = Self.index(of: flag, in: lines) else {
                Issue.record("Sin \(flag).")
                continue
            }
            #expect(lines[(at + 1)...(at + 2)].contains("DS.Haptic.error()"), "\(flag) ya no vibra.")
        }
    }

    // MARK: - C4 · selección: gráficas, selectores, reordenar

    @Test func charts_vibrateOncePerSegmentOrBar() throws {
        let trend = try Self.code("Yala/App/Views/Panel/TrendChartView.swift")
        #expect(trend.contains(
            ".sensoryFeedback(.selection, trigger: scrubbedPointDate) { old, new in new != nil && old != new }"))
        let cashFlow = try Self.code("Yala/App/Views/Panel/CashFlowWidget.swift")
        #expect(cashFlow.contains(
            ".sensoryFeedback(.selection, trigger: selectedBarDate) { old, new in new != nil && old != new }"))
    }

    /// Tocar un sector ya vibraba en quien recibe el toque (el anfitrión del filtro por segmento, o `askPanelSegment`
    /// sin él): la tarta no suma el suyo. La review del 2026-11-02 cazó la doble vibración.
    @Test func pieSegmentTap_vibratesOnce_inTheFilterHost() throws {
        let pie = try Self.code("Yala/App/Views/Panel/CategoriesPieWidget.swift")
        #expect(!pie.contains { $0.contains("DS.Haptic.") }, "La tarta vuelve a vibrar por su cuenta: dos por toque.")
        let host = try Self.code("Yala/App/Views/Filters/SegmentFilterChoiceSheet.swift")
        #expect(host.contains(".environment(\\.askSegmentFilter) { newChoice in"))
        #expect(host.contains("DS.Haptic.selection()"), "El anfitrión del filtro ya no vibra al tocar un segmento.")
    }

    /// Toda lista que se reordena vibra al soltar. Una lista nueva con `.onMove` entra sola en este test.
    @Test func everyReorderableList_vibratesOnDrop() throws {
        var missing: [String] = []
        for path in try Self.appSwiftFiles() {
            let lines = try Self.code(path)
            for (i, line) in lines.enumerated() where line.hasPrefix(".onMove") {
                let next = lines[(i + 1)..<min(i + 3, lines.count)]
                if !next.contains("DS.Haptic.selection()") { missing.append("\(path):\(i + 1)") }
            }
        }
        #expect(missing.isEmpty, "Listas que se reordenan sin vibrar al soltar: \(missing)")
    }

    @Test func formSelectors_vibrateOnChoose() throws {
        let cases: [(path: String, anchor: String)] = [
            ("Yala/App/Views/Transactions/AccountSelectorSheet.swift", "private func choose(_ account: Account)"),
            ("Yala/App/Views/Transactions/TagSelectorSheet.swift", "private func toggleTag(_ tag: Tag)"),
            ("Yala/App/Views/Statistics/Components/StatisticsPeriodControl.swift", "stepUnit: stepUnit"),
        ]
        for (path, anchor) in cases {
            let lines = try Self.code(path)
            guard let at = Self.index(of: anchor, in: lines) else {
                Issue.record("Sin \(anchor) en \(path).")
                continue
            }
            #expect(lines[(at + 1)...(at + 3)].contains { $0.contains("DS.Haptic.selection()") },
                    "\(path) ya no vibra al elegir.")
        }
        for path in [
            "Yala/App/Views/Transactions/SubcategorySelectorSheet.swift",
            "Yala/App/Views/Transactions/Components/NeedSelectorSheet.swift",
            "Yala/App/Views/Shared/CurrencySelectorView.swift",
            "Yala/App/Views/Settings/PersonalizationSettingsView.swift",
            "Yala/App/Views/Groups/SplitTypeSegmentedSelector.swift",
            "Yala/App/Views/Groups/GroupSplitEditorCard.swift",
        ] {
            #expect(try Self.code(path).contains { $0.contains("DS.Haptic.selection()") }, "\(path) ya no vibra al elegir.")
        }
    }

    /// El tipo de reparto desliza la cápsula, como Gasto / Ingreso / Transferencia (molde del sistema común).
    @Test func splitTypeSelector_slidesItsCapsule() throws {
        let lines = try Self.code("Yala/App/Views/Groups/SplitTypeSegmentedSelector.swift")
        #expect(lines.contains(".matchedGeometryEffect(id: \"selection\", in: selectionNamespace)"))
        #expect(lines.contains("dsWithAnimation(reduceMotion, DS.Animation.selection) {"))
    }

    // MARK: - C4 · onboarding y pagos

    @Test func onboarding_vibratesOnChoosingAdvancingAndFinishing() throws {
        let lines = try Self.code("Yala/App/Views/Onboarding/OnboardingView.swift")
        #expect(lines.contains("return Button(action: { DS.Haptic.selection(); action() }) {"))
        #expect(lines.contains("DS.Haptic.light()"))
        guard let save = Self.index(of: "try modelContext.save()", in: lines) else {
            Issue.record("Sin el guardado del onboarding.")
            return
        }
        #expect(lines[save + 1] == "DS.Haptic.success()", "Terminar el onboarding ya no vibra éxito tras guardar.")
    }

    @Test func scheduledPayments_vibrateOnPaidSavedDeletedAndPaused() throws {
        let sheet = try Self.code("Yala/App/Views/Planning/Components/ScheduledPaymentPaidSheet.swift")
        #expect(sheet.contains("DS.Haptic.success()"), "Marcar pagado ya no vibra.")
        let editor = try Self.code("Yala/App/Views/Planning/ScheduledPaymentEditorView.swift")
        guard let saved = Self.index(of: "if let id = savedID {", in: editor),
              let delete = Self.index(of: "private func deletePayment()", in: editor)
        else {
            Issue.record("Sin guardado o borrado en el editor de pagos.")
            return
        }
        #expect(editor[saved + 1] == "if !hostVibratesOnSave { DS.Haptic.success() }",
                "Guardar un pago ya no vibra tras guardar (o vibra también cuando el anfitrión ya lo hace).")
        #expect(editor[(delete + 1)...(delete + 2)].contains("DS.Haptic.warning()"), "Borrar un pago ya no vibra.")
        let viewModel = try Self.code("Yala/App/ViewModels/ScheduledPaymentsViewModel.swift")
        #expect(viewModel.filter { $0 == "DS.Haptic.success()" }.count >= 2, "Pausar o «Ya lo apunté» dejaron de vibrar.")
    }

    /// «Hacer recurrente» desde Nuevo registro: el formulario vibra el éxito al cerrarse con su aviso, así que ni la
    /// hoja corta ni el editor completo repiten, y el error ya lo vibra el ViewModel del pago.
    @Test func recurringFromTheForm_vibratesOncePerGesture() throws {
        let form = try Self.code("Yala/App/Views/Transactions/NewTransactionView.swift")
        #expect(form.contains("hostVibratesOnSave: true"), "El editor completo vuelve a vibrar además del formulario.")
        guard let start = Self.index(of: "private func createRecurringPayment(", in: form),
              let end = form[(start + 1)...].firstIndex(where: { $0.hasPrefix("private func ") })
        else {
            Issue.record("Sin createRecurringPayment.")
            return
        }
        #expect(!form[start..<end].contains { $0.contains("DS.Haptic.") },
                "La hoja corta vuelve a vibrar además del aviso de cierre (o del error del ViewModel).")
    }

    // MARK: - C8 · Yala IA

    /// Pendiente → guardado / descartado / fallido se funde, y la tarjeta que se va no se lee: no hay dos «Guardar»
    /// en el árbol durante el fundido.
    @Test func chatDraftCard_swapsStatesWithAFadeThatHidesTheOldOne() throws {
        let card = try Self.code("Yala/App/Views/Chat/ChatTransactionDraftCard.swift")
        #expect(card.contains(".transition(.stateSwap)"))
        let transitions = try Self.source("Yala/App/DesignSystem/ContentTransitions.swift")
        #expect(transitions.contains(
            "static var stateSwap: AnyTransition {\n        .asymmetric(insertion: .opacity, removal: AnyTransition(LoadingExitTransition()))"))
        let sheet = try Self.code("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(sheet.contains(".dsAnimation(DS.Animation.appear, value: draftStatuses, reduceMotion: reduceMotion)"),
                "El hilo ya no anima el cambio de estado de los borradores.")
    }

    @Test func chatDiscard_vibratesOnce() throws {
        let lines = try Self.code("Yala/App/ViewModels/ChatAssistantViewModel.swift")
        guard let start = Self.index(of: "func discardDraft(messageID: UUID, draftID: UUID)", in: lines),
              let end = lines[(start + 1)...].firstIndex(where: { $0.hasPrefix("func ") })
        else {
            Issue.record("Sin discardDraft.")
            return
        }
        #expect(lines[start..<end].filter { $0 == "DS.Haptic.warning()" }.count == 1)
    }

    @Test func chatErrorBanner_animatesAndVibrates() throws {
        let lines = try Self.code("Yala/App/Views/Chat/ChatSheetView.swift")
        guard let banner = Self.index(of: "errorBanner(error)", in: lines) else {
            Issue.record("Sin el banner de error.")
            return
        }
        #expect(lines[banner + 1] == ".transition(.opacity.combined(with: .move(edge: .bottom)))")
        #expect(lines.contains(".dsAnimation(DS.Animation.appear, value: errorMessage, reduceMotion: reduceMotion)"))
        #expect(lines.contains("if new != nil, new != old { DS.Haptic.error() }"))
    }

    @Test func chatNewConversation_vibratesAndRespectsReduceMotion() throws {
        let lines = try Self.code("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(!lines.contains { $0.contains("withAnimation(.easeInOut(duration: 0.25))") },
                "Nueva conversación vuelve a animar sin mirar Reducir movimiento.")
        #expect(lines.contains("DS.Haptic.warning()"), "Nueva conversación (el borrado) ya no vibra.")
        #expect(lines.contains("if restored { DS.Haptic.success() }"), "Deshacer ya no vibra cuando repone.")
    }

    @Test func chatVoicePanel_vibratesAndRespectsReduceMotion() throws {
        let lines = try Self.code("Yala/App/Views/Chat/ChatSheetView.swift")
        #expect(!lines.contains(".animation(.easeInOut(duration: 0.25), value: isVoiceActive)"))
        // La animación del panel la dejó la card C6 (misma curva y Reducir movimiento); aquí solo se fija que siga.
        #expect(lines.contains(".animation(reduceMotion ? nil : DS.Animation.appear, value: isVoiceActive)"))
        #expect(lines.contains("if now, !was { DS.Haptic.medium() }"), "Empezar a grabar ya no vibra.")
        guard let done = Self.index(of: "onDone: {", in: lines) else {
            Issue.record("Sin el «Listo» del panel de voz.")
            return
        }
        #expect(lines[(done + 1)...(done + 2)].contains("DS.Haptic.light()"), "Enviar lo dictado ya no vibra.")
    }
}
