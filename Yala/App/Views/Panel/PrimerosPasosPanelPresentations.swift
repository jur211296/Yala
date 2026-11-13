//
//  PrimerosPasosPanelPresentations.swift
//  Yala
//
//  Los pasos 1 y 2 de Primeros pasos 2.3, presentados desde el Panel (su mazo los abre): el paso 1 (Y23-07) y el
//  tutorial del paso 2 (Y23-08/09) a pantalla completa; al terminar el 2, la hoja «¿Borramos los de prueba?» y, al
//  cerrarla, la guía de foco de la Bandeja «Lo que Yala anota solo» (Y23-10). Después el Panel se llena solo: el paso 2
//  queda resuelto y vuelven las acciones (Nuevo registro, Voz, Foto, Yala IA), con el mazo en el paso 3. En su propio
//  modificador para no alargar la cadena de `PanelSheetsModifier`.
//

import SwiftData
import SwiftUI

struct PrimerosPasosPanelPresentations: ViewModifier {
    @Binding var sheets: PanelSheetState
    let viewModel: PanelViewModel

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.modelContext) private var modelContext

    /// El tutorial terminó (no solo se cerró): al cerrarse su pantalla toca la hoja del final.
    @State private var recordTutorialFinished = false
    /// Lo que la hoja del final ofrece borrar, copiado al terminar el tutorial.
    @State private var cleanupRecords: [RecordTutorialRecord] = []

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $sheets.showFirstAccountFlow, onDismiss: { viewModel.reloadAndRecalculate() }) {
                FirstAccountFlowView { _ in sheets.showFirstAccountFlow = false }
            }
            .fullScreenCover(isPresented: $sheets.showRecordTutorial, onDismiss: afterRecordTutorial) {
                RecordTutorialView { finished in
                    recordTutorialFinished = finished
                    sheets.showRecordTutorial = false
                }
            }
            .sheet(isPresented: $sheets.showPracticeRecordsCleanup) {
                PracticeRecordsCleanupSheet(records: cleanupRecords) { deleted in
                    finishRecordTutorial(deleted: deleted)
                }
            }
    }

    /// Al cerrarse la pantalla del tutorial. Si terminó y se anotó algo, la hoja del final; si terminó sin nada, se cierra
    /// el paso ya. Si solo se cerró, el mazo sigue en «Aprender a registrar» y se retoma donde iba.
    private func afterRecordTutorial() {
        viewModel.reloadAndRecalculate()
        guard recordTutorialFinished else { return }
        recordTutorialFinished = false
        let records = RecordTutorialSession.shared.records
        if RecordTutorialLogic.asksToCleanUp(recordCount: records.count) {
            cleanupRecords = records
            sheets.showPracticeRecordsCleanup = true
        } else {
            finishRecordTutorial(deleted: 0)
        }
    }

    /// Cierra el paso 2: el aviso de lo borrado y, con el Panel ya lleno, la guía de la Bandeja.
    private func finishRecordTutorial(deleted: Int) {
        let keptAny = RecordTutorialSession.shared.records.count > deleted
        // Telemetría del usuario nuevo (card 4b7h): si tras la hoja no queda ningún registro propio, el primero no ha
        // pasado todavía. Va antes de `finish()`, que cierra el paso y emitiría lo que esperaba.
        NewUserMetrics.recordTutorialFinished(keptARecord: hasAnyUserRecord())
        RecordTutorialSession.shared.finish()
        cleanupRecords = []
        // Debajo de la cuenta, solo «Últimos registros» (Y23-10): las gráficas se suman después desde «Configurar
        // Panel» (la guía de «días después», Y23-15). El tutorial solo existe en instalaciones nuevas de 2.3.
        appPreferences.materializePanelDefaultsIfNeeded()
        appPreferences.panelSectionsHidden = Self.sectionsHiddenAfterLearningToRecord(
            current: appPreferences.resolvedSectionsHidden)
        viewModel.reloadAndRecalculate()
        // Con algo anotado que se queda, Más lleva su punto de «algo nuevo».
        if keptAny { MoreTabNews.shared.markPending() }
        // El aviso de lo borrado sale al cerrar la guía de la Bandeja, como en el prototipo: a la vez, la guía lo tapaba.
        let notice: () -> Void = {
            if deleted > 0 { SavedRecordNotice.showInfo(message: L10n.PrimerosPasos23.Record.cleanupDone(deleted)) }
        }
        Task { @MainActor in
            // Que la hoja termine de cerrarse y el Panel se asiente antes de oscurecerlo.
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            if !PlaceGuideCenter.shared.start(.inbox, onFinish: notice) { notice() }
        }
    }

    /// Queda algún gasto o ingreso que apuntó la persona: sin el saldo inicial ni los ajustes (`countsAsUserRecord`), sin
    /// transferencias y sin lo que escribe el puente de Grupos. Sin poder contarlo se da por bueno: borrar solo pasa por la hoja, y lo que no se pudo
    /// leer no se borró.
    private func hasAnyUserRecord() -> Bool {
        do {
            return try modelContext.fetch(SetupChecklistManager.userRecordsDescriptor())
                .contains { $0.splitExpenseID == nil && $0.splitSettlementID == nil && $0.transferPairID == nil }
        } catch {
            #if DEBUG
            print("PrimerosPasosPanelPresentations: Error: counting user records: \(error)")
            #endif
            return true
        }
    }

    /// Las secciones ocultas al terminar el paso 2: todas menos la cuenta y «Últimos registros», en orden canónico (el
    /// mismo que escribe «Configurar Panel», para no empujar a iCloud un cambio que no cambia nada).
    static func sectionsHiddenAfterLearningToRecord(current: [String]) -> [String] {
        let kept: Set<PanelSectionKind> = [.accounts, .latestRecords]
        var hidden = Set(current)
        for kind in PanelSectionKind.allCases {
            if kept.contains(kind) { hidden.remove(kind.rawValue) } else { hidden.insert(kind.rawValue) }
        }
        return PanelSectionKind.allCases.map(\.rawValue).filter { hidden.contains($0) }
    }
}
