//
//  PracticeCleanupPrompt.swift
//  Yala
//
//  «¿Era de prueba?» en el momento (UX 2.2 · L5-5, decisión de Jürgen: opción B).
//
//  El primer presupuesto y el primer pago planificado se crean en Planificación, y la pregunta esperaba a que la
//  persona volviera al Panel —cuando ya estaba haciendo otra cosa—. Ahora la hace la propia Planificación al cerrarse
//  el editor. El primer gasto y las prácticas de voz y foto ya se preguntaban al cerrar su hoja, en el Panel, y siguen
//  ahí (`PanelSheetsModifier`). Los botones dicen lo que hacen: «Guardarlo» y «Borrarlo, era de prueba».
//
//  La oferta de prueba de Pro solo espera a la respuesta del primer REGISTRO (`TrialOfferMoments`), así que la de un
//  presupuesto o un pago no la mueve.
//

import SwiftData
import SwiftUI

/// Borra lo creado como práctica. Lo comparten el Panel y Planificación.
@MainActor
enum PracticeCleanupDeleter {

    static func delete(_ item: PracticeCleanupItem, in context: ModelContext) {
        do {
            for pid in item.allPersistentIDs {
                switch item.kind {
                case .transaction: try deleteModel(TransactionItem.self, id: pid, context: context)
                case .draft: try deleteModel(InboxDraft.self, id: pid, context: context)
                case .budget: try deleteModel(Budget.self, id: pid, context: context)
                case .scheduledPayment: try deleteModel(ScheduledPayment.self, id: pid, context: context)
                }
            }
            try context.save()
        } catch {
            #if DEBUG
            print("SetupChecklist: Error deleting practice item: \(error)")
            #endif
        }
    }

    private static func deleteModel<T: PersistentModel>(_ type: T.Type, id: PersistentIdentifier, context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<T>())
        guard let match = all.first(where: { $0.persistentModelID == id }) else {
            #if DEBUG
            print("SetupChecklist: Practice \(T.self) not found — ID mismatch")
            #endif
            return
        }
        context.delete(match)
    }
}

/// La pregunta, colgada de la pantalla que presenta el editor. `consume()` va en el `onDismiss` de esa hoja: así la
/// alerta sale con la hoja ya cerrada, nunca encima de ella.
struct PracticeCleanupPrompt: ViewModifier {
    /// Los pasos cuya pregunta hace esta pantalla.
    let steps: Set<SetupStepID>
    /// Sube cada vez que se cierra el editor (el `onDismiss` de su hoja).
    let editorClosedToken: Int
    let onAnswered: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var item: PracticeCleanupItem?
    @State private var showAlert = false

    func body(content: Content) -> some View {
        content
            .onChange(of: editorClosedToken) { _, _ in consume() }
            .alert(
                L10n.SetupChecklist.practiceTitle(item?.localizedItemType ?? ""),
                isPresented: $showAlert
            ) {
                Button(L10n.SetupChecklist.practiceKeep, role: .cancel) { answer(delete: false) }
                Button(L10n.SetupChecklist.practiceDelete, role: .destructive) { answer(delete: true) }
            } message: {
                Text(L10n.SetupChecklist.practiceMessage)
            }
    }

    private func consume() {
        guard let pending = SetupChecklistManager.shared.takePendingPracticeCleanup(for: steps) else { return }
        item = pending
        showAlert = true
    }

    private func answer(delete: Bool) {
        if delete, let item {
            PracticeCleanupDeleter.delete(item, in: modelContext)
        }
        TrialOfferMoments.notePracticeAnswered(item)
        item = nil
        onAnswered()
    }
}

extension View {
    func practiceCleanupPrompt(
        for steps: Set<SetupStepID>,
        editorClosedToken: Int,
        onAnswered: @escaping () -> Void
    ) -> some View {
        modifier(PracticeCleanupPrompt(steps: steps, editorClosedToken: editorClosedToken, onAnswered: onAnswered))
    }
}
