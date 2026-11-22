//
//  NuevoRegistroB1Pieces.swift
//  Yala
//
//  Las piezas de la hoja B1 de Nuevo registro (Jürgen, 2026-11-20): la fila de abajo en una sola línea, el chip de la
//  fecha, el «#» con número, la cápsula de moneda, la línea de categoría y necesidad, y los favoritos de solo icono.
//  La lógica que deciden (anchos, monedas, textos) vive en `NuevoRegistroB1Logic.swift`.
//

import SwiftData
import SwiftUI

// MARK: - La fila de abajo, siempre en una línea

nonisolated private struct OneLineChipFlexibleKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// En `OneLineChipRow`, este chip es el que encoge (y trunca su texto) cuando la fila no cabe.
    func shrinksInChipRow(_ shrinks: Bool = true) -> some View {
        layoutValue(key: OneLineChipFlexibleKey.self, value: shrinks)
    }
}

/// Los chips de abajo en UNA línea, centrada (ajuste 1 de Jürgen): nunca baja a otra. Si no cabe, encogen los marcados
/// con `shrinksInChipRow()` (`OneLineChipRowLogic`).
struct OneLineChipRow: Layout {
    var spacing: CGFloat = DS.Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let widths = arrange(subviews, maxWidth: maxWidth)
        let height = zip(subviews, widths).map { subview, width in
            subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }.max() ?? 0
        let content = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        return CGSize(width: maxWidth.isFinite ? maxWidth : content, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = arrange(subviews, maxWidth: bounds.width)
        let content = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        var x = bounds.minX + max(0, (bounds.width - content) / 2)
        for (subview, width) in zip(subviews, widths) {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            subview.place(
                at: CGPoint(x: x, y: bounds.midY - size.height / 2),
                proposal: ProposedViewSize(width: width, height: size.height)
            )
            x += width + spacing
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [CGFloat] {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        guard maxWidth.isFinite else { return ideals }
        return OneLineChipRowLogic.widths(
            ideals: ideals,
            flexible: subviews.map { $0[OneLineChipFlexibleKey.self] },
            maxWidth: maxWidth,
            spacing: spacing
        )
    }
}

// MARK: - El monto con su estimado al lado

/// El monto (primer hijo) y, si lo hay, el estimado en la moneda preferida (segundo): a la derecha y en la misma línea de
/// base si caben los dos a lo ancho; si no, centrado bajo el monto (ajuste 5 de la ronda 2). El conjunto va centrado.
struct AmountWithEstimateLayout: Layout {
    var spacing: CGFloat = DS.Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let main = subviews.first else { return .zero }
        let mainSize = main.sizeThatFits(.unspecified)
        let maxWidth = proposal.width ?? .infinity
        guard subviews.count > 1 else {
            return CGSize(width: maxWidth.isFinite ? maxWidth : mainSize.width, height: mainSize.height)
        }
        let estimate = subviews[1].sizeThatFits(.unspecified)
        let inline = fitsInline(main: mainSize, estimate: estimate, maxWidth: maxWidth)
        let width = maxWidth.isFinite ? maxWidth : (inline ? mainSize.width + spacing + estimate.width : max(mainSize.width, estimate.width))
        let height = inline ? mainSize.height : mainSize.height + DS.Spacing.xxs + estimate.height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let main = subviews.first else { return }
        let mainSize = main.sizeThatFits(.unspecified)
        guard subviews.count > 1 else {
            main.place(at: CGPoint(x: bounds.midX - mainSize.width / 2, y: bounds.minY), proposal: ProposedViewSize(mainSize))
            return
        }
        let estimate = subviews[1]
        let estimateSize = estimate.sizeThatFits(.unspecified)
        if fitsInline(main: mainSize, estimate: estimateSize, maxWidth: bounds.width) {
            let total = mainSize.width + spacing + estimateSize.width
            let x = bounds.midX - total / 2
            main.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(mainSize))
            // Misma línea de base que el monto.
            let mainBaseline = main.dimensions(in: ProposedViewSize(mainSize))[VerticalAlignment.lastTextBaseline]
            let estimateBaseline = estimate.dimensions(in: ProposedViewSize(estimateSize))[VerticalAlignment.lastTextBaseline]
            estimate.place(
                at: CGPoint(x: x + mainSize.width + spacing, y: bounds.minY + mainBaseline - estimateBaseline),
                proposal: ProposedViewSize(estimateSize)
            )
        } else {
            main.place(at: CGPoint(x: bounds.midX - mainSize.width / 2, y: bounds.minY), proposal: ProposedViewSize(mainSize))
            let width = min(estimateSize.width, bounds.width)
            estimate.place(
                at: CGPoint(x: bounds.midX - width / 2, y: bounds.minY + mainSize.height + DS.Spacing.xxs),
                proposal: ProposedViewSize(width: width, height: estimateSize.height)
            )
        }
    }

