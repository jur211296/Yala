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

            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

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

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(visibleSummaryItems(for: summary), id: \.icon) { item in
                    summaryRow(icon: item.icon, text: item.text)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
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
    /// (`primaryCurrencyCode` no se chequea: siempre viene poblado desde `defaultCurrencyCode.rawValue`.)
    private func isAllPrefilled(_ s: ICloudAccountSummary) -> Bool {
        s.userName != nil && s.accountsCount > 0 && s.categoriesCount > 0
    }

    /// Filas visibles del resumen `.found`: solo las categorías con count > 0.
    private func visibleSummaryItems(for s: ICloudAccountSummary) -> [(icon: String, text: String)] {
        var items: [(icon: String, text: String)] = []
        if s.accountsCount > 0 {
            items.append(("creditcard.fill", L10n.Welcome.Restore.foundAccounts(s.accountsCount)))
        }
        if s.transactionsCount > 0 {
            items.append(("list.bullet.rectangle", L10n.Welcome.Restore.foundTransactions(s.transactionsCount)))
        }
        if s.budgetsCount > 0 {
            items.append(("chart.pie.fill", L10n.Welcome.Restore.foundBudgets(s.budgetsCount)))
        }
        if s.groupsCount > 0 {
            items.append(("person.2.fill", L10n.Welcome.Restore.foundGroups(s.groupsCount)))
        }
        return items
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

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 24)
            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

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
