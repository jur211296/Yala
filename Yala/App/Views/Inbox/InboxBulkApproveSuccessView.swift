//
//  InboxBulkApproveSuccessView.swift
//  Yala
//
//  Success screen after bulk approving drafts from Inbox.
//  Shows count with options: View in Records, Back to Inbox.
//

import SwiftUI

struct InboxBulkApproveSuccessView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var checkmarkSize: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var countSize: CGFloat = 48

    let approvedCount: Int
    let onViewRecords: () -> Void
    let onBackToInbox: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Success circle (matching ImageSelectionView style)
            ZStack {
                // Main circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.green.opacity(0.4), radius: 16, x: 0, y: 8)

                // Glass overlay
                Circle()
                    .fill(DS.Colors.backgroundSubtle)
                    .frame(width: 100, height: 100)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                // Checkmark icon
                Image(systemName: "checkmark")
                    .font(.system(size: checkmarkSize, weight: .medium))
                    .foregroundStyle(.white)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }

            // Count and label
            VStack(spacing: DS.Spacing.sm) {
                Text("\(approvedCount)")
                    .font(.system(size: countSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.electricIndigo)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(approvedCount == 1 ? L10n.Inbox.transactionCreated : L10n.Inbox.transactionsCreated)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .background(Color.yalaBackground)
    }
}

#Preview {
    InboxBulkApproveSuccessView(
        approvedCount: 5,
        onViewRecords: {},
        onBackToInbox: {}
    )
}
