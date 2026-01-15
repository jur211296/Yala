//
//  TabBarConfigView.swift
//  Neto
//
//  Configure which tabs appear in the main TabView.
//  Min 1, Max 3 tabs (plus More which is always visible).
//

import SwiftUI

struct TabBarConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()

    @State private var localConfig: TabBarConfiguration = .default

    private var canDeactivate: Bool {
        localConfig.activeTabs.count > 1
    }

    private var canActivate: Bool {
        localConfig.activeTabs.count < 3
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        infoHeader
                        tabsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(L10n.Settings.tabBarConfig)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Action.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.save) {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            localConfig = TabBarConfiguration.fromJSON(tabConfigJSON)
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.body)
                .foregroundStyle(Color.electricIndigo)

            Text(L10n.Settings.tabBarConfigInfo)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.electricIndigo.opacity(0.1))
        )
    }

    // MARK: - Tabs Section

    private var tabsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Settings.tabBarConfigSections)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(ConfigurableTab.allCases.enumerated()), id: \.element) { index, tab in
                    tabRow(tab)

                    if index < ConfigurableTab.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.netoCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)

            // Validation message
            if !canActivate {
                validationMessage(L10n.Settings.tabBarConfigMaxWarning, icon: "exclamationmark.circle")
            } else if !canDeactivate {
                validationMessage(L10n.Settings.tabBarConfigMinWarning, icon: "exclamationmark.circle")
            }
        }
    }

    private func tabRow(_ tab: ConfigurableTab) -> some View {
        let isActive = localConfig.activeTabs.contains(tab)

        return HStack(spacing: 12) {
            // Tab icon
            Image(systemName: tab.iconName)
                .font(.body)
                .foregroundStyle(isActive ? Color.electricIndigo : Color.secondary)
                .frame(width: 28, height: 28)

            // Tab name
            Text(tab.displayName)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { isActive },
                set: { newValue in
                    toggleTab(tab, activate: newValue)
                }
            ))
            .labelsHidden()
            .tint(Color.electricIndigo)
            .disabled(isActive ? !canDeactivate : !canActivate)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func validationMessage(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 6)
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func toggleTab(_ tab: ConfigurableTab, activate: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if activate {
                _ = localConfig.activate(tab)
            } else {
                _ = localConfig.deactivate(tab)
            }
        }
    }

    private func saveAndDismiss() {
        tabConfigJSON = localConfig.toJSON()
        dismiss()
    }
}

#Preview {
    TabBarConfigView()
}
