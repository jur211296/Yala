//
//  CollapsibleSectionHeader.swift
//  Yala
//
//  Header colapsable estilo Liquid Glass con accessory `+`/`-`. Drift
//  tipográfico (Panel `.title` vs Stats `.subheadlineEmphasized`) gestionado
//  vía params opcionales.
//

import SwiftUI

struct CollapsibleSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    /// Versión atribuida del subtitle, con prioridad sobre `subtitle: String?`.
    /// Útil para componer jerarquía visual (ej. monto con symbol/decimales
    /// en secondary embebido en una frase). Si `subtitleAttributed != nil`,
    /// `subtitle` se ignora.
    var subtitleAttributed: AttributedString? = nil
    let isExpanded: Bool
    var titleFont: Font = DS.Typography.subheadlineEmphasized
    var subtitleFont: Font = DS.Typography.caption
    var subtitleLineLimit: Int = 3
    var accessibilityValue: String? = nil
    var accessibilityHint: String? = nil
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(.primary)
                    if let subtitleAttributed {
                        Text(subtitleAttributed)
                            .font(subtitleFont)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(subtitleLineLimit)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let subtitle {
                        Text(subtitle)
                            .font(subtitleFont)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(subtitleLineLimit)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: isExpanded ? "minus" : "plus")
                    .font(DS.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .frame(width: DS.Panel.headerAccessorySize, height: DS.Panel.headerAccessorySize)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
        .yalaAccessibilityValue(accessibilityValue)
        .yalaAccessibilityHint(accessibilityHint)
    }
}

private extension View {
    @ViewBuilder
    func yalaAccessibilityValue(_ value: String?) -> some View {
        if let value {
            self.accessibilityValue(value)
        } else {
            self
        }
    }

    @ViewBuilder
    func yalaAccessibilityHint(_ hint: String?) -> some View {
        if let hint {
            self.accessibilityHint(hint)
        } else {
            self
        }
    }
}
