//
//  InsightsViewModel.swift
//  Yala
//
//  ViewModel for Smart Insights tab. Computes local data via InsightsCalculator,
//  optionally generates AI insights for Pro users.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {

    // MARK: - Data

    private(set) var insightData: InsightData?

    /// Salud Financiera (mes actual). Siempre representa el mes calendario en curso —
    /// el selector de periodo de Resumen no afecta este score (mismo contrato que el
    /// widget del Panel). Nil hasta que `calculateFinancialScore` corra al menos una vez.
    private(set) var financialScore: FinancialScore?

    // MARK: - AI State

    private(set) var aiInsights: LLMInsightResponse?
    private(set) var isLoadingAI = false
    /// Por qué falló el análisis de IA. El texto lo elige la vista (`AIInsightCardComponents.message(for:)`).
    private(set) var aiError: AIInsightFailure?
    private(set) var aiActivated = false

    // MARK: - AI Generation Context (stored for on-demand button)

    private var lastPeriod: DetailPeriod?
    private var lastFilterHash: Int = 0
    private var lastTxnCount: Int = 0
    private var lastCurrencyCode: String = ""
    private var lastComparisonMode: ComparisonMode = .month
    private var lastCriteria: FilterCriteria = .empty
    private var lastAccounts: [Account] = []
    private var lastCategories: [Category] = []
    private var lastTags: [Tag] = []
    private var lastCustomRange: DateInterval?

    /// Sube cada vez que cambia el contexto del análisis (período, filtros, datos). La vista lo usa como `id` de la tarea
    /// que genera sola el «Resumen con IA» al abrir Observaciones (UX 2.2 · L11-7).
    private(set) var aiContextVersion = 0

    /// Dónde se guardan las respuestas por huella. Inyectable para los tests.
    var aiResultStore: InsightsAIResultStore = .shared

    /// La huella de la pregunta que va de camino al servicio de IA, si hay una.
    private var inFlightAIFingerprint: String?

    // MARK: - Preferences

    var currentTone: InsightTone { .current }
    var currentFocus: InsightFocus { .current }

    // MARK: - Equality Guard

    private(set) var lastInputsSignature: Int = 0

    /// Forces the next `calculateInsightsData` call to recompute even if inputs match.
    func invalidateCache() { lastInputsSignature = 0 }

    // MARK: - Calculation

    /// Computes all insights data from filtered transactions.
    func calculateInsightsData(
        transactions: [TransactionItem],
        accounts: [Account],
        categories: [Category],
        budgets: [Budget],
        scheduledPayments: [ScheduledPayment],
        period: DetailPeriod,
        criteria: FilterCriteria,
        currencyCode: String,
        customRange: DateInterval?,
        comparisonMode: ComparisonMode = .month,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) {
        // El toggle "incluir transacciones de grupos en estadísticas" filtra las TX
        // bridgeadas y por tanto es un input del cálculo — debe entrar en la firma
        // del gate, o cambiarlo no invalidaría el cache y dejaría insightData stale.
        let includeBridgedGroupTx = (UserDefaults.standard.object(forKey: AppPreferences.Keys.includeGroupTransactionsInStats) as? Bool) ?? true

        var hasher = Hasher()
        hasher.combine(SessionState.shared.dataVersion)
        hasher.combine(criteria.hashValue)
        hasher.combine(period)
        hasher.combine(currencyCode)
        hasher.combine(comparisonMode)
        hasher.combine(currentTone)
        hasher.combine(currentFocus)
        hasher.combine(includeBridgedGroupTx)
        if let customRange {
            hasher.combine(customRange.start)
            hasher.combine(customRange.duration)
        }
        let signature = hasher.finalize()
        guard signature != lastInputsSignature else { return }
        lastInputsSignature = signature

        insightData = InsightsCalculator.calculate(
            transactions: transactions,
            accounts: accounts,
            categories: categories,
            budgets: budgets,
            scheduledPayments: scheduledPayments,
            period: period,
            criteria: criteria,
            currencyCode: currencyCode,
            customRange: customRange,
            comparisonMode: comparisonMode,
            tone: currentTone,
            focus: currentFocus,
            includeBridgedGroupTx: includeBridgedGroupTx,
            adjustment: adjustment
        )
    }

    /// Recalcula el Financial Score para el período seleccionado. Se invoca aparte
    /// de `calculateInsightsData` porque tiene su propio gate de re-cálculo en
    /// `DetailContainerView` (depende de `dataVersion + interval`, no de filtros).
    /// `paidAmounts` se carga vía `ScheduledPaymentPaidStatusHelper` para el rango.
    func calculateFinancialScore(
        transactions: [TransactionItem],
        budgets: [Budget],
        scheduledPayments: [ScheduledPayment],
        accounts: [Account],
        paidAmounts: [String: [PaidOccurrenceInfo]],
        period: DetailPeriod,
        customRange: DateInterval?,
        preferredCurrencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) {
        let includeBridgedGroupTx = (UserDefaults.standard.object(forKey: AppPreferences.Keys.includeGroupTransactionsInStats) as? Bool) ?? true
        let newScore = FinancialScoreCalculator.calculate(
            transactions: transactions,
            budgets: budgets,
            scheduledPayments: scheduledPayments,
            accounts: accounts,
            paidAmounts: paidAmounts,
            period: period,
            customRange: customRange,
            preferredCurrencyCode: preferredCurrencyCode,
            includeBridgedGroupTx: includeBridgedGroupTx,
            adjustment: adjustment
        )
        if newScore != financialScore { financialScore = newScore }
    }

    // MARK: - AI Generation Context

    /// Stores the current context so the on-demand button can trigger generation without passing params.
    func storeGenerationContext(
        period: DetailPeriod,
        filterHash: Int,
        txnCount: Int,
        currencyCode: String,
        comparisonMode: ComparisonMode,
        criteria: FilterCriteria,
        accounts: [Account],
        categories: [Category],
        tags: [Tag],
        customRange: DateInterval? = nil
    ) {
        lastCustomRange = customRange
        aiContextVersion &+= 1
        lastPeriod = period
        lastFilterHash = filterHash
        lastTxnCount = txnCount
        lastCurrencyCode = currencyCode
        lastComparisonMode = comparisonMode
        lastCriteria = criteria
        lastAccounts = accounts
        lastCategories = categories
        lastTags = tags
    }

    /// Called from the "Generate AI Insights" button. Uses stored context. `refresh` («Actualizar») pide uno nuevo aunque
    /// haya uno guardado para estos mismos datos.
    func triggerAIGeneration(refresh: Bool = false) async {
        guard let period = lastPeriod else { return }
        aiActivated = true
        await generateAIInsights(
            period: period,
            filterHash: lastFilterHash,
            txnCount: lastTxnCount,
            currencyCode: lastCurrencyCode,
            comparisonMode: lastComparisonMode,
            criteria: lastCriteria,
            accounts: lastAccounts,
            categories: lastCategories,
            tags: lastTags,
            refresh: refresh
        )
    }

    // MARK: - Resumen con IA automático en Pro (UX 2.2 · L11-7)

    /// `true` si este usuario puede recibir el resumen sin tocar nada: Pro y con el consentimiento ya dado. Sin
    /// consentimiento hace falta un toque, y no se puede saltar: es el que autoriza enviar el resumen al servicio de IA.
    var canGenerateAIAutomatically: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
            && UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
    }

    /// La huella de lo que se enviaría ahora al servicio de IA (`InsightsAIResultStore.fingerprint`).
    func currentAIFingerprint() -> String? {
        guard let data = insightData, let period = lastPeriod else { return nil }
        let aggregated = buildAggregatedData(
            data,
            currencyCode: lastCurrencyCode,
            comparisonMode: lastComparisonMode,
            criteria: lastCriteria,
            accounts: lastAccounts,
            categories: lastCategories,
            tags: lastTags
        )
        return InsightsAIResultStore.fingerprint(
            aggregatedData: aggregated,
            period: period.rawValue,
            customRange: period == .custom ? lastCustomRange : nil,
            tone: currentTone,
            focus: currentFocus,
            currencyFormat: UserDefaults.standard.string(forKey: "currencyDisplayFormat") ?? "code"
        )
    }

    /// Tras un recálculo: si hay un resumen guardado para estos mismos datos, se enseña ya, sin llamar a nadie.
    func restoreSavedAIIfAvailable() {
        guard canGenerateAIAutomatically,
              let fingerprint = currentAIFingerprint(),
              let saved = aiResultStore.response(for: fingerprint)
        else { return }
        aiInsights = saved
        aiError = nil
        isLoadingAI = false
        aiActivated = true
    }

    /// Al abrir Observaciones en Pro: el resumen sale solo. Reusa el guardado si los datos no cambiaron; si no, lo pide.
    func autoGenerateIfNeeded() async {
        guard canGenerateAIAutomatically, insightData != nil, !isLoadingAI, aiInsights == nil, aiError == nil
        else { return }
        await triggerAIGeneration()
    }

    /// Resets AI state when period/filters change so the button reappears.
    func resetAIState() {
        aiInsights = nil
        aiActivated = false
        isLoadingAI = false
        aiError = nil
    }

    // MARK: - AI Insights

    /// Generate AI insights if Pro + AI consent + online + has data.
    func generateAIInsights(
        period: DetailPeriod,
        filterHash: Int,
        txnCount: Int,
        currencyCode: String,
        comparisonMode: ComparisonMode = .month,
        criteria: FilterCriteria = .empty,
        accounts: [Account] = [],
        categories: [Category] = [],
        tags: [Tag] = [],
        refresh: Bool = false
    ) async {
        guard let data = insightData else { return }

        // Check prerequisites
        let isPro = FeatureGateService.shared.canAccess(.smartInsightsAI)
        let hasConsent = UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        let isOnline = NetworkMonitor.shared.isConnected

        guard isPro, hasConsent, isOnline else {
            aiInsights = nil
            return
        }

        let tone = currentTone
        let focus = currentFocus

        // El guardado por huella va primero: mismos datos, misma respuesta, sin llamada (UX 2.2 · L11-7).
        let fingerprint = currentAIFingerprint()
        if !refresh, let fingerprint, let saved = aiResultStore.response(for: fingerprint) {
            aiInsights = saved
            aiError = nil
            return
        }
        // La misma pregunta ya va de camino: se espera a su respuesta, que se pintará al llegar.
        if !refresh, let fingerprint, fingerprint == inFlightAIFingerprint {
            isLoadingAI = true
            aiError = nil
            return
        }

        let key = InsightsLLMService.shared.cacheKey(
            period: period.rawValue,
            filterHash: filterHash,
            txnCount: txnCount,
            comparisonMode: comparisonMode.rawValue,
            tone: tone,
            focus: focus
        )

        // Check cache first
        if !refresh, let cached = InsightsLLMService.shared.getCached(key: key) {
            aiInsights = cached
            return
        }

        isLoadingAI = true
        aiError = nil

        // Build aggregated data (never individual transactions)
        let aggregated = buildAggregatedData(
            data,
            currencyCode: currencyCode,
            comparisonMode: comparisonMode,
            criteria: criteria,
            accounts: accounts,
            categories: categories,
            tags: tags
        )

        // La respuesta se enseña solo si sigue describiendo lo que hay en pantalla: un cambio de período o de filtro
        // mientras se espera la deja guardada con su huella, sin pintarla sobre otros datos. Y la misma pregunta en vuelo
        // no se repite: un recálculo a mitad de la espera (cambiar de pestaña y volver) la esperaba con otra llamada, que
        // además chocaba con el freno de 5 s del servicio y salía como error.
        inFlightAIFingerprint = fingerprint
        let contextVersion = aiContextVersion
        func stillCurrent() -> Bool {
            guard let fingerprint else { return contextVersion == aiContextVersion }
            return currentAIFingerprint() == fingerprint
        }
        do {
            let response = try await InsightsLLMService.shared.generateInsights(
                aggregatedData: aggregated,
                cacheKey: key,
                tone: tone,
                focus: focus,
                bypassCache: refresh
            )
            if inFlightAIFingerprint == fingerprint { inFlightAIFingerprint = nil }
            if let fingerprint { aiResultStore.save(response, for: fingerprint) }
            guard stillCurrent() else { return }
            aiInsights = response
            aiActivated = true
        } catch {
            if inFlightAIFingerprint == fingerprint { inFlightAIFingerprint = nil }
            guard stillCurrent() else { return }
            aiError = AIInsightFailureLogic.failure(for: error, isConnected: NetworkMonitor.shared.isConnected)
            #if DEBUG
            print("InsightsViewModel: AI error: \(error)")
            #endif
        }

        isLoadingAI = false
    }

    // MARK: - Helpers

    func buildAggregatedData(
        _ data: InsightData,
        currencyCode: String,
        comparisonMode: ComparisonMode,
        criteria: FilterCriteria = .empty,
        accounts: [Account] = [],
        categories: [Category] = [],
        tags: [Tag] = []
    ) -> [String: Any] {
        let comparisonLabel = comparisonMode == .year ? "año anterior" : "periodo anterior"
        var result: [String: Any] = [
            "currency": currencyCode,
            // Snapshot al payload IA — no reactivo. YalaFormatter deprecated permitido.
            "currency_display": YalaFormatterStatic.currencyIdentifier(for: currencyCode),
            // El idioma de la app, no el de la región: con la app en inglés y el iPhone en Perú,
            // `Locale.current.language` decía español y el análisis llegaba en español.
            "locale": AIPromptLanguage.current,
            "country": Locale.current.region?.identifier ?? "",
            "comparison_ref": comparisonLabel,
            "comparison_label": data.periodSummary.previousPeriodLabel,
            "total_expense": Int(data.periodSummary.totalExpense),
            "total_income": Int(data.periodSummary.totalIncome),
            "net_balance": Int(data.periodSummary.netBalance),
            "spending_total_variation": data.periodSummary.expenseVariation.map { "\(Int($0))%" } ?? "N/A",
            "income_variation": data.periodSummary.incomeVariation.map { "\(Int($0))%" } ?? "N/A",
            "daily_avg_variation": data.periodSummary.dailyAverageVariation.map { "\(Int($0))%" } ?? "N/A",
            "balance_variation": data.periodSummary.balanceVariation.map { "\(Int($0))%" } ?? "N/A",
            "count": data.periodSummary.transactionCount,
            "daily_avg": Int(data.quickStats.dailyAverage)
        ]

        // Top 5 categories with amounts
        if !data.quickStats.topCategories.isEmpty {
            result["top_categories"] = data.quickStats.topCategories.map {
                ["name": $0.category.name, "amount": Int($0.amount), "pct": Int($0.percentage)] as [String: Any]
            }
        }

        // Top subcategory
        if let topSub = data.quickStats.topSubcategory {
            let subName = topSub.subcategory?.name ?? topSub.subcategoryName
            let totalExpense = data.periodSummary.totalExpense
            let pctOfTotal = totalExpense > 0 ? Int((topSub.amount / totalExpense) * 100) : 0
            result["top_subcategory"] = ["name": subName, "amount": Int(topSub.amount), "pct_of_total": pctOfTotal] as [String: Any]
        }

        // Category → Subcategory tree (full context for LLM)
        if !categories.isEmpty {
            result["category_tree"] = categories.visibleCategoryTreeLabels()
        }

        // Highest expense
        if let highest = data.quickStats.highestExpense {
            result["highest_expense"] = ["amount": Int(highest.amount), "description": highest.note] as [String: Any]
        }

        // Highest average weekday
        if let weekday = data.quickStats.highestAvgWeekday {
            result["highest_avg_weekday"] = ["day": weekday.weekdayName, "avg": Int(weekday.average)] as [String: Any]
        }

        // Subscriptions (Netflix, Spotify, etc.)
        if data.commitments.activeSubscriptionsCount > 0 {
            result["subscriptions"] = ["count": data.commitments.activeSubscriptionsCount, "monthly_total": Int(data.commitments.activeSubscriptionsMonthly)] as [String: Any]
        }

        // Recurring payments (rent, utilities, payroll, etc.)
        if data.commitments.activeRecurringCount > 0 {
            result["recurring_payments"] = ["count": data.commitments.activeRecurringCount, "monthly_total": Int(data.commitments.activeRecurringMonthly)] as [String: Any]
        }

        // Pending payments
        if data.commitments.pendingPaymentsCount > 0 {
            result["pending_payments"] = ["count": data.commitments.pendingPaymentsCount, "amount": Int(data.commitments.pendingPaymentsAmount)] as [String: Any]
        }

        // Need split with amounts
        let needDist = data.needDistribution
        if needDist.total > 0 {
            result["need_split"] = [
                "essential": ["pct": Int(needDist.essentialPercent), "amount": Int(needDist.essential)] as [String: Any],
                "priority": ["pct": Int(needDist.priorityPercent), "amount": Int(needDist.priority)] as [String: Any],
                "optional": ["pct": Int(needDist.optionalPercent), "amount": Int(needDist.optional)] as [String: Any]
            ]
        }

        // Budgets at risk with spent + limit
        if !data.commitments.budgetsAtRisk.isEmpty {
            result["budgets_at_risk"] = data.commitments.budgetsAtRisk.map {
                ["name": $0.name, "spent": Int($0.spent), "limit": Int($0.limit), "usage_pct": Int($0.usagePercent)] as [String: Any]
            }
        }

        // Year-over-year with absolute amounts
        if let yoy = data.yearOverYear {
            var yoyDict: [String: Any] = [
                "current": Int(yoy.currentAmount),
                "previous": Int(yoy.previousYearAmount)
            ]
            if let variation = yoy.variation {
                yoyDict["variation"] = "\(Int(variation))%"
            }
            result["year_ago"] = yoyDict
        }

        // Active filters context — tells the AI what subset of data it's seeing
        if criteria.hasActiveFilters {
            result["active_filters"] = buildFilterContext(
                criteria: criteria,
                accounts: accounts,
                categories: categories,
                tags: tags
            )
        }

        // Shared expenses context for AI
        if let groupCtx = data.groupInsightsContext {
            var sharedDict: [String: Any] = [
                "total_shared": Int(groupCtx.totalSharedExpense),
                "total_personal": Int(groupCtx.totalPersonalExpense),
                "shared_count": groupCtx.sharedExpenseCount,
                "active_groups": groupCtx.groupCount
            ]
            let totalExpense = data.periodSummary.totalExpense
            if totalExpense > 0 {
                sharedDict["shared_pct"] = Int((groupCtx.totalSharedExpense / totalExpense) * 100)
            }
            if !groupCtx.groupExpensesByGroup.isEmpty {
                sharedDict["by_group"] = groupCtx.groupExpensesByGroup.prefix(5).map {
                    ["name": $0.groupName, "amount": Int($0.total)] as [String: Any]
                }
            }
            if !groupCtx.sharedCategoryBreakdown.isEmpty {
                sharedDict["top_shared_categories"] = groupCtx.sharedCategoryBreakdown.prefix(3).map {
                    ["name": $0.category, "amount": Int($0.amount)] as [String: Any]
                }
            }
            if groupCtx.pendingDebtTotal > 0 {
                sharedDict["pending_debt"] = Int(groupCtx.pendingDebtTotal)
            }
            result["shared_expenses"] = sharedDict
        }

        return result
    }

    /// Builds a human-readable description of active filters for the AI prompt.
    private func buildFilterContext(
        criteria: FilterCriteria,
        accounts: [Account],
        categories: [Category],
        tags: [Tag]
    ) -> [String: Any] {
        let mode = criteria.isExcludeMode ? "exclude" : "include"
        var filters: [String: Any] = ["mode": mode]
        var descriptions: [String] = []

        // Accounts
        if !criteria.selectedAccounts.isEmpty {
            let names = accounts
                .filter { criteria.selectedAccounts.contains($0.persistentModelID) }
                .map { $0.name }
            if !names.isEmpty {
                filters["accounts"] = names
                let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
                descriptions.append("\(verb) cuentas: \(names.joined(separator: ", "))")
            }
        }

        // Categories
        if !criteria.selectedCategories.isEmpty {
            let names = categories
                .filter { criteria.selectedCategories.contains($0.persistentModelID) }
                .map { $0.name }
            if !names.isEmpty {
                filters["categories"] = names
                let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
                descriptions.append("\(verb) categorías: \(names.joined(separator: ", "))")
            }
        }

        // Subcategories
        if !criteria.selectedSubcategories.isEmpty {
            let names = categories
                .flatMap { $0.subcategories ?? [] }
                .filter { criteria.selectedSubcategories.contains($0.persistentModelID) }
                .map { $0.name }
            if !names.isEmpty {
                filters["subcategories"] = names
                let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
                descriptions.append("\(verb) subcategorías: \(names.joined(separator: ", "))")
            }
        }

        // Tags
        if !criteria.selectedTags.isEmpty {
            let names = tags
                .filter { criteria.selectedTags.contains($0.persistentModelID) }
                .map { $0.name }
            if !names.isEmpty {
                filters["tags"] = names
                let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
                descriptions.append("\(verb) etiquetas: \(names.joined(separator: ", "))")
            }
        }

        // Needs
        if !criteria.selectedNeeds.isEmpty {
            let names = criteria.selectedNeeds.map { $0.displayName }
            filters["needs"] = names
            let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
            descriptions.append("\(verb) naturalezas: \(names.joined(separator: ", "))")
        }

        // Currencies
        if !criteria.selectedCurrencies.isEmpty {
            let codes = criteria.selectedCurrencies.map { $0.rawValue }
            filters["currencies"] = codes
            let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
            descriptions.append("\(verb) monedas: \(codes.joined(separator: ", "))")
        }

        // Transaction nature (income/expense) — always include semantics
        if criteria.selectedTransactionNatures.count == 1,
           let nature = criteria.selectedTransactionNatures.first {
            filters["transaction_type"] = nature == .income ? "income" : "expense"
            descriptions.append("Solo \(nature.displayName.lowercased())")
        }

        // Search text
        if !criteria.searchText.isEmpty {
            filters["search"] = criteria.searchText
            descriptions.append("Buscando: \"\(criteria.searchText)\"")
        }

        filters["summary"] = descriptions.joined(separator: ". ")

        return filters
    }
}
