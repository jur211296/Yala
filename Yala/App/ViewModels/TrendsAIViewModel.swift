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
        /// Falló: la card vuelve a los bullets de reglas con un aviso (V2-06).
        case failed
    }

    private(set) var phase: Phase = .idle

    /// Cada `reset` o petición nueva invalida la respuesta en vuelo: una
    /// respuesta de otro período o filtro no se pinta sobre el actual.
    @ObservationIgnored private var generation = 0

    /// Pide los bullets: `(input, regenerate)`. En producción, `TrendsAIService`.
    @ObservationIgnored private let request: (TrendsAIInput, Bool) async throws -> [TrendsAIBullet]
    @ObservationIgnored private let isPro: () -> Bool
    @ObservationIgnored private let hasConsent: () -> Bool
    @ObservationIgnored private let isOnline: () -> Bool

    /// Los seams llegan opcionales: un valor por defecto que lea un singleton
    /// `@MainActor` se evalúa fuera del actor y no compila.
    init(
        request: ((TrendsAIInput, Bool) async throws -> [TrendsAIBullet])? = nil,
        isPro: (() -> Bool)? = nil,
        hasConsent: (() -> Bool)? = nil,
        isOnline: (() -> Bool)? = nil
    ) {
        self.request = request ?? { input, regenerate in
            try await TrendsAIService.shared.generate(
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
        if phase != .idle { phase = .idle }
    }

    /// - Parameter regenerate: `true` desde «Regenerar» — salta la caché.
    func generate(input: TrendsAIInput, regenerate: Bool) async {
        guard isPro(), hasConsent() else { return }
        generation += 1
        let token = generation

        guard isOnline() else {
            phase = .failed
            return
        }

        let previous = phase
        phase = .loading
        do {
            let bullets = try await request(input, regenerate)
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
            phase = .failed
        }
    }
}
