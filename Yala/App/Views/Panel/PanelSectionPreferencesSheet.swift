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
//  P20-11:
//   - Picker de tamaño (Compacta/Ampliada) por widget cuando `type.supportsSize`.
//   - Botones de reset y reorder en la toolbar cambian a `Color.primary`.
//

import SwiftUI

struct PanelSectionPreferencesSheet: View {
    let kind: PanelSectionKind
    @Bindable var viewModel: PanelViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var sessionState
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedDetent: PresentationDetent = .medium
    @State private var showingReorderSheet = false
    @State private var infoSheetWidget: WidgetType?

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
            .navigationTitle(kind.localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.resetSectionPreferences(kind)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(DS.Typography.body).fontWeight(.medium)
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel(L10n.Widget.resetLayout)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingReorderSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(DS.Typography.body).fontWeight(.medium)
                            .foregroundStyle(Color.primary)
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
        .sheet(item: $infoSheetWidget) { type in
            if let kind = type.infoKind {
                WidgetInfoSheet(kind: kind, viewModel: viewModel) { previewSize in
                    WidgetInfoPreviewFactory.preview(
                        for: type,
                        viewModel: viewModel,
                        sessionState: sessionState,
                        currencyCode: viewModel.defaultCurrencyCode,
                        showVariations: appPreferences.showVariations,
                        reduceMotion: reduceMotion,
                        size: previewSize
                    )
                }
            }
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
                    widgetRow(for: type)
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
                        widgetRow(for: type)
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

    // MARK: - Widget Row (Toggle + optional size picker)

    @ViewBuilder
    private func widgetRow(for type: WidgetType) -> some View {
        let isHidden = viewModel.isWidgetHidden(type)
        let visibilityBinding = Binding(
            get: { !isHidden },
            set: { viewModel.setWidgetHidden(type, hidden: !$0) }
        )
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: type.iconName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(type.displayName)
                            .font(DS.Typography.body)
                        if let infoKind = type.infoKind {
                            Button {
                                infoSheetWidget = type
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(DS.Typography.labelSmall)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(infoKind.title)
                        }
                    }
                    if isHidden {
                        Text(L10n.Common.hidden)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Toggle("", isOn: visibilityBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if type.supportsSize {
                sizePicker(for: type, disabled: isHidden)
            }
        }
    }

    // MARK: - Size Picker (P20-11 — recover M/L variants)

    @ViewBuilder
    private func sizePicker(for type: WidgetType, disabled: Bool) -> some View {
        Picker(
            selection: Binding(
                get: { viewModel.widgetSize(type) },
                set: { viewModel.setWidgetSize(type, size: $0) }
            )
        ) {
            ForEach(type.supportedSizes, id: \.self) { size in
                Text(sizeLabel(size)).tag(size)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .disabled(disabled)
        .accessibilityLabel(type.displayName)
    }

    private func sizeLabel(_ size: WidgetSize) -> String {
        switch size {
        case .small: return L10n.Panel.WidgetSize.small
        case .medium: return L10n.Panel.WidgetSize.medium
        case .large: return L10n.Panel.WidgetSize.large
        }
    }
}
