//
//  BridgeRadioOption.swift
//  Yala
//
//  Componente compartido entre BridgeActivationSheet y BridgeDeactivationSheet.
//  Renderea un radio row con icono + título + hint opcional.
//

import SwiftUI

struct BridgeRadioOption<Tag: Hashable>: View {

    let tag: Tag
    @Binding var selection: Tag
    let title: String
    let hint: String?
    let action: (() -> Void)?

    init(
        tag: Tag,
        selection: Binding<Tag>,
        title: String,
        hint: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.tag = tag
        self._selection = selection
        self.title = title
        self.hint = hint
        self.action = action
    }

    var body: some View {
        Button {
            selection = tag
            action?()
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                if selection == tag {
                    Image(systemName: "largecircle.fill.circle")
                        .font(DS.Typography.body)
                        .foregroundStyle(.thAccent)
                } else {
                    Image(systemName: "circle")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let hint {
                        Text(hint)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
        }
        .buttonStyle(.plain)
    }
}
