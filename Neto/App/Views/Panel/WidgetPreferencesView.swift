//
//  WidgetPreferencesView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

struct WidgetPreferencesView: View {
    @Bindable var viewModel: PanelViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Elige qué quieres ver en tu panel principal y en qué orden.")
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
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.netoCard)  // Adapts to Light/Dark mode
                    }
                    .onMove { source, destination in
                        viewModel.moveWidget(from: source, to: destination)
                    }
                    .deleteDisabled(true)  // Disable delete, use toggles instead
                } header: {
                    Text("Widgets")
                }

                Section {
                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.resetWidgetConfigs()
                        }
                    } label: {
                        Text("Restablecer disposición original")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .listRowBackground(Color.netoCard)  // Adapts to Light/Dark mode
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))  // Force edit mode for reordering handles
            .navigationTitle("Preferencias del panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetPrimaryButton(
                        title: "Hecho",
                        action: { dismiss() }
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.netoBackground.ignoresSafeArea())  // Uses app's adaptive background
        }
    }
}

// MARK: - Row Component

private struct WidgetRow: View {
    let config: WidgetConfig
    let onToggle: () -> Void
    let onSizeChange: (WidgetSize) -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header: Icon, Name, Toggle
            HStack(spacing: 12) {
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
                        Text("Siempre visible • Posición fija")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if !config.isVisible {
                        Text("Oculto")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let sizeName = config.type.displaySizeName(for: config.size) {
                        Text("Tamaño: \(sizeName)")
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
                .opacity(config.isLocked ? 0.6 : 1.0)
                .tint(Color.electricIndigo)
            }

            // Size Controls (Only if visible and not locked)
            // Custom condition: Hide size picker if only 1 size is supported
            if config.isVisible && !config.isLocked && availableSizes(for: config.type).count > 1 {
                Picker(
                    "Tamaño",
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
