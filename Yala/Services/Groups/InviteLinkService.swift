//
//  InviteLinkService.swift
//  Yala
//
//  Construye y decodifica invite URLs branded (yala-app.pe/invite?...)
//  para invitaciones de grupo via Universal Links.
//

import Foundation

enum InviteLinkService {

    static let host = "yala-app.pe"
    static let path = "/invite"

    /// Hosts canónicos + alternos aceptados al validar/extraer un invite URL.
    /// Universal links siguen redirects HTTP a `yala-app.pe` automáticamente,
    /// pero el paste manual (A4 rama C) NO sigue redirects — debe aceptar todos.
    /// Lista de redirects en `Web/vercel.json`.
    static let alternateHosts: [String] = [
        "yala-app.pe", "www.yala-app.pe",
        "yala-pe.com", "www.yala-pe.com",
        "yala-app.com.pe", "www.yala-app.com.pe",
    ]

    // MARK: - Build

    /// Construye un invite URL branded a partir de un CKShare URL y metadata del grupo.
    static func buildInviteURL(
        shareURL: URL,
        group: SplitGroup,
        members: [SplitMember],
        inviterName: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path

        guard let shareData = shareURL.absoluteString.data(using: .utf8) else { return nil }
        let encoded = base64URLEncode(shareData)

        let memberNames = members
            .filter(\.isActive)
            .prefix(5)
            .map { member -> String in
                if member.isCurrentUser {
                    return String(inviterName.prefix(20))
                }
                return String(member.displayName.prefix(20))
            }
            .joined(separator: ",")

        let colorClean = group.colorHex.replacing("#", with: "")

        components.queryItems = [
            URLQueryItem(name: "s", value: encoded),
            URLQueryItem(name: "n", value: String(group.name.prefix(50))),
            URLQueryItem(name: "i", value: group.iconName),
            URLQueryItem(name: "c", value: colorClean),
            URLQueryItem(name: "m", value: memberNames),
            URLQueryItem(name: "u", value: String(inviterName.prefix(30))),
        ]

        return components.url
    }

    // MARK: - Build (backend, G4 DARK)

