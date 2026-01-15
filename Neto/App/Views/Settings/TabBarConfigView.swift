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
                        activeTabsSection
                        if !localConfig.inactiveTabs.isEmpty {
                            availableTabsSection
                        }
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

    // MARK: - Active Tabs Section (Reorderable)

    private var activeTabsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.Settings.tabBarConfigActive)
                    .font(.headline)
                    .foregroundStyle(Color.primary.opacity(0.6))

                Spacer()

                Text("\(localConfig.activeTabs.count)/3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)

            List {
                ForEach(Array(localConfig.activeTabs.enumerated()), id: \.element) { index, tab in
                    activeTabRow(tab, position: index + 1)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.netoCard)
                        .listRowSeparator(index == localConfig.activeTabs.count - 1 ? .hidden : .visible)
                }
                .onMove(perform: moveTab)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(localConfig.activeTabs.count) * 52)
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
            .environment(\.editMode, .constant(.active))

            // Validation message
            if !canDeactivate {
                validationMessage(L10n.Settings.tabBarConfigMinWarning, icon: "exclamationmark.circle")
            }
        }
    }

    private func activeTabRow(_ tab: ConfigurableTab, position: Int) -> some View {
        HStack(spacing: 12) {
            // Position indicator
            Text("\(position)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(Color.electricIndigo)
                .frame(width: 20)

            // Tab icon
            Image(systemName: tab.iconName)
                .font(.body)
                .foregroundStyle(Color.electricIndigo)
                .frame(width: 28, height: 28)

            // Tab name
            Text(tab.displayName)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // Remove button (if can deactivate)
            if canDeactivate {
                Button {
                    removeTab(tab)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Available Tabs Section

    private var availableTabsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Settings.tabBarConfigAvailable)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(localConfig.inactiveTabs.enumerated()), id: \.element) { index, tab in
                    availableTabRow(tab)

                    if index < localConfig.inactiveTabs.count - 1 {
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

            // Max warning
            if !canActivate {
                validationMessage(L10n.Settings.tabBarConfigMaxWarning, icon: "exclamationmark.circle")
            }
        }
    }

    private func availableTabRow(_ tab: ConfigurableTab) -> some View {
        HStack(spacing: 12) {
            // Tab icon
            Image(systemName: tab.iconName)
                .font(.body)
                .foregroundStyle(Color.secondary)
                .frame(width: 28, height: 28)
                .padding(.leading, 20) // Align with active tabs

            // Tab name
            Text(tab.displayName)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            // Add button
            Button {
                addTab(tab)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(canActivate ? Color.electricIndigo : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canActivate)
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

    private func moveTab(from source: IndexSet, to destination: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            localConfig.activeTabs.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func addTab(_ tab: ConfigurableTab) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            _ = localConfig.activate(tab)
        }
    }

    private func removeTab(_ tab: ConfigurableTab) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            _ = localConfig.deactivate(tab)
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
