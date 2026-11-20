//
//  TransactionSuccessView.swift
//  Yala
//
//  Created by Yala - Success confirmation screen after transaction registration.
//

import SwiftUI

// MARK: - Transaction Success Data

/// Data structure holding the saved transaction details for display
struct TransactionSuccessData {
    let transactionType: TransactionType
    let date: Date
    let accountName: String
    let accountColorHex: String
    let note: String
    let amount: Decimal
    let currencyCode: String
    let subcategoryName: String?
    let subcategoryColorHex: String?
    let categoryName: String?
    let categoryColorHex: String?
    let tags: [(name: String, colorHex: String)]
    let need: SubcategoryNeed?

    // For transfers
    let isTransfer: Bool
    let destinationAccountName: String?
    let destinationAccountColorHex: String?
    let destinationAmount: Decimal?
    let destinationCurrencyCode: String?
}

// MARK: - Transaction Success View

/// La pantalla de éxito minimalista (elegida por Jürgen el 2026-11-20 sobre la ronda 2 de Nuevo registro): «Editar»
/// arriba, un check pequeño en el color del tipo junto a «Gasto guardado», el monto grande con la descripción suelta encima
/// y una tarjeta sin rótulos con los datos por importancia (`TransactionSuccessFieldOrder`: fecha, cuenta, subcategoría,
/// naturaleza y etiquetas si tiene). Debajo, «Favorito» y «Recurrente» (en una transferencia solo «Favorito») y, al
/// pie, «Registrar otro» y «Aceptar» lado a lado. Los rótulos que no se ven, VoiceOver los lee.
struct TransactionSuccessView: View {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.setLocalizedDateFormatFromTemplate("dMMMy")
        return f
    }()

    let data: TransactionSuccessData
    /// Ya está en favoritos: el botón lo dice y no se vuelve a abrir.
    var isFavorited: Bool = false
    let onAccept: () -> Void
    let onCreateAnother: () -> Void
    let onEdit: () -> Void
    var onFavorite: (() -> Void)? = nil
    var onRecurring: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showHero = false
    @State private var showDetails = false
    @State private var showActions = false

    private var typeColor: Color { data.transactionType.color }

    private var savedTitle: String {
        switch data.transactionType {
        case .expense: return NuevoRegistroB1Text.string("success.saved.expense")
        case .income: return NuevoRegistroB1Text.string("success.saved.income")
        case .transfer: return NuevoRegistroB1Text.string("success.saved.transfer")
        }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.none) {
                HStack {
                    Spacer()
                    Button(L10n.Action.edit, action: onEdit)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("transaction_success_edit")
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)

                // Solo el centro se desplaza, y solo si no cabe (molde de `GroupExpenseSuccessView`): «Editar» arriba y
                // los botones abajo quedan siempre a la vista, también en un iPhone SE.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: DS.Spacing.none) {
                            Spacer()
                            hero
                                .padding(.bottom, DS.Spacing.xl)
                            detailsSection
                                .padding(.horizontal, DS.Spacing.xl)
                                .opacity(showDetails ? 1.0 : 0.0)
                                .offset(y: showDetails ? 0 : 15)
                            if onFavorite != nil || onRecurring != nil {
                                offersRow
                                    .padding(.horizontal, DS.Spacing.xl)
                                    .padding(.top, DS.Spacing.lg)
                                    .opacity(showDetails ? 1.0 : 0.0)
                            }
                            Spacer()
                        }
                        .frame(minHeight: proxy.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                }

                // Lado a lado, nunca uno debajo del otro (B1).
                HStack(spacing: DS.Spacing.sm) {
                    Button(action: onCreateAnother) {
                        Text(L10n.Transaction.createAnother)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    // Para que los tests lo toquen sin depender del texto (decisión 83 de la revisión 2.3).
                    .accessibilityIdentifier("transaction_success_create_another")

                    YalaPrimaryButton(L10n.Common.accept, action: onAccept)
                        .accessibilityIdentifier("transaction_success_accept")
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
                .opacity(showActions ? 1.0 : 0.0)
                .offset(y: showActions ? 0 : 10)
            }
        }
        .onAppear {
            // Momento de éxito: aquí se pide la oferta de prueba armada (UX 2.2 · L1-12, `TrialOfferMomentLogic`).
            TrialOfferMoments.noteRecordSaved()
            if reduceMotion {
                showHero = true
                showDetails = true
                showActions = true
            } else {
                withAnimation(DS.Animation.appear) { showHero = true }
                withAnimation(DS.Animation.appear.delay(0.15)) { showDetails = true }
                withAnimation(DS.Animation.appear.delay(0.3)) { showActions = true }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.headline)
                    .foregroundStyle(typeColor)
                    .symbolEffect(.bounce, value: reduceMotion ? false : showHero)
                    .accessibilityHidden(true)
                Text(savedTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("transaction_success_title")

            // La descripción va suelta, sobre el monto (ajuste 3 de Jürgen; sobre y no bajo, 2026-11-20).
            if !data.note.isEmpty {
                Text(data.note)
                    .font(DS.Typography.bodyLarge)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, DS.Spacing.xl)
                    .accessibilityIdentifier("transaction_success_description")
            }

            amount
                .scaleEffect(showHero ? 1.0 : 0.9)
                .opacity(showHero ? 1.0 : 0.0)

        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    @ViewBuilder
    private var amount: some View {
        if data.isTransfer,
           let destAmount = data.destinationAmount,
           let destCurrency = data.destinationCurrencyCode,
           destCurrency != data.currencyCode {
            Text(
                appPreferences.currency(Double(truncating: data.amount as NSDecimalNumber),
                                        currencyCode: data.currencyCode, forceFullPrecision: true)
                + " → "
                + appPreferences.currency(Double(truncating: destAmount as NSDecimalNumber),
                                          currencyCode: destCurrency, forceFullPrecision: true)
            )
            .font(DS.Typography.title2)
            .foregroundStyle(typeColor)
            .multilineTextAlignment(.center)
        } else {
            AmountText(
                value: Double(truncating: data.amount as NSDecimalNumber),
                currencyCode: data.currencyCode,
                font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary,
                tint: .color(typeColor),
                forceFullPrecision: true
            )
        }
    }

    // MARK: - Details

    private var fields: [TransactionSuccessFieldOrder.Field] {
        TransactionSuccessFieldOrder.fields(
            isTransfer: data.isTransfer,
            hasSubcategory: data.subcategoryName != nil,
            hasNeed: data.need != nil,
            hasTags: !data.tags.isEmpty
        )
    }

    private var detailsSection: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                row(for: field)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }

    @ViewBuilder
    private func row(for field: TransactionSuccessFieldOrder.Field) -> some View {
        switch field {
        case .date:
            detailRow(icon: "calendar", label: L10n.Transaction.date, spoken: Self.dateFormatter.string(from: data.date), identifier: "transaction_success_date") {
                Text(Self.dateFormatter.string(from: data.date))
            }
        case .account:
            detailRow(icon: "creditcard", label: L10n.Transaction.account, spoken: data.accountName, identifier: "transaction_success_account") {
                dotted(data.accountName, colorHex: data.accountColorHex)
            }
        case .transferAccounts:
            detailRow(icon: "arrow.up.circle", label: L10n.Transaction.origin, spoken: data.accountName,
                      identifier: "transaction_success_source") {
                dotted(data.accountName, colorHex: data.accountColorHex)
            }
            if let destName = data.destinationAccountName, let destColor = data.destinationAccountColorHex {
                detailRow(icon: "arrow.down.circle", label: L10n.Transaction.destination, spoken: destName,
                          identifier: "transaction_success_destination") {
                    dotted(destName, colorHex: destColor)
                }
            }
        case .subcategory:
            detailRow(icon: "tag", label: L10n.Transaction.category, spoken: [data.subcategoryName, data.categoryName].compactMap { $0 }.joined(separator: ", "), identifier: "transaction_success_category") {
                HStack(spacing: DS.Spacing.xs) {
                    dotted(data.subcategoryName ?? "",
                           colorHex: data.subcategoryColorHex ?? data.categoryColorHex ?? AppConstants.defaultColorHex)
                    if let categoryName = data.categoryName {
                        Text(verbatim: "·")
                            .foregroundStyle(.secondary)
                        Text(categoryName)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .need:
            if let need = data.need {
                detailRow(icon: "leaf", label: L10n.Category.need, spoken: need.displayName, identifier: "transaction_success_need") {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle().fill(need.color).frame(width: 8, height: 8)
                        Text(need.displayName)
                    }
                }
            }
        case .tags:
            detailRow(icon: "number", label: L10n.Transaction.tags, spoken: data.tags.map(\.name).joined(separator: ", "), identifier: "transaction_success_tags") {
                Text(data.tags.map(\.name).joined(separator: ", "))
            }
        }
    }

    private func dotted(_ text: String, colorHex: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(text)
        }
    }

    /// Una fila sin rótulo a la vista: icono y valor. El rótulo lo lee VoiceOver.
    private func detailRow<Value: View>(
        icon: String, label: String, spoken: String, identifier: String, @ViewBuilder value: () -> Value
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            value()
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(2)
                // `.combine` y no `.ignore`: así el valor sigue siendo un texto para VoiceOver y para las pruebas.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(label)
                .accessibilityValue(spoken)
                .accessibilityIdentifier(identifier)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Favorito y Recurrente

    /// Dos botones iguales en una fila: abren las hojas de siempre. En una transferencia, solo «Favorito».
    private var offersRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            if let onFavorite {
                offerButton(
                    title: NuevoRegistroB1Text.string(isFavorited ? "success.favorited" : "success.favorite"),
                    icon: isFavorited ? "star.fill" : "star",
                    isDone: isFavorited,
                    action: onFavorite
                )
                .disabled(isFavorited)
                .accessibilityIdentifier("transaction_success_favorite")
            }
            if let onRecurring, !data.isTransfer {
                offerButton(
                    title: NuevoRegistroB1Text.string("success.recurring"),
                    icon: "repeat",
                    isDone: false,
                    action: onRecurring
                )
                .accessibilityIdentifier("transaction_success_recurring")
            }
        }
    }

    private func offerButton(title: String, icon: String, isDone: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(DS.Typography.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isDone ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Capsule().fill(isDone ? AnyShapeStyle(Color.selectedFill(theme.accent)) : AnyShapeStyle(.thCard))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TransactionSuccessView(
        data: TransactionSuccessData(
            transactionType: .expense,
            date: Date.now,
            accountName: "Soles",
            accountColorHex: "FF6B6B",
            note: "Compra en supermercado",
            amount: 125.50,
            currencyCode: "PEN",
            subcategoryName: "Alimentación",
            subcategoryColorHex: "4CAF50",
            categoryName: "Hogar",
            categoryColorHex: "4CAF50",
            tags: [
                (name: "Necesario", colorHex: "2196F3"),
                (name: "Mensual", colorHex: "9C27B0"),
            ],
            need: .essential,
            isTransfer: false,
            destinationAccountName: nil,
            destinationAccountColorHex: nil,
            destinationAmount: nil,
            destinationCurrencyCode: nil
        ),
        onAccept: {},
        onCreateAnother: {},
        onEdit: {},
        onFavorite: {},
        onRecurring: {}
    )
}
