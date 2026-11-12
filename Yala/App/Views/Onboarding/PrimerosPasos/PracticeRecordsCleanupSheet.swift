//
//  PracticeRecordsCleanupSheet.swift
//  Yala
//
//  Y23-10 · Cierre de «Aprender a registrar»: sube una hoja a media altura, «¿Borramos los de prueba?», con los 1–4
//  registros del tutorial, todos marcados; se desmarcan los que se conservan. «Borrar N registros» (rojo) / «Conservarlos
//  todos». Borrar devuelve el saldo y quita los registros (el borrado de práctica de siempre, `PracticeCleanupDeleter`);
//  conservar los deja en «Últimos registros». Amplía el «¿Era de prueba?» del primer registro a todos los del tutorial.
//

import SwiftData
import SwiftUI

struct PracticeRecordsCleanupSheet: View {
    let records: [RecordTutorialRecord]
    /// Al cerrar, cuántos se borraron (0 = se conservaron todos).
    let onFinished: (_ deleted: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    @State private var selected: Set<PersistentIdentifier> = []
    @State private var didSeed = false
    @State private var answered = false
    @State private var detent: PresentationDetent = .medium

    private typealias T = L10n.PrimerosPasos23.Record

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(T.cleanupTitle)
                .font(DS.Typography.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("practice_cleanup_title")
            Text(T.cleanupMessage(records.count))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(records) { record in
                        row(record)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: DS.Spacing.xs) {
                Button(role: .destructive) {
                    deleteSelected()
                } label: {
                    Text(selected.isEmpty ? T.cleanupMarkSome : T.cleanupDelete(selected.count))
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(Color.red.opacity(selected.isEmpty ? 0.4 : 1)))
                }
                .buttonStyle(.plain)
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("practice_cleanup_delete")
                Button(T.cleanupKeepAll) {
                    answered = true
                    onFinished(0)
                    dismiss()
                }
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.thAccentText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("practice_cleanup_keep")
            }
        }
        .padding(DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // A media altura, el cristal del sistema; estirada, el fondo de siempre (regla «Ninguna hoja con fondo gris»).
        .yalaScreenBackground(detent == .large ? .subtle : .transparent)
        .onAppear {
            guard !didSeed else { return }
            didSeed = true
            selected = RecordTutorialLogic.initialSelection(records.map(\.persistentID))
        }
        // Cerrar la hoja arrastrándola es conservarlos: no se borra nada sin tocar «Borrar».
        .onDisappear {
            if !answered { onFinished(0) }
        }
    }

    private func row(_ record: RecordTutorialRecord) -> some View {
        let isOn = selected.contains(record.persistentID)
        return Button {
            DS.Haptic.selection()
            if isOn { selected.remove(record.persistentID) } else { selected.insert(record.persistentID) }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title3)
                    .foregroundStyle(isOn ? Color.red : Color.secondary)
                TutorialRecordRow(record: record)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("practice_cleanup_row")
    }

    private func deleteSelected() {
        let deleted = PracticeRecordsCleanup.delete(records, selected: selected, in: modelContext)
        DS.Haptic.warning()
        answered = true
        onFinished(deleted)
        dismiss()
    }
}

/// El borrado de la hoja: los marcados, con el borrado de práctica de siempre. Devuelve cuántos se borraron.
@MainActor
enum PracticeRecordsCleanup {
    @discardableResult
    static func delete(
        _ records: [RecordTutorialRecord], selected: Set<PersistentIdentifier>, in context: ModelContext
    ) -> Int {
        // Solo lo que sigue existiendo: un borrador que ya se aprobó en la Bandeja, o algo que se borró por otro
        // camino, no cuenta en «Borramos N registros» (review del lote).
        let doomed = records.filter { record in
            selected.contains(record.persistentID)
                && (TutorialRecordLookup.transaction(record, in: context) != nil
                    || TutorialRecordLookup.draft(record, in: context) != nil)
        }
        guard !doomed.isEmpty else { return 0 }
        for record in doomed {
            PracticeCleanupDeleter.delete(PracticeCleanupItem(
                stepID: .firstExpense,
                itemName: "",
                persistentID: record.persistentID,
                kind: record.isDraft ? .draft : .transaction,
                additionalIDs: record.additionalIDs
            ), in: context)
        }
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
        return doomed.count
    }
}
