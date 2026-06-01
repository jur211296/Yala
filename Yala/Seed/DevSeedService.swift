//
//  DevSeedService.swift
//  Yala
//
//  Orchestrator for dev seed data with progress tracking.
//

#if DEBUG
import Foundation
import SwiftData

/// Perfil de datos a sembrar (controla volumen / contenido).
enum DevSeedProfile: String {
    case minimal
    case realista
    case pesado
    case grupos

    /// Días de historial de transacciones a generar (escala el volumen).
    /// `minimal`/`grupos` (~1 semana) son rápidos para XCUITests. `realista`/`pesado`
    /// para escenarios ricos / performance (arranque más lento, riesgo watchdog).
    var daysBack: Int {
        switch self {
        case .minimal, .grupos: return 7
        case .realista: return 730
        case .pesado: return 3650
        }
    }

    /// Si además siembra un grupo de gastos compartidos (DevSeedGroups).
    var seedsGroups: Bool { self == .grupos }
}

@MainActor @Observable
final class DevSeedService {

    private(set) var isSeeding = false
    private(set) var progress: Double = 0
    private(set) var stepLabel: String = ""

    private(set) var hasSeeded = UserDefaults.standard.bool(forKey: "devSeedDataExecuted")

    // MARK: - Seed

    func seed(in context: ModelContext, profile: DevSeedProfile = .realista) async {
        guard !isSeeding else { return }
        isSeeding = true
        progress = 0

        let calendar = Calendar.current
        let endDate = Date.now
        guard let startDate = calendar.date(byAdding: .day, value: -profile.daysBack, to: endDate) else {
            isSeeding = false
            return
        }

        var rng = SeededRandom(seed: 42)

        // Step 1: Ensure categories exist, then build subcategory lookup
        updateStep(L10n.DevSeed.stepCategories, progress: 0.02)
        seedCategoriesIfNeeded(in: context)
        seedSystemGroupCategoriesIfNeeded(in: context)
        let subcategoryLookup = buildSubcategoryLookup(in: context)

        guard !subcategoryLookup.isEmpty else {
            print("DevSeedService: No subcategories found — cannot seed")
            isSeeding = false
            return
        }

        // Step 2: Create accounts
        updateStep(L10n.DevSeed.stepAccounts, progress: 0.05)
        let accounts = DevSeedAccounts.create(in: context)

        // Step 3: Create tags
        updateStep(L10n.DevSeed.stepTags, progress: 0.08)
        let tags = DevSeedTags.create(in: context)

        // Step 4: Create exchange rates
        updateStep(L10n.DevSeed.stepExchangeRates, progress: 0.10)
        DevSeedExchangeRates.create(
            startDate: startDate, endDate: endDate, rng: &rng, in: context
        )

        // Step 5: Create budgets
        updateStep(L10n.DevSeed.stepBudgets, progress: 0.15)
        DevSeedBudgets.create(
            account: accounts.cuentaPrincipal,
            subcategoryLookup: subcategoryLookup,
            in: context
        )

        // Step 6: Create scheduled payments
        updateStep(L10n.DevSeed.stepScheduledPayments, progress: 0.18)
        let spResult = DevSeedScheduledPayments.create(
            account: accounts.cuentaPrincipal,
            subcategoryLookup: subcategoryLookup,
            in: context
        )

        // Step 7: Flush before massive insert
        updateStep(L10n.DevSeed.stepSavingBase, progress: 0.20)
        do { try context.save() } catch {
            print("DevSeedService: Pre-transaction save error: \(error)")
        }

        // Step 8: Create transactions
        updateStep(L10n.DevSeed.stepTransactions, progress: 0.22)
        await DevSeedTransactions.create(
            startDate: startDate,
            endDate: endDate,
            accounts: accounts,
            tags: tags,
            scheduledPayments: spResult.payments,
            subcategoryLookup: subcategoryLookup,
            rng: &rng,
            progressUpdate: { [weak self] txProgress in
                // Map transaction progress (0-1) to overall progress (0.22-0.95)
                let overall = 0.22 + txProgress * 0.73
                self?.progress = overall
            },
            in: context
        )

        // Step 9: Create initial balances
        updateStep(L10n.DevSeed.stepInitialBalances, progress: 0.96)
        DevSeedTransactions.createInitialBalances(
            startDate: startDate,
            accounts: accounts,
            subcategoryLookup: subcategoryLookup,
            in: context
        )

        // Step 9.5: Inbox drafts (2 pending completos) — Inbox nunca vacío en dev/uitest.
        DevSeedDrafts.create(
            account: accounts.cuentaPrincipal,
            subcategoryLookup: subcategoryLookup,
            in: context
        )

        // Step 10: Grupos (perfil .grupos) — grupo local para QA del tab Grupos
        if profile.seedsGroups {
            updateStep("Grupos de prueba", progress: 0.97)
            DevSeedGroups.create(in: context)
        }

        // Final save
        updateStep(L10n.DevSeed.stepSaving, progress: 0.98)
        do { try context.save() } catch {
            print("DevSeedService: Final save error: \(error)")
        }

        // Mark as executed
        UserDefaults.standard.set(true, forKey: "devSeedDataExecuted")
        hasSeeded = true

        // Notify UI to refresh all data-dependent views
        SessionState.shared.incrementDataVersion()

        updateStep(L10n.DevSeed.stepDone, progress: 1.0)
        try? await Task.sleep(for: .milliseconds(500))
        isSeeding = false
    }

    // MARK: - Reset

    func reset(in context: ModelContext) async {
        guard !isSeeding else { return }
        isSeeding = true
        updateStep(L10n.DevSeed.stepDeleting, progress: 0.05)

        // Delete in dependency order (transactions first, then entities)
        deleteAll(TransactionItem.self, in: context)
        deleteAll(Budget.self, in: context)
        deleteAll(ScheduledPayment.self, in: context)
        deleteAll(ExchangeRate.self, in: context)
        deleteAll(Tag.self, in: context)
        deleteAll(Account.self, in: context)
        deleteAll(FavoritePayment.self, in: context)
        deleteAll(InboxDraft.self, in: context)
        deleteAll(CashFlowOverride.self, in: context)
        deleteAll(CashFlowLine.self, in: context)
        deleteAll(CashFlowPlan.self, in: context)
        deleteAll(Subcategory.self, in: context)
        deleteAll(Category.self, in: context)

        do { try context.save() } catch {
            print("DevSeedService: Reset save error: \(error)")
        }
        SessionState.shared.incrementDataVersion()

        // Clear flags
        UserDefaults.standard.removeObject(forKey: "devSeedDataExecuted")
        UserDefaults.standard.removeObject(forKey: "seedCategoriesExecuted")
        hasSeeded = false

        updateStep(L10n.DevSeed.stepReloading, progress: 0.10)
        isSeeding = false

        // Re-seed
        await seed(in: context)
    }

    // MARK: - Helpers

    private func updateStep(_ label: String, progress: Double) {
        self.stepLabel = label
        self.progress = progress
    }

    private func buildSubcategoryLookup(in context: ModelContext) -> [String: Subcategory] {
        let descriptor = FetchDescriptor<Subcategory>()
        do {
            let subcategories = try context.fetch(descriptor)
            var lookup: [String: Subcategory] = [:]
            for sub in subcategories {
                lookup[sub.name] = sub
            }
            return lookup
        } catch {
            print("DevSeedService: Error fetching subcategories: \(error)")
            return [:]
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        do {
            try context.delete(model: T.self)
        } catch {
            print("DevSeedService: Error deleting \(T.self): \(error)")
        }
    }
}
#endif
