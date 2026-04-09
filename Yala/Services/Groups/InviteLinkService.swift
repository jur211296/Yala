//
//  InviteLinkService.swift
//  Yala
//
//  Construye y decodifica invite URLs branded (yala-app.pe/invite?...)
//  para invitaciones de grupo via Universal Links.
//

import CloudKit
import Foundation

enum InviteLinkService {

    static let host = "yala-app.pe"
    static let path = "/invite"

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

        // Validate: universal link (yala-app.pe/invite) or custom scheme (yaladev://invite)
        let isUniversalLink = (components.host == host || components.host == "www.\(host)")
            && components.path == path
        let isCustomSchemeInvite = components.host == "invite"

        guard isUniversalLink || isCustomSchemeInvite else { return nil }

        return shareURL
    }

    // MARK: - Extract Metadata

    /// Extrae metadata del grupo desde un invite URL branded (params n, i, c, m).
    static func extractMetadata(from url: URL) -> (name: String?, icon: String?, color: String?, members: [String]?) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return (nil, nil, nil, nil)
        }
        let items = components.queryItems ?? []
        let name = items.first(where: { $0.name == "n" })?.value
        let icon = items.first(where: { $0.name == "i" })?.value
        let color = items.first(where: { $0.name == "c" })?.value
        let membersRaw = items.first(where: { $0.name == "m" })?.value
        let members = membersRaw?.split(separator: ",").map(String.init)
        return (name, icon, color, members)
    }

    // MARK: - Check

    /// Verifica si una URL es un invite link de Yala (universal link o custom scheme).
    static func isInviteLink(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let hasShareParam = components.queryItems?.contains(where: { $0.name == "s" }) == true
        let isUniversalLink = (components.host == host || components.host == "www.\(host)")
            && components.path == path
        let isCustomSchemeInvite = components.host == "invite"
        return (isUniversalLink || isCustomSchemeInvite) && hasShareParam
    }

    // MARK: - Fetch Share Metadata

    /// Obtiene CKShare.Metadata desde un CKShare URL usando CKFetchShareMetadataOperation.
    static func fetchShareMetadata(for url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let metadata):
                    continuation.resume(returning: metadata)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            CKContainer(identifier: CKConstants.containerID).add(operation)
        }
    }

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
