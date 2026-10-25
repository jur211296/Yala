//
//  FavoriteChipsRow.swift
//  Yala
//
//  La fila de favoritos del formulario de registro (UX 2.2 · L2-13, decidido por Jürgen el 14-oct y cerrado el 21-oct):
//  bajo el selector de tipo, un chip por favorito con el icono de su categoría, el nombre y el monto. Un toque rellena
//  el formulario; la persona toca «Guardar». Al final, «Ver todos» abre la lista.
//

import SwiftData
import SwiftUI

struct FavoriteChipsRow: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState

    /// El orden es el de Ajustes › Favoritos (`displayOrder`, reordenable), no por uso: así no saltan de sitio.
    @Query(sort: \FavoritePayment.displayOrder) private var favorites: [FavoritePayment]

    let onSelect: (FavoritePayment) -> Void
    let onSeeAll: () -> Void

    private var shown: [FavoritePayment] {
        FavoritesVisibility.shown(favorites, isExpensesOnlyMode: sessionState.isExpensesOnlyMode)
    }

    var body: some View {
        // Sin favoritos, la fila no sale.
        if !shown.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(shown, id: \.persistentModelID) { favorite in
                        chip(for: favorite)
                    }
                    seeAllChip
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
            .fadesTowardVerticalBar()
            .accessibilityIdentifier("new_transaction_favorites_row")
        }
    }

    private func chip(for favorite: FavoritePayment) -> some View {
        let style = FavoriteChipStyle(favorite: favorite)
        return Button {
            onSelect(favorite)
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: style.iconName)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(style.color)
                    .accessibilityHidden(true)
                Text(favorite.name)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let amount = favorite.amount, amount > 0 {
                    Text(amountText(amount, favorite: favorite))
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingV)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(.thCard))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.UXL2.useFavorite(favorite.name))
        .accessibilityIdentifier("new_transaction_favorite_chip_\(favorite.name)")
    }

    private var seeAllChip: some View {
        Button(action: onSeeAll) {
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.UXL2.favoritesSeeAll)
                    .font(DS.Typography.label)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelTiny)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.FormRow.paddingV)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("new_transaction_favorites_see_all")
    }

    /// El monto en la divisa del favorito (la del importe, L2-4k2q), con la preferencia de símbolo o código.
    private func amountText(_ amount: Double, favorite: FavoritePayment) -> String {
        let code = favorite.currencyCode ?? favorite.account?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
        return appPreferences.currency(amount, currencyCode: code, forceFullPrecision: true)
    }
}

/// Icono y color de un favorito: los de su categoría; los de transferencia, los de transferencia (L2-14).
struct FavoriteChipStyle {
    let iconName: String
    let color: Color

    init(favorite: FavoritePayment) {
        if favorite.type == .transfer {
            iconName = "arrow.left.arrow.right"
            color = TransactionType.transfer.color
            return
        }
        iconName = favorite.subcategory?.iconName
            ?? favorite.subcategory?.category?.iconName
            ?? "star.fill"
        let colorHex = favorite.subcategory?.category?.colorHex
            ?? favorite.subcategory?.colorHex
            ?? AppConstants.defaultColorHex
        color = Color(hex: colorHex)
    }
}