    private func fitsInline(main: CGSize, estimate: CGSize, maxWidth: CGFloat) -> Bool {
        AmountEstimatePlacementLogic.isInline(mainWidth: main.width, estimateWidth: estimate.width, spacing: spacing,
                                              maxWidth: maxWidth)
    }
}

// MARK: - Chips neutros de la fila de abajo

/// Un chip de la fila de abajo como valor ya puesto: cápsula neutra (`.thCard`), texto principal y solo el icono en su
/// color (Jürgen, 2026-11-20: «algo más neutro para que no se vea todo tan colorido»). Sin valor, el rótulo en gris; si
/// falta para guardar, el borde de acento de siempre (L2-2). El único chip relleno de la hoja es la subcategoría.
struct RecordValueChip: View {
    let icon: String
    var iconColor: Color? = nil
    let text: String
    let isSet: Bool
    var isMissing: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RecordValueChipLabel(icon: icon, iconColor: iconColor, text: text, isSet: isSet, isMissing: isMissing)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityValue(isMissing ? L10n.UXL2.missingChipValue : "")
        .accessibilityAddTraits(isSet ? .isSelected : [])
    }
}

/// Lo que pinta `RecordValueChip`, para un chip que abre un `Menu` en vez de una acción (el grupo del editor de la
/// Bandeja). `text == nil` = solo el ícono, cuando la fila no cabe con el texto.
struct RecordValueChipLabel: View {
    @Environment(\.yalaTheme) private var theme
    let icon: String
    var iconColor: Color? = nil
    let text: String?
    let isSet: Bool
    var isMissing: Bool = false

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(isSet ? AnyShapeStyle(iconColor ?? .secondary) : AnyShapeStyle(.secondary))
                .accessibilityHidden(true)
            if let text {
                Text(text)
                    .font(DS.Typography.label)
                    .foregroundStyle(isSet ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DS.FormRow.paddingV)
        .padding(.vertical, DS.Spacing.sm)
        .background(.thCard, in: Capsule())
        .overlay(Capsule().stroke(isMissing ? theme.accent : .clear, lineWidth: 1.5))
        .contentShape(Capsule())
    }
}

/// «Hoy» en la fila de abajo, o sobre la descripción en una transferencia: un valor ya puesto que se toca para cambiarlo.
struct RecordDateValueChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        RecordValueChip(icon: "calendar", text: text, isSet: true, action: action)
            .accessibilityLabel(L10n.Transaction.date)
            .accessibilityValue(text)
    }
}

// MARK: - «#» con el número de etiquetas

/// Las etiquetas en la fila de abajo: «#» sin ninguna; con ellas, su número («#2») sobre la cápsula neutra, con la «#» en
/// el color de la primera. Las pastillas por etiqueta con ✕ viven en la hoja de etiquetas (B1).
struct TagCountChip: View {
    @Environment(\.yalaTheme) private var theme
    let tags: [Tag]
    /// Hay una etiqueta recién creada por Yala IA (aprobación de la Bandeja): un punto de acento sobre el chip y «Nueva»
    /// para VoiceOver, lo que decía la pastilla de esa etiqueta antes de la B1.
    var marksNew: Bool = false
    let action: () -> Void

