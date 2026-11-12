//
//  TrendsAIViewModel.swift
//  Yala
//
//  Estado del análisis con IA del Trend Insight Card (ticket
//  trends-insight-card-v2-bullets, D3). Propio de Tendencias: no comparte
//  estado con `InsightsViewModel`, cuyo análisis es del período entero.
//

import Foundation
import Observation

@MainActor
@Observable
final class TrendsAIViewModel {

    enum Phase: Equatable {
        /// Sin análisis: la card muestra los bullets de reglas y el CTA.
        case idle
        case loading
        case loaded([TrendsAIBullet])
        /// Falló: la card vuelve a los bullets de reglas con un aviso (V2-06) que dice por qué.
        case failed(AIInsightFailure)
    }

    private(set) var phase: Phase = .idle

    /// Cada `reset` o petición nueva invalida la respuesta en vuelo: una
    /// respuesta de otro período o filtro no se pinta sobre el actual.
    @ObservationIgnored private var generation = 0

    /// La ranura de lo que se ve, la que puso el último `restoreSaved`. Una respuesta automática que llega después de un
    /// recálculo de los mismos datos se pinta igual; con otro período o filtro (`reset` la borra), no.
    @ObservationIgnored private var visibleSlot: String?

    /// Pide los bullets: `(input, regenerate)`. En producción, `TrendsAIService`.
    @ObservationIgnored private let request: (TrendsAIInput, Bool) async throws -> [TrendsAIBullet]
    @ObservationIgnored private let isPro: () -> Bool
    @ObservationIgnored private let hasConsent: () -> Bool
    @ObservationIgnored private let isOnline: () -> Bool
    /// La última respuesta de cada ranura y lo que se generó hoy (encargo `estadisticas-ia-automatica`).
    @ObservationIgnored private let store: StatsAIAutoRefreshStore

    /// Los seams llegan opcionales: un valor por defecto que lea un singleton
    /// `@MainActor` se evalúa fuera del actor y no compila.
    init(
        request: ((TrendsAIInput, Bool) async throws -> [TrendsAIBullet])? = nil,
        isPro: (() -> Bool)? = nil,
        hasConsent: (() -> Bool)? = nil,
        isOnline: (() -> Bool)? = nil,
        store: StatsAIAutoRefreshStore? = nil
    ) {
        self.store = store ?? .shared
        self.request = request ?? { input, regenerate in
            #if DEBUG
            if UITestHooks.statsAIReply { return StatsAIUITestReply.trends }
            #endif
            return try await TrendsAIService.shared.generate(
                input: input, tone: .current, focus: .current, bypassCache: regenerate
            )
        }
        self.isPro = isPro ?? { FeatureGateService.shared.canAccess(.smartInsightsAI) }
        self.hasConsent = hasConsent ?? {
            UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        }
        self.isOnline = isOnline ?? { NetworkMonitor.shared.isConnected }
    }

    /// Cambió el período, un filtro, la métrica o los datos: el análisis ya no
    /// describe lo que se ve. Vuelve al CTA (mismo contrato que
    /// `InsightsViewModel.resetAIState`).
    func reset() {
        generation += 1
        visibleSlot = nil
        if phase != .idle { phase = .idle }
    }

    /// - Parameters:
    ///   - regenerate: `true` desde «Regenerar» — salta la caché.
    ///   - autoRequest: la ranura de lo que se ve; con ella, la respuesta se guarda para enseñarla la próxima vez.
    func generate(input: TrendsAIInput, regenerate: Bool, autoRequest: AutoRequest? = nil) async {
        guard isPro(), hasConsent() else { return }
        generation += 1
        let token = generation

        guard isOnline() else {
            phase = .failed(.offline)
            return
        }

        if let autoRequest {
            // Lo pedido a mano no cuenta para el techo automático, pero sí para «una al día» y el antirrebote.
            store.recordGeneration(page: .trends, slot: autoRequest.slot, automatic: false)
        }
        let previous = phase
        phase = .loading
        do {
            let bullets = try await request(input, regenerate)
            if let autoRequest { save(bullets, for: autoRequest) }
            guard token == generation else { return }
            phase = .loaded(bullets)
        } catch InsightsLLMError.rateLimited {
            // Pedido antes de 5 s desde el anterior: no es un fallo, se queda lo que había
            // (un «Regenerar» rápido borraba un análisis bueno).
            guard token == generation else { return }
            phase = previous == .loading ? .idle : previous
        } catch {
            guard token == generation else { return }
            #if DEBUG
            print("TrendsAIViewModel: Error: \(error)")
            #endif
            phase = .failed(AIInsightFailureLogic.failure(for: error, isConnected: isOnline()))
        }
    }

    // MARK: - Automático (encargo `estadisticas-ia-automatica`)

