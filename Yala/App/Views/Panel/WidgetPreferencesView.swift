//
//  WidgetPreferencesView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

struct WidgetPreferencesView: View {
    @Bindable var viewModel: PanelViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @AppStorage("panelShowAIInsight") private var showAIInsight: Bool = false
    @State private var showConsentAlert = false

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    private var hasAIConsent: Bool {
        UserDefaults.standard.bool(forKey: "aiInsightsConsentAccepted")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.Widget.preferencesDescription)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                }

                // AI Observations toggle
                Section {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(DS.Typography.title)
                            .foregroundStyle(.thAccent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(theme.accent.opacity(0.1)))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(L10n.Panel.aiInsightsTitle)
                                .font(DS.Typography.bodyBold)
                            Text(L10n.Panel.aiInsightsDescription)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isProUser {
                            Toggle(L10n.Panel.aiInsightsTitle, isOn: $showAIInsight)
                                .labelsHidden()
                                .onChange(of: showAIInsight) { _, newValue in
                                    if newValue && !hasAIConsent {
                                        showAIInsight = false
                                        showConsentAlert = true
                                    }
                                }
                        } else {
                            ProBadge(size: .small)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                    .listRowBackground(theme.card)
                }

                Section {
                    ForEach(viewModel.widgetConfigs) { config in
                        WidgetRow(
                            config: config,
                            onToggle: {
                                viewModel.toggleWidgetVisibility(id: config.id)
                            },
                            onSizeChange: { newSize in
                                viewModel.updateWidgetSize(id: config.id, newSize: newSize)
                            },
                            onScheduledPaymentsModeChange: { mode in
                                viewModel.updateScheduledPaymentsMode(id: config.id, mode: mode)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(theme.card)  // Adapts to Light/Dark mode
                    }
                    .onMove { source, destination in
                        viewModel.moveWidget(from: source, to: destination)
                    }
                    .deleteDisabled(true)  // Disable delete, use toggles instead
                } header: {
                    Text(L10n.Panel.widgets)
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.resetWidgetConfigs()
                    } label: {
                        Text(L10n.Widget.resetLayout)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(theme.card)  // Adapts to Light/Dark mode
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))  // Force edit mode for reordering handles
            .navigationTitle(L10n.Widget.preferences)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { dismiss() })
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())  // Uses app's adaptive background
            .alert(L10n.AIConsent.insightsTitle, isPresented: $showConsentAlert) {
                Button(L10n.AIConsent.accept) {
                    UserDefaults.standard.set(true, forKey: "aiInsightsConsentAccepted")
                    showAIInsight = true
                }
                Button(L10n.AIConsent.privacyPolicy) {
                    openURL(AppConstants.privacyURL)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.insightsMessage)
            }
        }
    }
}

// MARK: - Row Component

private struct WidgetRow: View {
    @Environment(\.yalaTheme) private var theme
    let config: WidgetConfig
    let onToggle: () -> Void
    let onSizeChange: (WidgetSize) -> Void
    let onScheduledPaymentsModeChange: (ScheduledPaymentsWidgetMode) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Header: Icon, Name, Toggle
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: config.type.iconName)
                    .font(DS.Typography.title)
                    .foregroundStyle(.thAccent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(theme.accent.opacity(0.1))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(config.type.displayName)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.primary)

                    if config.isLocked {
                        Text("\(L10n.Widget.alwaysVisible) • \(L10n.Widget.fixedPosition)")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    } else if !config.isVisible {
                        Text(L10n.Common.hidden)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    } else if config.type == .scheduledPayments {
                        // Show mode name for scheduled payments
                        Text(String(format: L10n.Widget.size, config.scheduledPaymentsMode.displayName))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    } else if let sizeName = config.type.displaySizeName(for: config.size) {
                        Text(String(format: L10n.Widget.size, sizeName))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Toggle (Disabled if locked)
                Toggle(
                    config.type.displayName,
                    isOn: Binding(
                        get: { config.isVisible },
                        set: { newValue in
                            if newValue != config.isVisible { onToggle() }
                        }
                    )
                )
                .labelsHidden()
                .disabled(config.isLocked)
                .accessibilityHint(config.isLocked ? L10n.Accessibility.widgetFixed : "")
                .opacity(config.isLocked ? 0.6 : 1.0)

            }

            // Mode picker for scheduled payments widget
            if config.isVisible && !config.isLocked && config.type == .scheduledPayments {
                Picker(
                    L10n.Widget.sizeLabel,
                    selection: Binding(
                        get: { config.scheduledPaymentsMode },
                        set: { newMode in
                            if newMode != config.scheduledPaymentsMode { onScheduledPaymentsModeChange(newMode) }
                        }
                    )
                ) {
                    ForEach(ScheduledPaymentsWidgetMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, DS.Spacing.formIndent)  // Indent to align with text
            }

            // Size Controls (Only if visible, not locked, and has multiple sizes)
            if config.isVisible && !config.isLocked && config.type != .scheduledPayments && availableSizes(for: config.type).count > 1 {
                Picker(
                    L10n.Widget.sizeLabel,
                    selection: Binding(
                        get: { config.size },
                        set: { newSize in
                            if newSize != config.size { onSizeChange(newSize) }
                        }
                    )
                ) {
                    ForEach(availableSizes(for: config.type)) { size in
                        Text(config.type.displaySizeName(for: size) ?? size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, DS.Spacing.formIndent)  // Indent to align with text
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func availableSizes(for type: WidgetType) -> [WidgetSize] {
        return type.supportedSizes
    }
}
