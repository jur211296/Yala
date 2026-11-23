//
//  ConectaTuIALogic.swift
//  Yala
//
//  «Conecta tu IA» (2.3, opción C de Jürgen del 23-nov): las reglas sin efectos. Qué IA se nombran, con qué conector
//  habla cada build, cuándo se puede conectar y cuándo salen las puertas de la Bandeja. Gratis para todos: aquí no hay
//  ninguna puerta Pro (decisión 2).
//

import Foundation

nonisolated enum ConectaTuIALogic {

    /// Las IA que el conector reconoce por su vuelta (`clientLabelFromRedirects` en `mcp/src/writeTool.ts`). Son nombres
    /// de marca: no se traducen.
    enum Provider: String, CaseIterable, Identifiable, Sendable {
        case claude
        case chatgpt
        case grok

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .claude: "Claude"
            case .chatgpt: "ChatGPT"
            case .grok: "Grok"
            }
        }

        /// La IA por el nombre que trae un borrador o la lista del conector. Solo los tres nombres exactos.
        init?(name: String?) {
            guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
            guard let match = Provider.allCases.first(where: { $0.displayName == name }) else { return nil }
            self = match
        }
    }

    /// La dirección que se pega en la IA: la del conector de la misma nube que el build. Yala Dev habla con staging y
    /// Yala con producción, como «Navegadores conectados» (`mcp/wrangler.toml`, `PUBLIC_URL`).
    static func baseURL(isDevBuild: Bool) -> URL? {
        isDevBuild
            ? URL(string: "https://yala-mcp-staging.misty-surf-6866.workers.dev")
            : URL(string: "https://mcp.yala-app.pe")
    }

    static func connectorAddress(isDevBuild: Bool) -> String {
        guard let base = baseURL(isDevBuild: isDevBuild) else { return "" }
        return base.appendingPathComponent("mcp").absoluteString
    }

    /// El nombre que enseña la Bandeja para lo que apuntó una IA: el suyo si es uno de los tres (decisión 6); si no,
    /// `nil` y la fila dice «Tu IA».
    static func aiName(evidence: String?) -> String? {
        Provider(name: evidence)?.displayName
    }

    /// Si la IA puede ver algo. El conector solo lee la cuenta de Yala: con los datos en iCloud, primero hay que pasarlos.
    enum Availability: Equatable, Sendable {
        case ready
        case needsAccount
    }

    /// `forcesReady`: la demo del simulador (`ConectaTuIADemo`), donde no hay sesión de la nube.
    static func availability(storageIsCloud: Bool, hasSession: Bool, forcesReady: Bool = false) -> Availability {
        forcesReady || (storageIsCloud && hasSession) ? .ready : .needsAccount
    }

    /// La tarjeta «Apunta desde tu IA» de la Bandeja vacía (decisión D8): en Pendientes, mientras ninguna IA haya apuntado
    /// nada en este teléfono. Quien ya la usa no necesita que se la presenten.
    static func showsInboxDoor(isPendingFilter: Bool, hasAnyAIDraft: Bool, isSelectionMode: Bool) -> Bool {
        isPendingFilter && !hasAnyAIDraft && !isSelectionMode
    }

    /// El chip «De tu IA» (decisión D9): solo si hay algo que filtrar, o si ya está elegido (para poder volver).
    static func showsAIFilter(aiPendingCount: Int, isSelected: Bool) -> Bool {
        aiPendingCount > 0 || isSelected
    }
}
