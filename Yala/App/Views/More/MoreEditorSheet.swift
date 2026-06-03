//
//  MoreEditorSheet.swift
//  Yala
//
//  Editor del dashboard "Más" (icono del toolbar): reordenar las secciones del
//  dashboard y configurar las pestañas del tab bar (reutiliza TabBarConfigView).
//

import SwiftUI

struct MoreEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    @State private var localOrder: [MoreSectionKind] = MoreSectionKind.allCases
    @State private var showTabBarConfig = false

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        sectionsReorderBlock
                        tabBarConfigBlock
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.More.Editor.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { dismiss() })
                }
            }
        }
        .onAppear {
            localOrder = MoreSectionKind.ordered(from: appPreferences.moreSectionOrder)
        }
        .sheet(isPresented: $showTabBarConfig) {
            TabBarConfigView()
        }
    }

    // MARK: - Reorder de secciones

    private var sectionsReorderBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.More.Editor.sectionsHeader)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.horizontal, DS.Chip.paddingV)

            List {
                ForEach(localOrder) { kind in
                    sectionRow(kind)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(kind == localOrder.last ? .hidden : .visible)
                }
                .onMove(perform: moveSection)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(localOrder.count) * 52)
            .solidCard()
            .environment(\.editMode, .constant(.active))
        }
    }

    private func sectionRow(_ kind: MoreSectionKind) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: kind.icon)
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)
                .frame(width: 28, height: 28)

            Text(kind.title)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
        .accessibilityIdentifier("more_editor_section_\(kind.rawValue)")
    }

    // MARK: - Configurar tab bar (reusa TabBarConfigView)

    private var tabBarConfigBlock: some View {
        Button {
            showTabBarConfig = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "rectangle.bottomthird.inset.filled")
                    .font(DS.Typography.body)
                    .foregroundStyle(.thAccent)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Settings.tabBarConfig)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(L10n.More.Editor.tabBarHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .solidCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("more_editor_tabbar_button")
    }

    private func moveSection(from source: IndexSet, to destination: Int) {
        dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.8)) {
            localOrder.move(fromOffsets: source, toOffset: destination)
        }
        appPreferences.moreSectionOrder = localOrder.map(\.rawValue)
    }
}

#Preview {
    MoreEditorSheet()
        .previewAppPreferences()
}
