//
//  PanelSectionPreferencesSheet.swift
//  Yala
//
//  Per-section preferences sheet for reordering and toggling widgets within
//  one Panel section. Draft mutations persist to `AppPreferences` via
//  `PanelViewModel`'s 200ms debounce; `.onDisappear` flushes pending writes.
//
//  Chrome adapts to the current detent:
//   - medium → `Form` plain (native iOS 26 glass material, matches
//     `PanelSectionsConfigView`).
//   - large  → `PanelBackgroundView` + `List.solidCard()` canonical pattern
//     (UI-PATTERNS.md, mirrors `AccountsSettingsListView`).
//

import SwiftUI

struct PanelSectionPreferencesSheet: View {
    let kind: PanelSectionKind
    @Bindable var viewModel: PanelViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDetent: PresentationDetent = .medium

    private var isLargeDetent: Bool { selectedDetent == .large }

    /// Estimated row height for the large-detent List (icon + toggle + drag
    /// handle + vertical paddings). Matches the fixed `listRowInsets`.
    private static let rowHeight: CGFloat = 60

    var body: some View {
        NavigationStack {
            Group {
                if isLargeDetent {
                    largeLayout
                } else {
                    mediumLayout
                }
            }
            .navigationTitle(L10n.Panel.SectionPrefs.title(kind.localizedTitle))
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
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { dismiss() })
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
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
                    row(for: type)
                }
                .onMove { source, destination in
                    viewModel.moveWidgetInSection(kind, from: source, to: destination)
                }
                .deleteDisabled(true)
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Large Layout (solidCard — UI-PATTERNS.md pattern)

    private var largeLayout: some View {
        let types = viewModel.orderedWidgetTypes(in: kind)
        return ZStack {
            PanelBackgroundView()

            ScrollView {
                List {
                    ForEach(types, id: \.self) { type in
                        row(for: type)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onMove { source, destination in
                        viewModel.moveWidgetInSection(kind, from: source, to: destination)
                    }
                    .deleteDisabled(true)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(types.count) * Self.rowHeight)
                .solidCard()
                .environment(\.editMode, .constant(.active))
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Row (compartido entre ambos layouts)

    @ViewBuilder
    private func row(for type: WidgetType) -> some View {
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
