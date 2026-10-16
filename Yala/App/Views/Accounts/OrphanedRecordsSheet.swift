//
//  OrphanedRecordsSheet.swift
//  Yala
//
//  «Movimientos sin cuenta»: la cifra, cuáles son y a qué cuenta moverlos.
//  Card `tablero-los-movimientos-que-quedaron-sin-cuenta-sovw` (decisión de Jürgen del 2026-10-15).
//

import SwiftUI
import SwiftData

/// El mismo lenguaje que la hoja de eliminar cuenta (`AccountRemovalSheet`): lista agrupada, la cifra en una fila,
/// «Mover a» con las cuentas y su moneda, y el botón principal abajo. Una sola presentación con fases.
struct OrphanedRecordsSheet: View {

    @State private var viewModel = OrphanedRecordsViewModel()
    /// Se movieron: quien presenta recarga el Panel.
    let onMoved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Cuántas filas se enseñan antes de resumir el resto: la lista es para reconocerlos, no para revisarlos uno a uno.
    private static let listedLimit = 20

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.OrphanedRecords.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.Action.cancel) { dismiss() }
                            .disabled(viewModel.phase == .working)
                            .accessibilityIdentifier("orphaned_records_cancel")
                    }
                }
        }
        .interactiveDismissDisabled(viewModel.phase == .working)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("orphaned_records_sheet")
        .onAppear { viewModel.load(context: modelContext) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .choose:
            chooseView
        case .working:
            VStack(spacing: DS.Spacing.lg) {
                ProgressView()
                Text(L10n.OrphanedRecords.working)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .yalaScreenBackground(.subtle)
            .accessibilityIdentifier("orphaned_records_working")
        case .failed(let failure):
            failedView(failure)
        }
    }

    // MARK: - Elegir

    private var chooseView: some View {
        List {
            Section {
                Text(L10n.OrphanedRecords.intro)
                    .font(DS.Typography.body)
                    .accessibilityIdentifier("orphaned_records_intro")
                LabeledContent(L10n.Account.Removal.countRecords) {
                    Text("\(viewModel.records.count)")
                        .font(DS.Typography.body.monospacedDigit())
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("orphaned_records_count")
            }

            if !viewModel.records.isEmpty {
                Section {
                    ForEach(viewModel.records.prefix(Self.listedLimit)) { record in
                        recordRow(record)
                    }
                } header: {
                    Text(L10n.OrphanedRecords.listHeader)
                } footer: {
                    if viewModel.records.count > Self.listedLimit {
                        Text(L10n.OrphanedRecords.moreNote(viewModel.records.count - Self.listedLimit))
                    }
                }
            }

            if viewModel.destinations.isEmpty {
                Section {
                    Text(L10n.OrphanedRecords.noDestination)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("orphaned_records_no_destination")
                }
            } else {
                Section {
                    ForEach(viewModel.destinations) { option in
                        destinationRow(option)
                    }
                } header: {
                    Text(L10n.Account.Removal.destinationHeader)
                } footer: {
                    if let note = moveFooter {
                        Text(note)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .yalaScreenBackground(.subtle)
        .safeAreaInset(edge: .bottom) {
            YalaPrimaryButton(moveActionTitle, isDisabled: !viewModel.canMove) {
                Task {
                    if await viewModel.move(context: modelContext) {
                        onMoved()
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier("orphaned_records_move")
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(.bar)
        }
    }

    private func recordRow(_ record: OrphanedRecordsViewModel.Record) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(record.title)
                    .font(DS.Typography.body)
                    .lineLimit(2)
                Text(record.date, format: .dateTime.day().month(.wide).year())
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Spacing.sm)
            AmountText(value: record.amount, currencyCode: record.currencyCode)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("orphaned_records_row")
    }

    private func destinationRow(_ option: OrphanedRecordsViewModel.DestinationOption) -> some View {
        Button { viewModel.select(option) } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(option.name)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(option.currencyCode)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if option.id == viewModel.destinationID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option.id == viewModel.destinationID ? .isSelected : [])
        .accessibilityIdentifier("orphaned_records_destination_\(option.name)")
    }

    private var moveActionTitle: String {
        guard let option = viewModel.selectedDestination else { return L10n.OrphanedRecords.moveActionGeneric }
        return L10n.OrphanedRecords.moveAction(option.name)
    }

    private var moveFooter: String? {
        guard let option = viewModel.selectedDestination else { return nil }
        let outcome = option.outcome
        var lines: [String] = []
        if outcome.converted > 0 { lines.append(L10n.OrphanedRecords.convertNote(option.currencyCode)) }
        if outcome.keptInTheirCurrency > 0 { lines.append(L10n.OrphanedRecords.keptCurrencyNote) }
        if outcome.removed > 0 { lines.append(L10n.OrphanedRecords.collapsedNote(option.name)) }
        return lines.isEmpty ? nil : lines.joined(separator: "\n\n")
    }

    // MARK: - Error

    private func failedView(_ failure: AccountRemovalService.Failure) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(L10n.OrphanedRecords.failedTitle)
                .font(DS.Typography.title)
            Text(message(for: failure))
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("orphaned_records_failed_message")
            Spacer()
            YalaSecondaryButton(L10n.Action.back) { viewModel.back(context: modelContext) }
                .accessibilityIdentifier("orphaned_records_back")
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .yalaScreenBackground(.subtle)
    }

    private func message(for failure: AccountRemovalService.Failure) -> String {
        switch failure {
        case .unreadable: return L10n.OrphanedRecords.failedUnreadable
        case .noLongerAllowed: return L10n.OrphanedRecords.failedChanged
        case .ratesUnavailable: return L10n.Account.Removal.failedRates
        case .saveFailed: return L10n.Common.saveError
        }
    }
}
