//
//  WelcomeRestoreView.swift
//  Yala
//
//  A4 — Rama B del Welcome Chooser. "Ya tengo cuenta" → restore desde iCloud.
//
//  State machine: searching → found / notFound / iCloudDisabled / error.
//  Cada transición a state está gateada por `Task.isCancelled` para evitar
//  resume sobre vista no presentada (race con CKShare, dismiss user, app background).
//

import SwiftData
import SwiftUI

struct WelcomeRestoreView: View {

    enum ViewState: Equatable {
        case searching
        case found(ICloudAccountSummary)
        case notFound
        case iCloudDisabled
        case error
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var state: ViewState = .searching
    @State private var searchTask: Task<Void, Never>?
    @State private var showStartFreshConfirm: Bool = false

    var onContinueWithSummary: (ICloudAccountSummary) -> Void
    var onCompleteSkipAll: () -> Void
    var onStartFresh: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            switch state {
            case .searching:
                searchingView
            case .found(let summary):
                foundView(summary: summary)
            case .notFound:
                notFoundView
            case .iCloudDisabled:
                iCloudDisabledView
            case .error:
                errorView
            }
        }
        .task { startSearch() }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
        .confirmationDialog(
            L10n.Welcome.Restore.startFreshConfirmTitle,
            isPresented: $showStartFreshConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.Welcome.Restore.startFreshConfirmConfirm, role: .destructive) {
                onStartFresh()
            }
            Button(L10n.Welcome.Restore.startFreshConfirmCancel, role: .cancel) {}
        } message: {
            Text(L10n.Welcome.Restore.startFreshConfirmBody)
        }
    }

    // MARK: - Search

    private func startSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            // Distingue iCloud-disabled (state dedicado con CTA Ajustes) de timeout/error
            // antes de invocar `forceFetchAndWait`, que devuelve `false` en ambos casos.
            guard iCloudSyncService.shared.isAccountAvailable else {
                if !Task.isCancelled { state = .iCloudDisabled }
                return
            }
            let success = await iCloudSyncService.shared.forceFetchAndWait(timeout: 15)
            guard !Task.isCancelled else { return }
            guard success else { state = .error; return }
            do {
                let summary = try modelContext.iCloudAccountSummary(appPreferences: appPreferences)
                guard !Task.isCancelled else { return }
                state = summary.hasAnyData ? .found(summary) : .notFound
            } catch {
                if !Task.isCancelled { state = .error }
            }
        }
    }

    // MARK: - State views

    private var searchingView: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Welcome.Restore.searching)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(L10n.Welcome.Restore.searchingTip)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.xxl)
            Spacer()
        }
    }

    private func foundView(summary: ICloudAccountSummary) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer(minLength: DS.Spacing.xxl)

            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: DS.Gradients.heroIntense,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: DS.Spacing.sm) {
                Text(summary.userName.map { L10n.Welcome.Restore.foundTitle($0) } ?? L10n.Welcome.Restore.foundTitleAnonymous)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(L10n.Welcome.Restore.foundBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)

            countCards(for: summary)
                .padding(.horizontal, DS.Spacing.lg)

            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                Button {
                    DS.Haptic.success()
                    if isAllPrefilled(summary) {
                        onCompleteSkipAll()
                    } else {
                        onContinueWithSummary(summary)
                    }
                } label: {
                    Text(L10n.Welcome.Restore.continueAction)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                }

                Button {
                    showStartFreshConfirm = true
                } label: {
                    Text(L10n.Welcome.Restore.startFresh)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    /// Si los 3 inputs que el user introduciría manualmente ya están en iCloud, salta a home.
    /// SSOT: `ICloudAccountSummary.isFullyPrefilled` en `iCloudSyncService.swift` (reusado por WelcomeHero alert).
    private func isAllPrefilled(_ s: ICloudAccountSummary) -> Bool {
        s.isFullyPrefilled
    }

    /// Items visibles del resumen `.found` (count > 0), cada uno renderizado
    /// como card individual.
    private struct CountItem: Identifiable {
        let id = UUID()
        let icon: String
        let count: Int
        let label: String
    }

    private func visibleCountItems(for s: ICloudAccountSummary) -> [CountItem] {
        var items: [CountItem] = []
        if s.accountsCount > 0 {
            items.append(CountItem(icon: "creditcard.fill", count: s.accountsCount,
                                   label: L10n.Welcome.Restore.foundAccounts(s.accountsCount)))
        }
        if s.transactionsCount > 0 {
            items.append(CountItem(icon: "list.bullet.rectangle.fill", count: s.transactionsCount,
                                   label: L10n.Welcome.Restore.foundTransactions(s.transactionsCount)))
        }
        if s.budgetsCount > 0 {
            items.append(CountItem(icon: "chart.pie.fill", count: s.budgetsCount,
                                   label: L10n.Welcome.Restore.foundBudgets(s.budgetsCount)))
        }
        if s.groupsCount > 0 {
            items.append(CountItem(icon: "person.2.fill", count: s.groupsCount,
                                   label: L10n.Welcome.Restore.foundGroups(s.groupsCount)))
        }
        return items
    }

    /// Layout adaptativo según número de categorías visibles:
    /// 1 → card centrado max-width 280pt; 2 → HStack 2 cols;
    /// 3 → HStack 3 cols; 4 → grid 2×2.
    @ViewBuilder
    private func countCards(for summary: ICloudAccountSummary) -> some View {
        let items = visibleCountItems(for: summary)
        switch items.count {
        case 1:
            HStack {
                Spacer()
                countCard(items[0])
                    .frame(maxWidth: 280)
                Spacer()
            }
        case 2, 3:
            HStack(spacing: DS.Spacing.md) {
                ForEach(items) { item in
                    countCard(item)
                        .frame(maxWidth: .infinity)
                }
            }
        default:
            // 4 items o más → grid 2×2.
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: DS.Spacing.md),
                          GridItem(.flexible(), spacing: DS.Spacing.md)],
                spacing: DS.Spacing.md
            ) {
                ForEach(items) { item in
                    countCard(item)
                }
            }
        }
    }

    private func countCard(_ item: CountItem) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: item.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text("\(item.count)")
                .font(DS.Typography.amount)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(item.label)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
        .dsCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.label)
    }

    private var notFoundView: some View {
        emptyStateView(
            icon: "icloud.slash",
            tint: .gray,
            title: L10n.Welcome.Restore.notFoundTitle,
            body: L10n.Welcome.Restore.notFoundBody,
            primaryTitle: L10n.Welcome.Restore.startFresh,
            primaryAction: onStartFresh,
            secondaryTitle: L10n.Welcome.Restore.retry,
            secondaryAction: { state = .searching; startSearch() }
        )
    }

    private var iCloudDisabledView: some View {
        emptyStateView(
            icon: "icloud.slash.fill",
            tint: .orange,
            title: L10n.Welcome.Restore.iCloudDisabledTitle,
            body: L10n.Welcome.Restore.iCloudDisabledBody,
            primaryTitle: L10n.Welcome.Restore.openSettings,
            primaryAction: onOpenSettings,
            secondaryTitle: L10n.Welcome.Restore.startFresh,
            secondaryAction: onStartFresh
        )
    }

    private var errorView: some View {
        emptyStateView(
            icon: "exclamationmark.triangle.fill",
            tint: .orange,
            title: L10n.Welcome.Restore.errorTitle,
            body: L10n.Welcome.Restore.errorBody,
            primaryTitle: L10n.Welcome.Restore.retry,
            primaryAction: { state = .searching; startSearch() },
            secondaryTitle: L10n.Welcome.Restore.startFresh,
            secondaryAction: onStartFresh
        )
    }

    // MARK: - Helpers

    private func emptyStateView(
        icon: String,
        tint: Color,
        title: String,
        body bodyText: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(tint)
            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(bodyText)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)
            Spacer()
            VStack(spacing: DS.Spacing.sm) {
                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                }
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
    }
}
