//
//  InboxBulkApproveSuccessView.swift
//  Yala
//
//  Success screen after bulk approving drafts from Inbox.
//  Shows count with options: View in Records, Back to Inbox.
//

import SwiftUI

struct InboxBulkApproveSuccessView: View {
    let approvedCount: Int
    let onViewRecords: () -> Void
    let onBackToInbox: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.green)

            // Count
            Text("\(approvedCount)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.electricIndigo)

            // Label
            Text(approvedCount == 1 ? L10n.Inbox.transactionCreated : L10n.Inbox.transactionsCreated)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            // Action buttons
            VStack(spacing: DS.Spacing.md) {
                // Primary: View in Records
                Button(action: onViewRecords) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text(L10n.Inbox.viewInRecords)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.electricIndigo)
                .controlSize(.large)

                // Secondary: Back to Inbox
                Button(action: onBackToInbox) {
                    HStack {
                        Image(systemName: "tray")
                        Text(L10n.Inbox.backToInbox)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.electricIndigo)
                .controlSize(.large)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxxl)
        }
    }
}

#Preview {
    InboxBulkApproveSuccessView(
        approvedCount: 5,
        onViewRecords: {},
        onBackToInbox: {}
    )
}
