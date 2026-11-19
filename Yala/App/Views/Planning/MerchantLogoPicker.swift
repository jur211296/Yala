//
//  MerchantLogoPicker.swift
//  Yala
//
//  Elegir a mano el logo de un pago planificado (card `scheduled-payments-real-brand-logos`, 2.3). Con cientos de
//  comercios el menú de antes no se podía usar: hoja con buscador sobre todo el banco (nombre y formas de escribirlo),
//  y arriba las dos salidas de siempre, automático y sin logo. Sin textos nuevos: reusa los de la fila «Logo» y el
//  buscador del sistema.
//

import SwiftUI

struct MerchantLogoPickerSheet: View {
    /// Lo que guarda el pago: `nil` = automático, `SubscriptionBrandCatalog.noneID` = sin logo, o el id elegido.
    @Binding var brandLogoID: String?
    let paymentName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @State private var query = ""

    private var automatic: PaymentLogo? { PaymentLogoResolver.automatic(name: paymentName) }

    private var results: [Merchant] {
        MerchantLogoSearch.filter(MerchantCatalog.sortedForPicking, query: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        choiceRow(id: "scheduled_logo_option_auto", isSelected: brandLogoID == nil) {
                            brandLogoID = nil
                        } label: {
                            if let automatic {
                                SubscriptionBrandBadge(logo: automatic, diameter: DS.Icon.badgeSmall, isDecorative: true)
                                Text(L10n.Scheduled.logoAutoNamed(automatic.name))
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .frame(width: DS.Icon.badgeSmall)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(L10n.Scheduled.logoAuto)
                            }
                        }
                        choiceRow(id: "scheduled_logo_option_none",
                                  isSelected: brandLogoID == SubscriptionBrandCatalog.noneID) {
                            brandLogoID = SubscriptionBrandCatalog.noneID
                        } label: {
                            Image(systemName: "circle.slash")
                                .frame(width: DS.Icon.badgeSmall)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(L10n.Scheduled.logoNone)
                        }
                    }
                }
                Section {
                    ForEach(results) { merchant in
                        choiceRow(id: "scheduled_logo_option_\(merchant.id)", isSelected: brandLogoID == merchant.id) {
                            brandLogoID = merchant.id
                        } label: {
                            SubscriptionBrandBadge(logo: PaymentLogo(merchant: merchant), diameter: DS.Icon.badgeSmall,
                                                   isDecorative: true)
                            Text(verbatim: merchant.name)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(L10n.Scheduled.logoTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
        }
        .yalaScreenBackground(.subtle)
    }

    private func choiceRow<Label: View>(
        id: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            action()
            DS.Haptic.selection()
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                label()
                Spacer(minLength: DS.Spacing.sm)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.label)
                        .foregroundStyle(theme.accentText)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Color(.label))
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}

/// El filtro del buscador: lo escrito, sin mayúsculas ni tildes, dentro del nombre o de una forma de escribirlo.
enum MerchantLogoSearch {
    static func filter(_ merchants: [Merchant], query: String) -> [Merchant] {
        let needle = SubscriptionBrandCatalog.normalize(query)
        guard !needle.isEmpty else { return merchants }
        return merchants.filter { merchant in
            ([merchant.name] + merchant.aliases).contains { SubscriptionBrandCatalog.normalize($0).contains(needle) }
        }
    }
}