    /// Lo que la decisión automática necesita de lo que se ve: la petición, su ranura (página + período + métrica +
    /// filtros + idioma…), la huella de las cifras y las cifras que deciden si un cambio es relevante.
    struct AutoRequest {
        let input: TrendsAIInput
        let slot: String
        let fingerprint: String
        let snapshot: StatsAIAutoRefreshLogic.Snapshot

        /// - Parameter slotParts: lo que define la ranura y no viaja en el payload: período, comparación y filtros.
        static func make(
            input: TrendsAIInput,
            transactionCount: Int,
            slotParts: [String: Any],
            tone: InsightTone,
            focus: InsightFocus
        ) -> AutoRequest? {
            var parts = slotParts
            parts["metric"] = input.metric.rawValue
            parts["locale"] = input.locale
            parts["country"] = input.country
            parts["currency"] = input.currencyCode
            parts["currency_display"] = input.currencyDisplay
            parts["tone"] = tone.rawValue
            parts["focus"] = focus.rawValue
            var payload = TrendsAIService.buildPayload(input)
            payload["_tone"] = tone.rawValue
            payload["_focus"] = focus.rawValue
            payload["_slot"] = parts
            guard let slot = StatsAIAutoRefreshStore.slotKey(page: .trends, parts: parts),
                  let fingerprint = InsightsAIResultStore.stableHash(payload)
            else { return nil }
            let snapshot = StatsAIAutoRefreshLogic.Snapshot(
                transactionCount: transactionCount,
                totals: [
                    input.currentTotal,
                    input.cashFlow?.totalIncome ?? 0,
                    input.cashFlow?.totalExpense ?? 0,
                ]
            )
            return AutoRequest(input: input, slot: slot, fingerprint: fingerprint, snapshot: snapshot)
        }
    }

    /// Lo guardado para esta ranura sale ya, sin llamar a nadie, mientras `autoRefresh` decide si toca uno nuevo. Solo
    /// sobre la tarjeta sin análisis: no pisa uno a la vista ni uno que se está pidiendo.
    func restoreSaved(_ autoRequest: AutoRequest) {
        visibleSlot = autoRequest.slot
        guard isPro(), hasConsent(), phase == .idle,
              let (_, bullets) = store.response([TrendsAIBullet].self, page: .trends, slot: autoRequest.slot),
              !bullets.isEmpty
        else { return }
        phase = .loaded(bullets)
    }

    /// Al abrir Tendencias y tras cada recálculo: el análisis sale solo para Pro con la IA aceptada, una vez al día o
    /// ante un cambio relevante, con antirrebote y techo diario (`StatsAIAutoRefreshLogic`). Lo guardado se queda a la
    /// vista mientras se regenera, y un fallo no avisa: la próxima apertura lo reintenta.
    func autoRefresh(_ autoRequest: AutoRequest, now: Date = .now) async {
        let saved = store.entry(page: .trends, slot: autoRequest.slot).map {
            StatsAIAutoRefreshLogic.Saved(fingerprint: $0.fingerprint, savedAt: $0.savedAt, snapshot: $0.snapshot)
        }
        let decision = StatsAIAutoRefreshLogic.decide(
            isPro: isPro(),
            hasConsent: hasConsent(),
            transactionCount: autoRequest.snapshot.transactionCount,
            saved: saved,
            fingerprint: autoRequest.fingerprint,
            snapshot: autoRequest.snapshot,
            today: store.today(page: .trends, slot: autoRequest.slot, now: now),
            now: now
        )
        // Sin red no se gasta el intento: la próxima apertura lo vuelve a decidir. Con algo pidiéndose, tampoco.
        guard case .generate(let reason) = decision, isOnline(), phase != .loading else { return }
        #if DEBUG
        print("TrendsAIViewModel: auto refresh (\(reason.rawValue))")
        #endif
        store.recordGeneration(page: .trends, slot: autoRequest.slot, automatic: true, now: now)
        generation += 1
        let token = generation
        let shown = phase
        let inBackground: Bool
        if case .loaded = shown { inBackground = true } else { inBackground = false }
        if !inBackground { phase = .loading }
        do {
            let bullets = try await request(autoRequest.input, false)
            save(bullets, for: autoRequest)
            let sameView = autoRequest.slot == visibleSlot && phase != .loading
            guard token == generation || sameView, !bullets.isEmpty else { return }
            phase = .loaded(bullets)
        } catch {
            #if DEBUG
            print("TrendsAIViewModel: Error: \(error)")
            #endif
            guard token == generation else { return }
            // Silencioso: lo que había se queda; sin nada, vuelven los bullets de reglas con su botón.
            phase = inBackground ? shown : .idle
        }
    }

    private func save(_ bullets: [TrendsAIBullet], for autoRequest: AutoRequest) {
        guard !bullets.isEmpty else { return }
        store.save(
            bullets,
            page: .trends,
            slot: autoRequest.slot,
            fingerprint: autoRequest.fingerprint,
            snapshot: autoRequest.snapshot
        )
    }
}
