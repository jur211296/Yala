//
//  GroupSplitLinesSheet.swift
//  Yala
//
//  Grupos B, card 6: la hoja «Tu parte» que abre «Partir tu parte» desde la pantalla de éxito de un gasto de grupo y desde
//  el detalle del registro. Es la misma tarjeta de la Bandeja (`GroupSplitLinesCard`) con el gasto encima y «Guardar»
//  abajo (maqueta `opcion-b.html`, escenarios 2 y 3). «Guardar» espera a que las líneas cuadren.
//

import SwiftData
import SwiftUI

struct GroupSplitLinesSheet: View {

    // MARK: - Input

    let splitExpenseID: String
    /// Tras guardar: quien la abrió vuelve a leer lo que pinta (el desglose del detalle).
    var onSaved: (() -> Void)? = nil

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var accounts: [Account]

    // MARK: - State

    @State private var target: GroupSplitLinesService.Target?
    @State private var lines: [GroupSplitLinesRecipe.Line] = []
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var showsError = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L10n.Groups.SplitLines.yourShareTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                    }
                }
                .alert(L10n.Common.error, isPresented: $showsError) {
                    Button(L10n.Common.ok) {}
                } message: {
                    Text(errorMessage ?? L10n.Common.unknownError)
                }
        }
        .yalaScreenBackground(.subtle)
        .onAppear(perform: load)
    }

    @ViewBuilder
    private var content: some View {
        if let target, target.offersSplit {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    header(target)
                    GroupSplitLinesCard(
                        lines: $lines,
                        share: target.share,
                        currencyCode: target.currencyCode,
                        transferSourceName: target.transferSourceName,
                        transferSourceAccount: target.transferSourceAccount
                    )
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
                .frame(maxWidth: DS.Adaptive.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                YalaPrimaryButton(L10n.Action.save, icon: "checkmark.circle.fill") { save(target) }
                    .disabled(!canSave(target))
                    .accessibilityIdentifier("split_lines_save")
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.lg)
                    .background(.thBackground)
            }
        } else if hasLoaded {
            // El gasto ya no está, o dejó de poder partirse (puente apagado mientras la hoja estaba abierta).
            Text(L10n.Common.unknownError)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .padding(DS.Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// El gasto que se parte: su nombre y su importe, como en la hoja de la Bandeja.
    private func header(_ target: GroupSplitLinesService.Target) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(target.expense.expenseDescription.isEmpty ? "—" : target.expense.expenseDescription)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            AmountText(
                value: target.expense.amount,
                currencyCode: target.currencyCode,
                font: DS.Typography.heroAmount,
                secondaryFont: DS.Typography.heroAmountSecondary,
                forceFullPrecision: true
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func load() {
        guard !hasLoaded else { return }
        defer { hasLoaded = true }
        do {
            guard let resolved = try GroupSplitLinesService.target(splitExpenseID: splitExpenseID, context: modelContext)
            else { return }
            target = resolved
            lines = resolved.initialLines
        } catch {
            #if DEBUG
            print("GroupSplitLinesSheet: Error: \(error)")
            #endif
        }
    }

    private func canSave(_ target: GroupSplitLinesService.Target) -> Bool {
        GroupSplitLinesEditorLogic.canSave(
            lines, share: target.share, currencyCode: target.currencyCode,
            destinations: GroupSplitLinesCard.destinationInfo(accounts))
    }

    private func save(_ target: GroupSplitLinesService.Target) {
        guard canSave(target) else { return }
        do {
            try GroupSplitLinesService.save(lines, for: target, context: modelContext)
            DS.Haptic.success()
            onSaved?()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupSplitLinesSheet: Error: \(error)")
            #endif
            errorMessage = GroupsUserFacingErrorLogic.message(for: error)
            showsError = true
        }
    }
}
