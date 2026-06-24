//
//  RestoreProgressView.swift
//  Yala
//
//  Pantalla de progreso del restore de iCloud (rama B + alert "Cargar mis datos").
//  La espera real la hace `iCloudSyncService.waitForImportQuiescence`; un refresher
//  paralelo refresca los conteos REALES en vivo (CloudKit no expone un % del import).
//  Barra por fases (connecting → importing → completed/partial). Siempre se muestra
//  un mínimo para no parpadear. Al asentar (o timeout) llama `onSettled` con el summary.
//

import SwiftData
import SwiftUI

struct RestoreProgressView: View {
    let timeout: TimeInterval
    var onSettled: (ICloudAccountSummary) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var counts: ICloudAccountSummary?
    @State private var phase: OnboardingRestorePhase = .connecting
    @State private var runTask: Task<Void, Never>?

    init(timeout: TimeInterval = 90, onSettled: @escaping (ICloudAccountSummary) -> Void) {
        self.timeout = timeout
        self.onSettled = onSettled
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            processingCircle
            VStack(spacing: DS.Spacing.md) {
                Text(phaseLabel)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                progressBar
                liveCounts
            }
            .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
        .task { startFlow() }
        .onDisappear { runTask?.cancel() }
    }

    private var phaseLabel: String {
        switch phase {
        case .connecting: return L10n.Welcome.Restore.Progress.connecting
        case .importing:  return L10n.Welcome.Restore.Progress.importing
        case .completed:  return L10n.Welcome.Restore.Progress.completed
        case .partial:    return L10n.Welcome.Restore.Progress.partial
        }
    }

    private var processingCircle: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [theme.accent.opacity(0.3), .clear],
                                     center: .center, startRadius: 50, endRadius: 90))
                .frame(width: 180, height: 180)
                .blur(radius: 10)
            Circle()
                .fill(LinearGradient(colors: [theme.accent.opacity(0.8), theme.accent.opacity(0.6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 120)
                .shadow(color: theme.accent.opacity(0.4), radius: 20, x: 0, y: 8)
            if OnboardingRestoreProgress.isTerminal(phase) {
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.accent.opacity(0.15)).frame(height: 8)
                Capsule()
                    .fill(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.8)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * OnboardingRestoreProgress.fraction(for: phase)),
                           height: 8)
                    .dsAnimation(.easeInOut(duration: 0.4), value: phase, reduceMotion: reduceMotion)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, DS.Spacing.xxxxl)
    }

    /// Conteos REALES que van apareciendo conforme llegan los lotes de CloudKit.
    /// Iconos + número (sin labels de texto → no requiere L10n; el ícono comunica el tipo).
    private var liveCounts: some View {
        HStack(spacing: DS.Spacing.lg) {
            countChip("creditcard.fill", counts?.accountsCount ?? 0, L10n.Welcome.Restore.foundAccounts(counts?.accountsCount ?? 0))
            countChip("tag.fill", counts?.categoriesCount ?? 0, "\(counts?.categoriesCount ?? 0)")
            countChip("list.bullet.rectangle.fill", counts?.transactionsCount ?? 0, L10n.Welcome.Restore.foundTransactions(counts?.transactionsCount ?? 0))
            countChip("chart.pie.fill", counts?.budgetsCount ?? 0, L10n.Welcome.Restore.foundBudgets(counts?.budgetsCount ?? 0))
            countChip("person.2.fill", counts?.groupsCount ?? 0, L10n.Welcome.Restore.foundGroups(counts?.groupsCount ?? 0))
        }
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: counts)
    }

    @ViewBuilder
    private func countChip(_ icon: String, _ value: Int, _ a11y: String) -> some View {
        if value > 0 {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                Text("\(value)").monospacedDigit().contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(a11y)
        }
    }

    private func startFlow() {
        runTask = Task { @MainActor in
            // Refresco visual paralelo: conteos reales + fase, hasta que asiente.
            let refresher = Task { @MainActor in
                while !Task.isCancelled {
                    do {
                        counts = try modelContext.iCloudAccountSummary(appPreferences: appPreferences)
                    } catch {
                        #if DEBUG
                        print("RestoreProgressView: iCloudAccountSummary falló: \(error)")
                        #endif
                    }
                    phase = OnboardingRestoreProgress.phase(
                        hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport,
                        isQuiescent: iCloudSyncService.shared.isImportQuiescent,
                        timedOut: false
                    )
                    try? await Task.sleep(for: .seconds(0.6))
                }
            }
            // Espera real (primer import + quiescencia) con tope.
            let settled = await iCloudSyncService.shared.waitForImportQuiescence(timeout: timeout)
            refresher.cancel()
            guard !Task.isCancelled else { return }
            phase = settled ? .completed : .partial
            do {
                counts = try modelContext.iCloudAccountSummary(appPreferences: appPreferences)
            } catch {
                #if DEBUG
                print("RestoreProgressView: iCloudAccountSummary falló: \(error)")
                #endif
            }
            // Mínimo de exhibición para que se vea el estado final.
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            onSettled(counts ?? ICloudAccountSummary(
                userName: nil, accountsCount: 0, transactionsCount: 0,
                budgetsCount: 0, groupsCount: 0, primaryCurrencyCode: nil, categoriesCount: 0))
        }
    }
}
