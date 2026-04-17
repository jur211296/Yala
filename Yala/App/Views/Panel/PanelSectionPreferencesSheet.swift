//
//  PanelSectionPreferencesSheet.swift
//  Yala
//
//  Per-section preferences sheet for toggling widget visibility within one
//  Panel section. Reorder lives in a dedicated sub-sheet (tap the
//  `arrow.up.arrow.down` toolbar button) so the main sheet can keep a clean
//  auto-height layout without `List`'s fixed-frame requirement.
//
//  Draft mutations persist to `AppPreferences` via `PanelViewModel`'s 200ms
//  debounce; `.onDisappear` flushes pending writes.
//
//  Chrome adapts to the current detent:
//   - medium → `Form` plain (native iOS 26 glass material, matches
//     `PanelSectionsConfigView`).
//   - large  → `PanelBackgroundView` + `VStack + Divider + solidCard`
//     canonical pattern (UI-PATTERNS.md, mirrors `CategoriesSettingsListView`).
//

import SwiftUI

struct PanelSectionPreferencesSheet: View {
    let kind: PanelSectionKind
    @Bindable var viewModel: PanelViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDetent: PresentationDetent = .medium
    @State private var showingReorderSheet = false

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            Group {
                if isLargeDetent {
                    largeLayout
                } else {
                    mediumLayout
                }
            }
            .navigationTitle(L10n.Panel.SectionPrefs.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.resetSectionPreferences(kind)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(DS.Typography.body).fontWeight(.medium)
                            .foregroundStyle(.thToolbarIcon)
                    }
                    .accessibilityLabel(L10n.Widget.resetLayout)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingReorderSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(DS.Typography.body).fontWeight(.medium)
                            .foregroundStyle(.thToolbarIcon)
                    }
                    .accessibilityLabel(L10n.Action.reorder)
                    .disabled(viewModel.orderedWidgetTypes(in: kind).count < 2)

                    YalaSaveButton(action: { dismiss() })
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingReorderSheet) {
            reorderSheet
        }
        .onDisappear {
            viewModel.flushPendingSectionWrites()
            viewModel.reloadAndRecalculate()
        }
    }

    // MARK: - Medium Layout (Form — same chrome as PanelSectionsConfigView)

    private var mediumLayout: some View {
        Form {
            Section {
                ForEach(viewModel.orderedWidgetTypes(in: kind), id: \.self) { type in
                    toggleRow(for: type)
                }
            }
        }
    }

    // MARK: - Large Layout (VStack + Divider + solidCard — altura automática)

    private var largeLayout: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                let types = viewModel.orderedWidgetTypes(in: kind)
                VStack(spacing: DS.Spacing.none) {
                    ForEach(Array(types.enumerated()), id: \.element) { index, type in
                        toggleRow(for: type)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)

                        if index < types.count - 1 {
                            Divider()
                                .padding(.leading, DS.Spacing.lg)
                        }
                    }
                }
                .padding(.vertical, DS.Chip.paddingV)
                .solidCard()
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Reorder Sub-Sheet (List + .onMove, medium detent)

    private var reorderSheet: some View {
        NavigationStack {
            List {
                ForEach(viewModel.orderedWidgetTypes(in: kind), id: \.self) { type in
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: type.iconName)
                            .font(DS.Typography.body)
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                        Text(type.displayName)
                            .font(DS.Typography.body)
                    }
                }
                .onMove { source, destination in
                    viewModel.moveWidgetInSection(kind, from: source, to: destination)
                }
                .deleteDisabled(true)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(L10n.Action.reorder)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { showingReorderSheet = false })
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Toggle Row (shared by medium + large)

    @ViewBuilder
    private func toggleRow(for type: WidgetType) -> some View {
        let isHidden = viewModel.isWidgetHidden(type)
        Toggle(
            isOn: Binding(
                get: { !isHidden },
                set: { viewModel.setWidgetHidden(type, hidden: !$0) }
            )
        ) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: type.iconName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(type.displayName)
                        .font(DS.Typography.body)
                    if isHidden {
                        Text(L10n.Common.hidden)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
