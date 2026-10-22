//
//  MetricsClient.swift
//  Yala
//
//  Cliente HTTP del POST /metrics del gateway (molde RemoteConfigClient: público,
//  sin auth/attest, SyncHTTPSession inyectable, jamás bloquea nada).
//

import Foundation
import os

/// Resultado de un envío, decide qué hace el spool con el batch.
nonisolated enum MetricsSendOutcome {
    /// 2xx — entregado, retirar del spool.
    case delivered
    /// 4xx — el server RECHAZÓ el batch (bug de construcción nuestro o binding ausente
    /// jamás — eso responde 200). Retirar igualmente: reintentar un body inválido
    /// atascaría la cabeza del spool para siempre. El breadcrumb lo delata.
    case dropped
    /// Red caída / 5xx — conservar en el spool; el próximo trigger reintenta.
    case retry
}

@MainActor
final class MetricsClient {

    private let baseURL: URL
    private let urlSession: SyncHTTPSession

    init(baseURL: URL = ProxyConfig.baseURL, urlSession: SyncHTTPSession = URLSession.shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func send(install: String, app: String?, events: [MetricsEvent]) async -> MetricsSendOutcome {
        guard !events.isEmpty else { return .delivered }
        var request = URLRequest(url: baseURL.appendingPathComponent("metrics"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(
                MetricsRequestBody(v: 1, install: install, app: app, events: events))
        } catch {
            // Encode imposible con structs planos; si ocurre, el batch jamás será enviable.
            MetricsBreadcrumb.sendDropped(reason: "encode")
            return .dropped
        }
        do {
            let (_, response) = try await urlSession.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            switch status {
            case 200...299:
                return .delivered
            case 400...499:
                MetricsBreadcrumb.sendDropped(reason: "status_\(status)")
                return .dropped
            default:
                MetricsBreadcrumb.sendRetry(reason: "status_\(status)")
                return .retry
            }
        } catch {
            // Offline/timeout = normal; el spool conserva y el próximo trigger reintenta.
            MetricsBreadcrumb.sendRetry(reason: String(describing: type(of: error)))
            return .retry
        }
    }
}

// MARK: - Breadcrumb (Console.app, fuera de #if DEBUG, sin PII)

/// Rastros del pipeline de telemetría propia (molde RemoteConfigBreadcrumb). Sin PII:
/// solo motivos/counts — jamás bodies ni el install hash.
nonisolated enum MetricsBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "Metrics")

    static func sendDropped(reason: String) {
        logger.notice("Metrics sendDropped reason=\(reason, privacy: .public)")
    }

    static func sendRetry(reason: String) {
        logger.notice("Metrics sendRetry reason=\(reason, privacy: .public)")
    }

    static func drained(count: Int) {
        logger.notice("Metrics drained count=\(count, privacy: .public)")
    }
}
