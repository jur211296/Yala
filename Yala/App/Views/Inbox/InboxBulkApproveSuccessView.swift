//
//  InboxBulkApproveSuccessView.swift
//  Yala
//
//  Success screen after bulk approving drafts from Inbox.
//  Shows count with options: View in Records, Back to Inbox.
//
//  Cascade animation 0/150/300/500/700ms standardize con TransactionSuccessView
//  e InboxApproveSuccessView (F4 — épico transactions-forms-polish-panel-alignment).
//

import SwiftUI

struct InboxBulkApproveSuccessView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var checkmarkSize: CGFloat = 40 // A11Y-DT: @ScaledMetric

    let approvedCount: Int
    let onViewRecords: () -> Void
    let onBackToInbox: () -> Void

    @State private var showHero = false
    @State private var showCount = false
    @State private var showButtons = false

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Success hero (shared component with internal cascade hero → checkmark)
            SuccessHeroView(
                icon: "checkmark",
                gradientColors: DS.Gradients.success,
                glowColor: DS.Semantic.successForeground.opacity(0.25),
                iconSize: checkmarkSize,
                appeared: showHero,
                reduceMotion: reduceMotion
            )
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityHidden(true)

            // Count and label
            VStack(spacing: DS.Spacing.sm) {
                Text("\(approvedCount)")
                    .font(Font.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.thAccent)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                Text(approvedCount == 1 ? L10n.Inbox.transactionCreated : L10n.Inbox.transactionsCreated)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .scaleEffect(showCount ? 1.0 : 0.8)
            .opacity(showCount ? 1.0 : 0.0)

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
            .opacity(showButtons ? 1.0 : 0.0)
            .offset(y: showButtons ? 0 : 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thBackground)
        .onAppear {
            if reduceMotion {
                showHero = true
                showCount = true
                showButtons = true
            } else {
                Task {
                    // 0ms — hero
                    withAnimation(.spring(response: 0.5, dampingFraction: DS.Animation.springBouncy)) {
                        showHero = true
                    }
                    // 300ms — count (hero+checkmark interno completa antes)
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showCount = true
                    }
                    // 700ms — buttons
                    try? await Task.sleep(for: .milliseconds(400))
                    withAnimation(.easeOut(duration: 0.3)) {
                        showButtons = true
                    }
                }
            }
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