    var body: some View {
        let first = tags.first.map { Color(hex: $0.colorHex) }
        Button(action: action) {
            HStack(spacing: DS.Spacing.xxs) {
                Text(verbatim: "#")
                    .foregroundStyle(first.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
                if !tags.isEmpty {
                    Text(verbatim: "\(tags.count)")
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }
            .font(DS.Typography.label)
            .lineLimit(1)
            .padding(.horizontal, DS.FormRow.paddingV)
            .padding(.vertical, DS.Spacing.sm)
            .frame(minWidth: 40)
            .background(.thCard, in: Capsule())
            .overlay(alignment: .topTrailing) {
                if marksNew {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(TagCountChipLogic.accessibilityLabel(names: tags.map(\.name)))
        .accessibilityValue(marksNew ? L10n.Inbox.newTag : "")
        .accessibilityAddTraits(tags.isEmpty ? [] : .isSelected)
    }
}

// MARK: - La cápsula de moneda «S/ ▾»

/// A la izquierda del monto, como en Grupos. Abre las monedas en las que hay cuentas y cuántas tiene cada una; con una
/// sola moneda no abre nada y no lleva flecha.
struct AmountCurrencyCapsule: View {
    let label: String
    let options: [AmountCurrencyOption]
    let current: String
    /// Prefijo de los identificadores de XCUITest: la cápsula vive también en la aprobación de la Bandeja, en Grupos y en
    /// el editor de favorito («draft_editor», «group_expense»…). Por defecto, los de Nuevo registro.
    var identifierPrefix: String = "new_transaction"
    /// Lo que se pone en «S/ ▾» en vez del menú: una hoja propia (la moneda del gasto de Grupos). Con ella, la flecha sale
    /// aunque no haya opciones.
    var onTapInsteadOfMenu: (() -> Void)? = nil
    let onChoose: (String) -> Void

    var body: some View {
        if let onTapInsteadOfMenu {
            Button(action: onTapInsteadOfMenu) {
                capsule(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NuevoRegistroB1Text.string("currency.a11y"))
            .accessibilityValue(current)
            .accessibilityIdentifier("\(identifierPrefix)_currency_capsule")
        } else if options.count > 1 {
            Menu {
                ForEach(options) { option in
                    Button {
                        onChoose(option.currencyCode)
                    } label: {
                        if option.currencyCode == current.uppercased() {
                            Label(menuTitle(option), systemImage: "checkmark")
                        } else {
                            Text(menuTitle(option))
                        }
                    }
                    .accessibilityIdentifier("\(identifierPrefix)_currency_option_\(option.currencyCode)")
                }
            } label: {
                capsule(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NuevoRegistroB1Text.string("currency.a11y"))
            .accessibilityValue(current)
            .accessibilityIdentifier("\(identifierPrefix)_currency_capsule")
        } else {
            capsule(showsChevron: false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(NuevoRegistroB1Text.string("currency.a11y"))
                .accessibilityValue(current)
                .accessibilityIdentifier("\(identifierPrefix)_currency_capsule")
        }
    }

    private func menuTitle(_ option: AmountCurrencyOption) -> String {
        let count = option.accountCount == 1
            ? NuevoRegistroB1Text.string("currency.accountsCount.one")
            : String(format: NuevoRegistroB1Text.string("currency.accountsCount.other"), option.accountCount)
        return "\(option.currencyCode) · \(count)"
    }

    private func capsule(showsChevron: Bool) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.headline)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(DS.Typography.labelSmall)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DS.FormRow.paddingV)
        .padding(.vertical, DS.Spacing.sm)
        .background(Capsule().fill(.thCard))
        .fixedSize()
    }
}

// MARK: - Categoría y necesidad, como texto con su puntito

/// Bajo el chip de subcategoría: «● Alimentación · ● Opcional ▾» en `subheadline` secundario (B1). El puntito nunca va
/// solo: el nombre va al lado. La necesidad abre su selector; en un ingreso no sale.
struct CategoryNeedLine<Trailing: View>: View {
    let category: Category
    let need: SubcategoryNeed?
    let onNeedTap: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(category.name)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("record_category_chip")

            if let need {
                Text(verbatim: "·")
                    .accessibilityHidden(true)
                Button(action: onNeedTap) {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(need.color)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(need.displayName)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(DS.Typography.captionSmall)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(need.displayName)
                .accessibilityHint(NuevoRegistroB1Text.string("need.a11yChange"))
                .accessibilityIdentifier("new_transaction_need_chip")
            }

            trailing()
        }
        .font(DS.Typography.subheadline)
        .foregroundStyle(.secondary)
    }
}

extension CategoryNeedLine where Trailing == EmptyView {
    init(category: Category, need: SubcategoryNeed?, onNeedTap: @escaping () -> Void) {
        self.init(category: category, need: need, onNeedTap: onNeedTap, trailing: { EmptyView() })
    }
}

// MARK: - Favoritos

/// La fila de favoritos de la hoja B1: arriba, el rótulo «Favoritos» y, en su misma línea a la derecha, «Ver todos ›».
/// Debajo, centrados, los favoritos del tipo elegido como chips completos (icono y nombre) mientras quepan todos; si no,
/// como bolitas de 40 pt con el icono y el color de su categoría (en una transferencia, los de su cuenta de destino), y
/// si ni así caben, con scroll lateral desde el margen. Tocar una bolita la estira con su nombre y los demás bajan; con
/// texto de accesibilidad, todos enseñan su nombre (Jürgen, 21-nov-2026, sustituye a la fila de solo icono del 20-nov).
struct IconFavoritesRow: View {
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(sort: \FavoritePayment.displayOrder) private var favorites: [FavoritePayment]

    let transactionType: TransactionType
    let onSelect: (FavoritePayment) -> Void
    let onSeeAll: () -> Void

    @State private var chosen: PersistentIdentifier?
    /// Ancho visible del scroll de bolitas: su contenido lo usa como mínimo para quedar centrado mientras quepa.
    @State private var iconRowWidth: CGFloat = 0

    private var shown: [FavoritePayment] {
        FavoritesVisibility.shown(favorites, isExpensesOnlyMode: sessionState.isExpensesOnlyMode, type: transactionType)
    }

    var body: some View {
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                header
                // Chips completos si caben todos; si no, bolitas (que hacen scroll si tampoco caben). Lo decide el
                // ancho ideal de cada forma, sin anchos fijos.
                ViewThatFits(in: .horizontal) {
                    namedChips
                    iconChips
                }
                .frame(maxWidth: .infinity)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("new_transaction_favorites_row")
            .onChange(of: transactionType) { _, _ in chosen = nil }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text(NuevoRegistroB1Text.string("favorites.label"))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("new_transaction_favorites_label")
            Spacer(minLength: DS.Spacing.sm)
            seeAllButton
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private var namedChips: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(shown, id: \.persistentModelID) { favorite in
                chip(for: favorite, alwaysNamed: true)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xxs)
    }

    private var iconChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(shown, id: \.persistentModelID) { favorite in
                    chip(for: favorite, alwaysNamed: false)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.xxs)
            .frame(minWidth: iconRowWidth)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { iconRowWidth = $0 }
        // Un scroll lateral también se estira en vertical: sin esto se quedaba un tercio del alto libre y la
        // descripción bajaba (medido en el 17 Pro, 2026-11-20).
        .fixedSize(horizontal: false, vertical: true)
        .fadesTowardVerticalBar()
    }

    private func chip(for favorite: FavoritePayment, alwaysNamed: Bool) -> some View {
        let style = IconFavoriteStyle(favorite: favorite)
        let isChosen = chosen == favorite.persistentModelID
        let showsName = alwaysNamed || isChosen || dynamicTypeSize.isAccessibilitySize
        return Button {
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion) { chosen = favorite.persistentModelID }
            onSelect(favorite)
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: style.iconName)
                    .font(DS.Typography.label)
                    .foregroundStyle(isChosen ? Color.white : style.color)
                    .accessibilityHidden(true)
                if showsName {
                    Text(favorite.name)
                        .font(DS.Typography.label)
                        .foregroundStyle(isChosen ? Color.white : Color.primary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, showsName ? DS.Spacing.md : 0)
            .frame(minWidth: 40, minHeight: 40)
            .background(Capsule().fill(isChosen ? AnyShapeStyle(Color.selectedFill(style.color)) : AnyShapeStyle(.thCard)))
            .contentShape(Capsule())
            .opacity(chosen == nil || isChosen ? 1 : 0.42)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(L10n.UXL2.useFavorite(favorite.name))
        .accessibilityIdentifier("new_transaction_favorite_chip_\(favorite.name)")
    }

    /// «Ver todos ›» en la línea del rótulo. Su zona de toque mide 44 pt de alto, como cuando iba en la fila de chips,
    /// y el relleno negativo de fuera le quita a la línea esos 28 pt de más (2 × 14): la línea mide lo que el rótulo y
    /// la fila no baja.
    private var seeAllButton: some View {
        Button(action: onSeeAll) {
            HStack(spacing: DS.Spacing.xxs) {
                Text(NuevoRegistroB1Text.string("favorites.seeAll"))
                    .font(DS.Typography.caption)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelTiny)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.secondary)
            .padding(.leading, DS.Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -(DS.Spacing.md + DS.Spacing.xxs))
        .accessibilityIdentifier("new_transaction_favorites_see_all")
    }
}

/// Icono y color de un favorito de solo icono: los de su categoría; en una transferencia, los de su cuenta de destino
/// (todas llevaban ⇄ y con solo el icono no se distinguían).
struct IconFavoriteStyle {
    let iconName: String
    let color: Color

    init(favorite: FavoritePayment) {
        if favorite.type == .transfer, let destination = favorite.destinationAccount {
            iconName = destination.iconName
            color = Color(hex: destination.colorHex)
            return
        }
        let base = FavoriteChipStyle(favorite: favorite)
        iconName = base.iconName
        color = base.color
    }
}
