//
//  NotificationPrimerSheet.swift
//  Yala
//
//  Contextual notification permission primer shown after 3rd transaction.
//

import SwiftUI
import SwiftData

struct NotificationPrimerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            // Title
            Text(L10n.NotificationPrimer.title)
                .font(DS.Typography.title)
                .multilineTextAlignment(.center)

            // Benefits
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                benefitRow(icon: "chart.bar.fill", text: L10n.NotificationPrimer.benefit1)
                benefitRow(icon: "calendar.badge.clock", text: L10n.NotificationPrimer.benefit2)
                benefitRow(icon: "bell.fill", text: L10n.NotificationPrimer.benefit3)
            }
            .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            // CTA
            VStack(spacing: DS.Spacing.md) {
                YalaPrimaryButton(
                    L10n.NotificationPrimer.accept,
                    isLoading: isRequesting
                ) {
                    acceptNotifications()
                }

                Button {
                    dismiss()
                } label: {
                    Text(L10n.NotificationPrimer.reject)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text(L10n.NotificationPrimer.hint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .presentationDetents([.medium])
    }

    // MARK: - Components

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.tint)
                .frame(width: DS.Spacing.xxl)
            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Actions

    private func acceptNotifications() {
        isRequesting = true
        Task { @MainActor in
            let granted = await NotificationService.shared.requestPermission()
            if granted {
                NotificationService.shared.seedDefaultNotificationsIfNeeded(context: modelContext)
            }
            isRequesting = false
            dismiss()
        }
    }
}
