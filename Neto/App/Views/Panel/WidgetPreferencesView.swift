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
                        .listRowBackground(Color.white.opacity(0.8))
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
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))  // Force edit mode for reordering handles
            .navigationTitle("Preferencias del panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.electricIndigo)
                }
            }
            .background(Color.deepSlate.opacity(0.05).ignoresSafeArea())
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
                    } else {
                        Text(
                            config.size == .small
                                ? "Tamaño: Pequeño"
                                : config.size == .medium ? "Tamaño: Mediano" : "Tamaño: Grande"
                        )
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
            if config.isVisible && !config.isLocked {
                Picker(
                    "Tamaño",
                    selection: Binding(
                        get: { config.size },
                        set: { onSizeChange($0) }
                    )
                ) {
                    ForEach(WidgetSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, 44)  // Indent to align with text
            }
        }
        .padding(.vertical, 4)
    }
}
