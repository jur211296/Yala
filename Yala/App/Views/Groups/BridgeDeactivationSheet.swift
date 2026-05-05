//
//  BridgeDeactivationSheet.swift
//  Yala
//
//  A0-Bridge V2.0: sheet de desactivación tardía cuando user desactiva el toggle
//  personalAutoCreate y el grupo tiene TX/drafts bridgeadas. Ofrece:
//  - Eliminarlas (default — invoca unbridgeAllForGroup).
//  - Mantenerlas como histórico (solo set autoCreate=false).
//

import SwiftUI

struct BridgeDeactivationSheet: View {

    // MARK: - Input

    let group: SplitGroup
    let bridgedCount: Int
    let onConfirm: (_ deleteAll: Bool) -> Void
    let onCancel: () -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedOption: Option = .delete

    enum Option: Hashable { case delete, keep }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(String(format: L10n.Groups.Bridge.deactivateBody, bridgedCount))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    VStack(spacing: DS.Spacing.none) {
                        BridgeRadioOption(
                            tag: Option.delete,
                            selection: $selectedOption,
                            title: String(format: L10n.Groups.Bridge.deactivateOptionDelete, bridgedCount)
                        )
                        Divider().padding(.leading, DS.FormRow.paddingH)
                        BridgeRadioOption(
                            tag: Option.keep,
                            selection: $selectedOption,
                            title: L10n.Groups.Bridge.deactivateOptionKeep
                        )
                    }
                    .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(.thCard))

                    YalaPrimaryButton(L10n.Action.continueAction, icon: "checkmark.circle.fill") {
                        onConfirm(selectedOption == .delete)
                        dismiss()
                    }
                    .padding(.top, DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(PanelBackgroundView())
            .navigationTitle(L10n.Groups.Bridge.deactivateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Action.cancel) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

}
