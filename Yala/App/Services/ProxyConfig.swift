//
//  ProxyConfig.swift
//  Yala
//
//  Configuración del gateway seguro (host del Worker). NO contiene secretos.
//  Config commiteada y per-scheme: Yala Dev → Worker staging; Yala (prod) → Worker production.
//

import Foundation

enum ProxyConfig {
    /// Base URL del gateway de Yala.
    /// ⚠️ OWNER (task #7): reemplazar el subdominio `*-REPLACE` por el real de tu cuenta tras
    /// `wrangler deploy` (ej. `yala-gateway-staging.tu-cuenta.workers.dev`). workers.dev no toca DNS.
    nonisolated static var baseURL: URL {
        #if DEV_BUILD
        return URL(string: "https://yala-gateway-staging.misty-surf-6866.workers.dev")!
        #else
        return URL(string: "https://yala-gateway-production.misty-surf-6866.workers.dev")!
        #endif
    }

    /// Host (sin esquema) para la `Configuration` del SDK MacPaw/OpenAI.
    nonisolated static var openAIHost: String {
        baseURL.host ?? "yala-gateway-staging.misty-surf-6866.workers.dev"
    }

    /// Secret de bypass de dev/test (solo DEBUG, solo staging). NO se commitea: se lee de la env var
    /// `YALA_DEV_SHARED_SECRET` del scheme. Vacío → el bypass queda deshabilitado (IA off en simulador).
    nonisolated static var devSharedSecret: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["YALA_DEV_SHARED_SECRET"] ?? ""
        #else
        return ""
        #endif
    }
}
