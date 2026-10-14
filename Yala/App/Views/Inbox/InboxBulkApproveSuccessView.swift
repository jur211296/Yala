//
//  InboxBulkApproveSuccessView.swift
//  Yala
//
//  Success screen after bulk approving drafts from Inbox.
//  Shows count with options: View in Records, Back to Inbox.
//

import SwiftUI

struct InboxBulkApproveSuccessView: View {
    @Environment(AppPreferences.self) private var appPreferences

    let approvedCount: Int
    /// Total y cuenta de lo aprobado; cada parte sale solo si es la misma para todos.
    var summary: InboxBulkApproveSummaryLogic.Summary = .init(total: nil, currencyCode: nil, accountName: nil)
    let onViewRecords: () -> Void
    let onBackToInbox: () -> Void

    private var summaryLine: String? {
        var parts: [String] = []
        if let total = summary.total, let code = summary.currencyCode {
            parts.append(L10n.Inbox.bulkSuccessTotal(appPreferences.currency(total, currencyCode: code, forceFullPrecision: true)))
        }
        if let account = summary.accountName { parts.append(account) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // El mismo check que al aprobar uno (UX 2.2 · L4-13, variante 2): verde SUAVE —el tinte al 15 % del verde
            // de éxito, como los indicadores de Últimos registros—, sin halo, degradado ni sombra.
            InboxApproveSuccessCheck(isVisible: true)

            // Count and label
            VStack(spacing: DS.Spacing.sm) {
                Text("\(approvedCount)")
                    .font(Font.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.thAccent)

                Text(approvedCount == 1 ? L10n.Inbox.transactionCreated : L10n.Inbox.transactionsCreated)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                // «S/ 60.50 en total · Cuenta Principal»: lo que se guardó, no solo cuántos.
                if let summaryLine {
                    Text(summaryLine)
                        .font(DS.Typography.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                        .accessibilityIdentifier("inbox_bulk_success_summary")
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: DS.Spacing.md) {
                // Primary: View in Records
                YalaPrimaryButton(L10n.Inbox.viewInRecords, icon: "list.bullet.rectangle") {
                    onViewRecords()
                }

                // Secondary: Back to Inbox
                YalaSecondaryButton(L10n.Inbox.backToInbox, icon: "tray") {
                    onBackToInbox()
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thBackground)
        // Momento de éxito: aquí se pide la oferta de prueba armada (UX 2.2 · L1-12, `TrialOfferMomentLogic`).
        .onAppear { TrialOfferMoments.noteRecordSaved() }
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
