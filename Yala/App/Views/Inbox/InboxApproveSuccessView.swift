//
//  InboxApproveSuccessView.swift
//  Yala
//
//  Pantalla de éxito tras aprobar un borrador de la Bandeja, con el diseño minimalista del registro personal (encargo
//  del 2026-11-24): «Editar» arriba, un check pequeño en el color del tipo junto a «Gasto guardado», la descripción sobre
//  el monto grande y una tarjeta sin rótulos con fecha, cuenta y categoría. Al pie, «Guardar el siguiente» (si queda
//  otro) y «Aceptar» lado a lado. La presentan la hoja del editor y la de deslizar (`InboxView`, con `item:`).
//

import SwiftUI

/// Data for displaying approved transaction details
struct InboxApproveSuccessData {
    let date: Date
    let accountName: String
    let accountColorHex: String
    let note: String
    let amount: Double
    let currencyCode: String
    let subcategoryName: String
    let categoryName: String
    let categoryColorHex: String
    let isExpense: Bool
}

/// Lo que decide el éxito de la Bandeja sin vista (encargo del 2026-11-24).
nonisolated enum InboxApproveSuccessLogic {

    /// Las filas de la tarjeta al aprobar uno, por importancia: fecha, cuenta y categoría (la nota va sobre el monto).
    enum Field: Equatable { case date, account, category }

    static func fields(hasCategory: Bool) -> [Field] {
        hasCategory ? [.date, .account, .category] : [.date, .account]
    }

    /// Lo grande al aprobar varios: el total si todos comparten moneda (`InboxBulkApproveSummaryLogic`); si no, cuántos.
    enum BulkFigure: Equatable {
        case total(Double, currencyCode: String)
        case count(Int)
    }

    static func bulkFigure(total: Double?, currencyCode: String?, approvedCount: Int) -> BulkFigure {
        if approvedCount > 0, let total, let currencyCode { return .total(total, currencyCode: currencyCode) }
        return .count(approvedCount)
    }

    /// Con nada guardado (todo se quedó por posible duplicado o le falta algo) el check sería mentira: va un aviso.
    static func bulkSavedSomething(approvedCount: Int) -> Bool { approvedCount > 0 }
}

struct InboxApproveSuccessView: View {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("dMMMy")
        return formatter
    }()

    let data: InboxApproveSuccessData
    let hasNextDraft: Bool
    let onEdit: () -> Void
    let onAccept: () -> Void
    let onApproveNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHero = false
    @State private var showDetails = false
    @State private var showActions = false

    private var type: TransactionType { data.isExpense ? .expense : .income }

    private var savedTitle: String {
        NuevoRegistroB1Text.string(data.isExpense ? "success.saved.expense" : "success.saved.income")
    }

    var body: some View {
        MinimalSuccessLayout(onEdit: onEdit, editIdentifier: "inbox_success_edit", footerVisible: showActions) {
            VStack(spacing: DS.Spacing.none) {
                hero
                    .padding(.bottom, DS.Spacing.xl)
                detailsCard
                    .padding(.horizontal, DS.Spacing.xl)
                    .opacity(showDetails ? 1.0 : 0.0)
                    .offset(y: showDetails ? 0 : 15)
            }
        } footer: {
            MinimalSuccessFooter(
                secondary: hasNextDraft
                    ? .init(title: L10n.Inbox.approveNext, identifier: "inbox_success_approve_next", action: onApproveNext)
                    : nil,
                primary: .init(title: L10n.Common.accept, identifier: "inbox_success_accept", action: onAccept)
            )
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
            MinimalSuccessTitle(title: savedTitle, tint: type.color, bounces: reduceMotion ? false : showHero,
                                identifier: "inbox_success_title")

            if !data.note.isEmpty {
                MinimalSuccessDescription(text: data.note, identifier: "inbox_success_description")
            }

            // Sin signo, como en la personal: el color y el título ya dicen si es gasto o ingreso.
            AmountText(
                value: abs(data.amount),
                currencyCode: data.currencyCode,
                font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary,
                tint: .color(type.color),
                forceFullPrecision: true
            )
            .scaleEffect(showHero ? 1.0 : 0.9)
            .opacity(showHero ? 1.0 : 0.0)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Tarjeta

    private var detailsCard: some View {
        MinimalSuccessCard {
            ForEach(InboxApproveSuccessLogic.fields(hasCategory: !data.subcategoryName.isEmpty), id: \.self) { field in
                row(for: field)
            }
        }
    }

    @ViewBuilder
    private func row(for field: InboxApproveSuccessLogic.Field) -> some View {
        switch field {
        case .date:
            let date = Self.dateFormatter.string(from: data.date)
            MinimalSuccessRow(icon: "calendar", label: L10n.Transaction.date, spoken: date,
                              identifier: "inbox_success_date") {
                Text(date)
            }
        case .account:
            MinimalSuccessRow(icon: "creditcard", label: L10n.Transaction.account, spoken: data.accountName,
                              identifier: "inbox_success_account") {
                MinimalSuccessDotted(text: data.accountName, colorHex: data.accountColorHex)
            }
        case .category:
            MinimalSuccessRow(icon: "tag", label: L10n.Transaction.category,
                              spoken: [data.subcategoryName, data.categoryName].filter { !$0.isEmpty }
                                .joined(separator: ", "),
                              identifier: "inbox_success_category") {
                // Un solo texto que fluye: con dos piezas lado a lado, «Mascotas y animales» se partía en columna.
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: data.categoryColorHex))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    categoryText
                }
            }
        }
    }

    private var categoryText: Text {
        guard !data.categoryName.isEmpty else { return Text(data.subcategoryName) }
        let separator = Text(verbatim: " · ").foregroundStyle(.secondary)
        let category = Text(data.categoryName).font(DS.Typography.subheadline).foregroundStyle(.secondary)
        return Text("\(Text(data.subcategoryName))\(separator)\(category)")
    }
}

#Preview {
    InboxApproveSuccessView(
        data: InboxApproveSuccessData(
            date: Date.now,
            accountName: "Efectivo",
            accountColorHex: "4CAF50",
            note: "Almuerzo con amigos",
            amount: -45.50,
            currencyCode: "PEN",
            subcategoryName: "Restaurantes",
            categoryName: "Alimentación",
            categoryColorHex: "FF9800",
            isExpense: true
        ),
        hasNextDraft: true,
        onEdit: {},
        onAccept: {},
        onApproveNext: {}
    )
    .previewAppPreferences()
}
