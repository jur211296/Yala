//
//  PanelPanoramaSection.swift
//  Yala
//
//  `panelAccountsCollapsed` is reused as the storage key for the whole group
//  to preserve iCloud KV sync across devices; renaming it would orphan the
//  existing value.
//

import SwiftUI

struct PanelPanoramaSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let accountsSortOrderNames: [String]
    let accountsVisible: Bool
    let healthVisible: Bool
    @Binding var accountFormSheet: AccountFormSheet?
    @Binding var showUpgradeForAccounts: Bool

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header

            if !appPreferences.panelAccountsCollapsed {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Header (collapse toggle)

    private var header: some View {
        let expanded = !appPreferences.panelAccountsCollapsed
        return Button {
            dsWithAnimation(reduceMotion) {
                appPreferences.panelAccountsCollapsed.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Panel.panoramaTitle)
                    .font(DS.Typography.title)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(DS.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Panel.panoramaTitle)
        .accessibilityValue(
            expanded ? L10n.Panel.panoramaExpandedValue : L10n.Panel.panoramaCollapsedValue
        )
        .accessibilityHint(
            expanded ? L10n.Panel.panoramaCollapse : L10n.Panel.panoramaExpand
        )
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if accountsVisible {
                PanelAccountsSection(
                    viewModel: viewModel,
                    sessionState: sessionState,
                    accountsSortOrderNames: accountsSortOrderNames,
                    accountFormSheet: $accountFormSheet,
                    showUpgradeForAccounts: $showUpgradeForAccounts
                )
            }
            if healthVisible {
                PanelHealthSection(
                    viewModel: viewModel,
                    sessionState: sessionState
                )
            }
        }
    }
}
