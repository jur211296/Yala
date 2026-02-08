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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.Widget.preferencesDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                }

                Section {
                    ForEach(viewModel.widgetConfigs) { config in
                        WidgetRow(
                            config: config,
                            onToggle: {
                                withAnimation {
                                    viewModel.toggleWidgetVisibility(id: config.id)
                                }
                            },
                            onSizeChange: { newSize in
                                withAnimation {
                                    viewModel.updateWidgetSize(id: config.id, newSize: newSize)
                                }
                            },
                            onScheduledPaymentsModeChange: { mode in
                                withAnimation {
                                    viewModel.updateScheduledPaymentsMode(id: config.id, mode: mode)
                                }
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.yalaCard)  // Adapts to Light/Dark mode
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
                        withAnimation {
                            viewModel.resetWidgetConfigs()
                        }
                    } label: {
                        Text(L10n.Widget.resetLayout)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(Color.yalaCard)  // Adapts to Light/Dark mode
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
            .background(Color.yalaBackground.ignoresSafeArea())  // Uses app's adaptive background
        }
    }
}

// MARK: - Row Component

private struct WidgetRow: View {
    let config: WidgetConfig
    let onToggle: () -> Void
    let onSizeChange: (WidgetSize) -> Void
    let onScheduledPaymentsModeChange: (ScheduledPaymentsWidgetMode) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Header: Icon, Name, Toggle
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: config.type.iconName)
                    .font(.title3)
                    .foregroundStyle(Color.electricIndigo)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Color.electricIndigo.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.type.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    if config.isLocked {
                        Text("\(L10n.Widget.alwaysVisible) • \(L10n.Widget.fixedPosition)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if !config.isVisible {
                        Text(L10n.Common.hidden)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if config.type == .scheduledPayments {
                        // Show mode name for scheduled payments
                        Text(String(format: L10n.Widget.size, config.scheduledPaymentsMode.displayName))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let sizeName = config.type.displaySizeName(for: config.size) {
                        Text(String(format: L10n.Widget.size, sizeName))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Toggle (Disabled if locked)
                Toggle(
                    "",
                    isOn: Binding(
                        get: { config.isVisible },
                        set: { _ in onToggle() }
                    )
                )
                .labelsHidden()
                .disabled(config.isLocked)
                .accessibilityHint(config.isLocked ? "Widget fijo, siempre visible" : "")
                .opacity(config.isLocked ? 0.6 : 1.0)
                .tint(Color.electricIndigo)
            }

            // Mode picker for scheduled payments widget
            if config.isVisible && !config.isLocked && config.type == .scheduledPayments {
                Picker(
                    L10n.Widget.sizeLabel,
                    selection: Binding(
                        get: { config.scheduledPaymentsMode },
                        set: { onScheduledPaymentsModeChange($0) }
                    )
                ) {
                    ForEach(ScheduledPaymentsWidgetMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, 44)  // Indent to align with text
            }

            // Size Controls (Only if visible, not locked, and has multiple sizes)
            if config.isVisible && !config.isLocked && config.type != .scheduledPayments && availableSizes(for: config.type).count > 1 {
                Picker(
                    L10n.Widget.sizeLabel,
                    selection: Binding(
                        get: { config.size },
                        set: { onSizeChange($0) }
                    )
                ) {
                    ForEach(availableSizes(for: config.type)) { size in
                        Text(config.type.displaySizeName(for: size) ?? size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, 44)  // Indent to align with text
            }
        }
        .padding(.vertical, 4)
    }

    private func availableSizes(for type: WidgetType) -> [WidgetSize] {
        return type.supportedSizes
    }
}
