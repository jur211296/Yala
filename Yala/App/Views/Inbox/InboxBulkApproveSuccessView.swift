//
//  InboxBulkApproveSuccessView.swift
//  Yala
//
//  Pantalla de éxito tras aprobar varios borradores de la Bandeja, con el diseño minimalista del registro personal
//  (encargo del 2026-11-24): un check pequeño junto a «3 registros guardados», el total grande si todos comparten moneda
//  (si no, cuántos), y una tarjeta sin rótulos con la cuenta común y lo que se quedó en la Bandeja. Al pie, «Volver a
//  bandeja» y «Ver en registros» lado a lado.
//

import SwiftUI

struct InboxBulkApproveSuccessView: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    let approvedCount: Int
    /// Total y cuenta de lo aprobado; cada parte sale solo si es la misma para todos.
    var summary: InboxBulkApproveSummaryLogic.Summary = .init(total: nil, currencyCode: nil, accountName: nil)
    /// Lo que no se guardó y qué le falta (UX 2.2 · L4-7): antes «2 transacciones creadas» no decía que uno se quedó.
    var leftoverLine: String? = nil
    /// Lo que se quedó en la Bandeja por parecerse a un registro que ya existe (lote 03 de las necesarias 2.3).
    var duplicatesLine: String? = nil
    let onViewRecords: () -> Void
    let onBackToInbox: () -> Void

    @State private var showHero = false
    @State private var showDetails = false
    @State private var showActions = false

    private var figure: InboxApproveSuccessLogic.BulkFigure {
        InboxApproveSuccessLogic.bulkFigure(total: summary.total, currencyCode: summary.currencyCode,
                                            approvedCount: approvedCount)
    }

    private var savedSomething: Bool { InboxApproveSuccessLogic.bulkSavedSomething(approvedCount: approvedCount) }

    private var tint: Color { savedSomething ? theme.accentText : DS.Semantic.warningForeground }

    private var hasCardRows: Bool { summary.accountName != nil || leftoverLine != nil || duplicatesLine != nil }

    var body: some View {
        MinimalSuccessLayout(footerVisible: showActions) {
            VStack(spacing: DS.Spacing.none) {
                hero
                    .padding(.bottom, DS.Spacing.xl)
                if hasCardRows {
                    detailsCard
                        .padding(.horizontal, DS.Spacing.xl)
                        .opacity(showDetails ? 1.0 : 0.0)
                        .offset(y: showDetails ? 0 : 15)
                }
            }
        } footer: {
            MinimalSuccessFooter(
                secondary: .init(title: L10n.Inbox.backToInbox, identifier: "inbox_bulk_success_back",
                                 action: onBackToInbox),
                primary: .init(title: L10n.Inbox.viewInRecords, identifier: "inbox_bulk_success_records",
                               action: onViewRecords)
            )
        }
        // Momento de éxito: aquí se pide la oferta de prueba armada (UX 2.2 · L1-12, `TrialOfferMomentLogic`).
        // Con nada guardado (todo se quedó por posible duplicado) no hay momento de éxito.
        .onAppear {
            if savedSomething { TrialOfferMoments.noteRecordSaved() }
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
            MinimalSuccessTitle(
                title: ExitoGruposBandejaText.bulkTitle(approvedCount),
                icon: savedSomething ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                tint: tint,
                bounces: reduceMotion ? false : showHero,
                identifier: "inbox_bulk_success_title"
            )

            figureView
                .scaleEffect(showHero ? 1.0 : 0.9)
                .opacity(showHero ? 1.0 : 0.0)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// El total (o cuántos) grande, como el monto de la personal. Para VoiceOver y las pruebas es UN texto:
    /// «S/ 60.50 en total».
    @ViewBuilder
    private var figureView: some View {
        switch figure {
        case .total(let total, let code):
            AmountText(
                value: total,
                currencyCode: code,
                font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary,
                tint: .color(tint),
                forceFullPrecision: true
            )
            // Un solo texto para VoiceOver y las pruebas (`app.staticTexts`), no las piezas del importe.
            .accessibilityRepresentation {
                Text(L10n.Inbox.bulkSuccessTotal(
                    appPreferences.currency(total, currencyCode: code, forceFullPrecision: true)))
            }
            .accessibilityIdentifier("inbox_bulk_success_summary")
        case .count(let count):
            Text(verbatim: "\(count)")
                .font(DS.Typography.heroAmount)
                .foregroundStyle(tint)
                .accessibilityLabel(ExitoGruposBandejaText.bulkTitle(count))
                .accessibilityIdentifier("inbox_bulk_success_summary")
        }
    }

    // MARK: - Tarjeta

    private var detailsCard: some View {
        MinimalSuccessCard {
            if let account = summary.accountName {
                MinimalSuccessRow(icon: "creditcard", label: L10n.Transaction.account, spoken: account,
                                  identifier: "inbox_bulk_success_account") {
                    Text(account)
                }
            }
            if let leftoverLine {
                warningRow(icon: "exclamationmark.circle", text: leftoverLine,
                           identifier: "inbox_bulk_success_leftover")
            }
            if let duplicatesLine {
                warningRow(icon: "doc.on.doc", text: duplicatesLine, identifier: "inbox_bulk_success_duplicates")
            }
        }
    }

    /// Lo que se quedó en la Bandeja: icono de aviso y el texto entero (las pruebas buscan el texto por su id).
    private func warningRow(icon: String, text: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Semantic.warningForeground)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }
}

#Preview {
    InboxBulkApproveSuccessView(
        approvedCount: 2,
        summary: .init(total: 60.5, currencyCode: "PEN", accountName: "Cuenta Principal"),
        onViewRecords: {},
        onBackToInbox: {}
    )
    .previewAppPreferences()
}