    /// Construye un invite URL backend (contrato C1) a partir del `group_id` + `token` hex del RPC
    /// `create_group_invite`. Formato:
    ///   `https://yala-app.pe/invite?g=<gid>&t=<token>&s=<b64u("…/invite?g=&t=")>&n=..&i=..&c=..&m=..&u=..`
    /// `s` SIEMPRE presente (el AASA exige la presencia de `s`): es el base64URL de la forma MÍNIMA
    /// self-referential (`…/invite?g=..&t=..` sin cosméticos) para que `invite.astro` — que re-emite SOLO
    /// `s` por el camino custom-scheme — preserve `g`/`t` sin tocarse.
    ///
    /// **VIVO** (medido el 2026-09-04). Este docblock decía «DARK: sin call-sites de UI hoy» y era
    /// cierto cuando se escribió, en G4. Su productor real es `GroupBackendInviteService.createInviteLink`
    /// (`:48`), que a su vez cuelga de los dos botones de compartir enlace —`GroupMembersView` y
    /// `GroupDetailViewModel`—, o sea del recorrido de invitación de todos los grupos backend.
    /// Misma familia que el `AppAttestClient.ensureRegistered()` de `.claude/rules/gateway-attest.md`,
    /// cuya promesa falsa costó una vuelta entera de diagnóstico del 401.
    /// ⇒ **si vuelves a escribir DARK aquí, pega el grep de call-sites al lado:**
    /// `grep -rn "buildBackendInviteURL" Yala/ --include='*.swift'`
    static func buildBackendInviteURL(
        groupID: String,
        token: String,
        group: SplitGroup,
        members: [SplitMember],
        inviterName: String
    ) -> URL? {
        // Forma mínima self-referential para `s` (solo g+t, sin cosméticos).
        var inner = URLComponents()
        inner.scheme = "https"
        inner.host = host
        inner.path = path
        inner.queryItems = [
            URLQueryItem(name: "g", value: groupID),
            URLQueryItem(name: "t", value: token),
        ]
        guard let innerString = inner.url?.absoluteString,
              let innerData = innerString.data(using: .utf8)
        else { return nil }
        let encoded = base64URLEncode(innerData)

        let memberNames = members
            .filter(\.isActive)
            .prefix(5)
            .map { member -> String in
                if member.isCurrentUser {
                    return String(inviterName.prefix(20))
                }
                return String(member.displayName.prefix(20))
            }
            .joined(separator: ",")

        let colorClean = group.colorHex.replacing("#", with: "")

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "g", value: groupID),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: encoded),
            URLQueryItem(name: "n", value: String(group.name.prefix(50))),
            URLQueryItem(name: "i", value: group.iconName),
            URLQueryItem(name: "c", value: colorClean),
            URLQueryItem(name: "m", value: memberNames),
            URLQueryItem(name: "u", value: String(inviterName.prefix(30))),
        ]
        return components.url
    }

    // MARK: - Extract (backend, G4 DARK)

    /// Extrae `(group_id, token)` de un invite URL backend (contrato C1). Estrategia:
    ///   1. `g`+`t` directos si ambos presentes y no vacíos (universal link tapeado directo);
    ///   2. fallback: decodifica `s` → si la URL interior porta `g`+`t`, úsalos (camino custom-scheme
    ///      de `invite.astro`, que re-emite solo `s`);
    ///   3. `nil` → NO es un invite backend.
    /// Un link CKShare actual (`s` = CKShare URL, sin `g`/`t` ni al top ni en el interior) devuelve
    /// `nil` SIEMPRE → el camino CKShare vigente queda intacto.
    static func extractBackendInvite(from url: URL) -> (groupID: String, token: String)? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        // Validación host/path idéntica a `isInviteLink` (menos la exigencia de `s`, que aquí puede venir
        // como g/t directos): universal link en host alterno + path, o custom scheme `//invite`.
        let isUniversalLink = alternateHosts.contains(components.host ?? "")
            && components.path == path
        let isCustomSchemeInvite = components.host == "invite"
        guard isUniversalLink || isCustomSchemeInvite else { return nil }

        let items = components.queryItems ?? []
        // (1) g+t directos.
        if let pair = backendPair(from: items) { return pair }
        // (2) fallback: decodificar `s` → parsear el interior.
        if let encoded = items.first(where: { $0.name == "s" })?.value,
           let data = base64URLDecode(encoded),
           let innerString = String(data: data, encoding: .utf8),
           let inner = URL(string: innerString),
           let innerComponents = URLComponents(url: inner, resolvingAgainstBaseURL: false),
           let pair = backendPair(from: innerComponents.queryItems ?? []) {
            return pair
        }
        return nil
    }

    /// `(g, t)` si ambos parámetros están presentes y no vacíos; `nil` en otro caso.
    private static func backendPair(from items: [URLQueryItem]) -> (groupID: String, token: String)? {
        guard let g = items.first(where: { $0.name == "g" })?.value, !g.isEmpty,
              let t = items.first(where: { $0.name == "t" })?.value, !t.isEmpty
        else { return nil }
        return (groupID: g, token: t)
    }

    // MARK: - Extract

    /// Extrae el CKShare URL original de un invite URL branded.
    /// Acepta universal links (https://yala-app.pe/invite?s=...) y custom schemes (yaladev://invite?s=...).
    static func extractShareURL(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "s" })?.value,
              let data = base64URLDecode(encoded),
              let urlString = String(data: data, encoding: .utf8),
              let shareURL = URL(string: urlString)
        else { return nil }

        // Validate: universal link en cualquier host alterno O custom scheme (yala/yaladev://invite).
        let isUniversalLink = alternateHosts.contains(components.host ?? "")
            && components.path == path
        let isCustomSchemeInvite = components.host == "invite"

        guard isUniversalLink || isCustomSchemeInvite else { return nil }

        return shareURL
    }

    // MARK: - Extract Metadata

    /// Metadata branded del invite link (parámetros n/i/c/m del URL). Usada
    /// para personalizar el banner de invitación con identidad del grupo.
    struct BrandedMetadata: Equatable, Sendable, Codable {
        let name: String?
        let icon: String?
        let color: String?
        let members: [String]?

        nonisolated static let empty = BrandedMetadata(name: nil, icon: nil, color: nil, members: nil)

        /// `true` si hay algo que PINTAR: los tres campos que `GroupInviteOnboardingView` consume
        /// (`name`/`icon`/`color`). `members` queda fuera a propósito — ninguna vista lo lee hoy, así
        /// que una marca con solo `m` no es marca.
        ///
        /// Existe para una decisión concreta: al re-tapear, `persistIntent` **conserva la marca ya
        /// capturada si la nueva no trae nada**. Sin eso, un segundo tap sobre la forma mínima
        /// (`?g=..&t=..`, que la puerta ya acepta) borraría el nombre del grupo que el primer tap sí
        /// traía. Y NO vale `== .empty`: `extractMetadata` sobre `…&m=` devuelve `members: []`, que no
        /// es igual a `.empty` y sin embargo tampoco es marca.
        var hasBranding: Bool {
            name?.isEmpty == false || icon?.isEmpty == false || color?.isEmpty == false
        }
    }

    /// Extrae metadata del grupo desde un invite URL branded (params n, i, c, m).
    static func extractMetadata(from url: URL) -> BrandedMetadata {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .empty
        }
        let items = components.queryItems ?? []
        let membersRaw = items.first(where: { $0.name == "m" })?.value
        return BrandedMetadata(
            name: items.first(where: { $0.name == "n" })?.value,
            icon: items.first(where: { $0.name == "i" })?.value,
            color: items.first(where: { $0.name == "c" })?.value,
            members: membersRaw?.split(separator: ",").map(String.init)
        )
    }

    // MARK: - Check

    /// Verifica si una URL es un invite link de Yala (universal link en cualquier host alterno o custom scheme).
    ///
    /// **Acepta lo mismo que `extractBackendInvite` sabe leer, y ese acoplamiento es el punto.** Esta
    /// función es la PUERTA —las tres entradas (`YalaAppDelegate.application(_:continue:)`,
    /// `AppBootstrapper.handleIncomingURL`, `InviteRecoveryView`) gatean por ella— y el parser es quien
    /// decide qué es un invite. Mientras exigió `s`, la forma mínima `…/invite?g=..&t=..` —que el parser
    /// lee perfectamente, y que es justo lo que `invite.astro` maneja por el camino custom-scheme— no
    /// llegaba a `handleInviteLink`: caía al `switch url.host` de `handleIncomingURL` y moría en su
    /// `default`, **sin una sola línea de UI**. Ese apagón mudo es el peor modo de fallo de este
    /// subsistema y ya se pagó una vez (§S5.2).
    ///
    /// Hoy `buildBackendInviteURL` siempre emite `s`, así que la estrechez era INOCUA; deja de serlo en
    /// cuanto alguien emita el enlace mínimo. ⇒ el criterio es «lo que el parser lee», no «lo que el
    /// productor de hoy escribe».
    ///
    /// **Residual medido (2026-09-05):** el AASA (`Web/public/.well-known/apple-app-site-association`)
    /// sigue con `"?": { "s": "*" }`, así que un universal link SIN `s` lo abre Safari y no la app. Esto
    /// cubre las otras dos vías —custom scheme y paste manual en `InviteRecoveryView`—; el AASA es
    /// despliegue web y va aparte (`invite-aasa-requires-s-param` en backlog).
    static func isInviteLink(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let items = components.queryItems ?? []
        let hasShareParam = items.contains { $0.name == "s" }
        let hasBackendPair = backendPair(from: items) != nil
        let isUniversalLink = alternateHosts.contains(components.host ?? "")
            && components.path == path
        let isCustomSchemeInvite = components.host == "invite"
        return (isUniversalLink || isCustomSchemeInvite) && (hasShareParam || hasBackendPair)
    }

    // MARK: - Fetch Share Metadata


    // MARK: - Base64URL Helpers

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
