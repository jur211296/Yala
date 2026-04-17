//
//  HeroKPIPreferencesSheet.swift
//  Yala
//
//  Preferences sheet for the Panel 2.0 Hero del mes (P20-04b). Reorder +
//  toggle-visibility for the 6 `HeroKPI` cases. Mirrors the chrome of
//  `PanelSectionPreferencesSheet` (P20-03) — same medium/large adaptive
//  layouts, same reorder sub-sheet pattern, same onDisappear flush/reload.
//
//  Differences vs the section sheet:
//   • Single global set (not per-kind) → no `kind` argument.
//   • Last-active toggle is disabled to guarantee ≥1 pill always renders
//     (consistency with `PanelSectionKind.latestRecords.canBeHidden == false`).
//   • Footer explains the "first 3 shown" rule — the hero caps the HStack
//     at 3 pills so the layout stays stable.
//

import SwiftUI

struct HeroKPIPreferencesSheet: View {
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
            .navigationTitle(L10n.Panel.Hero.KpiPrefs.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.resetHeroKPIPreferences()
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
                    .disabled(HeroKPI.allCases.count < 2)

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
            viewModel.flushPendingHeroKPIWrites()
            viewModel.reloadAndRecalculate()
        }
    }

    // MARK: - Medium Layout (Form — same chrome as PanelSectionPreferencesSheet)

    private var mediumLayout: some View {
        // Hoist once per render — every `toggleRow` needs the active count to
        // decide whether to lock itself. Without this, 6 rows × one recompute
        // each = N² contains-checks on the ≤6-element active list.
        let activeCount = viewModel.activeHeroKPIs(max: .max).count
        return Form {
            Section {
                ForEach(viewModel.orderedHeroKPIs(), id: \.self) { kpi in
                    toggleRow(for: kpi, activeCount: activeCount)
                }
            } footer: {
                Text(L10n.Panel.Hero.KpiPrefs.footer)
            }
        }
    }

    // MARK: - Large Layout (VStack + Divider + solidCard)

    private var largeLayout: some View {
        let activeCount = viewModel.activeHeroKPIs(max: .max).count
        return ZStack {
            PanelBackgroundView()

            ScrollView {
                let kpis = viewModel.orderedHeroKPIs()
                VStack(alignment: .leading, spacing: DS.Spacing.none) {
                    VStack(spacing: DS.Spacing.none) {
                        ForEach(Array(kpis.enumerated()), id: \.element) { index, kpi in
                            toggleRow(for: kpi, activeCount: activeCount)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, DS.Spacing.sm)

                            if index < kpis.count - 1 {
                                Divider()
                                    .padding(.leading, DS.Spacing.lg)
                            }
                        }
                    }
                    .padding(.vertical, DS.Chip.paddingV)
                    .solidCard()

                    Text(L10n.Panel.Hero.KpiPrefs.footer)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, DS.Spacing.md)
                        .padding(.horizontal, DS.Spacing.md)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Reorder Sub-Sheet (List + .onMove, medium detent)

    /// Shows only ACTIVE KPIs. Reordering hidden KPIs is confusing because
    /// they aren't visible in the hero — their position only matters the
    /// moment the user activates them, and by then the toggle row already
    /// lets them move up/down implicitly by enabling/disabling others.
    /// Moving among actives maps 1:1 to the hero order.
    private var reorderSheet: some View {
        NavigationStack {
            List {
                ForEach(viewModel.activeHeroKPIs(max: .max), id: \.self) { kpi in
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: kpi.iconName)
                            .font(DS.Typography.body)
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                        Text(kpi.displayName)
                            .font(DS.Typography.body)
                    }
                }
                .onMove { source, destination in
                    viewModel.moveActiveHeroKPI(from: source, to: destination)
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

    // MARK: - Toggle Row

    /// The Hero renders 3 pills max. We enforce both bounds in the sheet:
    ///   • lower: disabling the second-to-last active toggle would leave a
    ///     single pill, which looks lonely → lock at 2.
    ///   • upper: once 3 are active, hide the "activate" for the rest so the
    ///     user isn't confused when activating doesn't change the hero.
    /// Enforcement is UI-only (the VM tolerates any state) because an older
    /// device iCloud-syncing a 4+ config is possible and shouldn't crash.
    private static let minimumActiveKPIs = 2
    private static let maximumActiveKPIs = 3

    @ViewBuilder
    private func toggleRow(for kpi: HeroKPI, activeCount: Int) -> some View {
        let isHidden = viewModel.isHeroKPIHidden(kpi)
        let lockedAtMinimum = !isHidden && activeCount <= Self.minimumActiveKPIs
        let lockedAtMaximum = isHidden && activeCount >= Self.maximumActiveKPIs
        let subtitleKey: String? = {
            if lockedAtMinimum { return L10n.Panel.Hero.KpiPrefs.minimumActive }
            if lockedAtMaximum { return L10n.Panel.Hero.KpiPrefs.maximumReached }
            if isHidden        { return L10n.Common.hidden }
            return nil
        }()

        Toggle(
            isOn: Binding(
                get: { !isHidden },
                set: { viewModel.setHeroKPIHidden(kpi, hidden: !$0) }
            )
        ) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: kpi.iconName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(kpi.displayName)
                        .font(DS.Typography.body)
                    if let subtitleKey {
                        Text(subtitleKey)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .disabled(lockedAtMinimum || lockedAtMaximum)
    }
}
