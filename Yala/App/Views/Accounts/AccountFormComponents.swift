//
//  AccountFormComponents.swift
//  Yala
//
//  Piezas del formulario de cuenta de la auditoría UX 2.2, lote 7. Van aparte para no alargar la cadena del
//  `body` de `AccountFormView`, que el compilador del CI (Xcode 26.6) ya tipa con esfuerzo (`swiftui-ds.md`).
//

import SwiftUI

// MARK: - Tipo de cuenta en fichas (L7-3)

/// Los cinco tipos a la vez, como fichas con icono dentro del formulario, y la frase del elegido debajo
/// (auditoría UX 2.2, lote 7, L7-3, variante 2). Antes eran cinco nombres en otra pantalla y la elegida solo
/// llevaba un check fino. La elegida va rellena de índigo, como en el onboarding.
struct AccountTypeChips: View {
    @Binding var selectedType: AccountType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Account.type)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(AccountType.allCases) { type in
                    chip(type)
                }
            }

            Text(Self.hint(for: selectedType))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("account_type_hint")
        }
        .padding()
    }

    private func chip(_ type: AccountType) -> some View {
        let isSelected = type == selectedType
        return Button {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.75)) {
                selectedType = type
            }
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                Image(systemName: iconName(for: type))
                    .font(DS.Typography.headline)
                    .accessibilityHidden(true)
                Text(type.localizedName)
                    .font(DS.Typography.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(isSelected ? Color.selectedIndigoFill : Color.primary.opacity(0.06))
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("account_type_chip_\(type.rawValue)")
    }

    /// La frase de cada tipo: las del onboarding, y una propia para «General», que el onboarding no ofrece.
    static func hint(for type: AccountType) -> String {
        type == .general ? L10n.UXL7.generalTypeHint : type.typeDescription
    }
}

// MARK: - La moneda nueva en el Panel (L7-8)

/// Tras crear una cuenta en otra moneda. Con hueco: «¿Ver EUR en tu Panel?» y cuánto vale 1 EUR en la moneda
/// principal. Con las dos secundarias puestas —antes no decía nada—: cambiar una de ellas por la nueva.
struct SecondaryCurrencySuggestionAlert: ViewModifier {
    @Binding var suggestion: SecondaryCurrencySuggestionLogic.Suggestion?
    let preferred: String
    /// La moneda nueva y, si la hay, la que sale.
    let onAccept: (_ new: String, _ replacing: String?) -> Void
    let onDecline: () -> Void

    private var isPresented: Binding<Bool> {
        Binding(get: { suggestion != nil }, set: { if !$0 { suggestion = nil } })
    }

    private var title: String {
        switch suggestion {
        case .add(let code): return L10n.UXL7.Secondary.addTitle(code)
        case .replace: return L10n.UXL7.Secondary.replaceTitle
        case nil: return ""
        }
    }

    func body(content: Content) -> some View {
        content.alert(title, isPresented: isPresented, presenting: suggestion) { suggestion in
            switch suggestion {
            case .add(let code):
                Button(L10n.UXL7.Secondary.addAccept) { onAccept(code, nil) }
                Button(L10n.Account.secondaryCurrencyReject, role: .cancel) { onDecline() }
            case .replace(let new, let current):
                ForEach(current, id: \.self) { old in
                    Button(L10n.UXL7.Secondary.replaceButton(old, new)) { onAccept(new, old) }
                }
                Button(L10n.UXL7.Secondary.keep, role: .cancel) { onDecline() }
            }
        } message: { suggestion in
            Text(Self.message(for: suggestion, preferred: preferred))
        }
    }

    static func message(for suggestion: SecondaryCurrencySuggestionLogic.Suggestion, preferred: String) -> String {
        switch suggestion {
        case .add(let code):
            return L10n.UXL7.Secondary.addMessage(code, preferred)
        case .replace(let new, let current):
            return L10n.UXL7.Secondary.replaceMessage(current.first ?? "", current.dropFirst().first ?? "", new)
        }
    }
}

// MARK: - Descartar cambios (L7-5)

/// «¿Descartar cambios?» con «Seguir editando», los textos del molde de la Bandeja.
struct DiscardAccountChangesAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content.alert(L10n.Inbox.discardChangesTitle, isPresented: $isPresented) {
            Button(L10n.Inbox.discardChanges, role: .destructive) { onDiscard() }
            Button(L10n.Inbox.keepEditing, role: .cancel) {}
        } message: {
            Text(L10n.Inbox.discardChangesMessage)
        }
    }
}
