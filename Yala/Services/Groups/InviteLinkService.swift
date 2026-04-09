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
        members: [SplitMember]
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path

        guard let shareData = shareURL.absoluteString.data(using: .utf8) else { return nil }
        let encoded = base64URLEncode(shareData)

        let memberNames = members
            .prefix(5)
            .map { String($0.displayName.prefix(20)) }
            .joined(separator: ",")

        let colorClean = group.colorHex.replacingOccurrences(of: "#", with: "")

        components.queryItems = [
            URLQueryItem(name: "s", value: encoded),
            URLQueryItem(name: "n", value: String(group.name.prefix(50))),
            URLQueryItem(name: "i", value: group.iconName),
            URLQueryItem(name: "c", value: colorClean),
            URLQueryItem(name: "m", value: memberNames),
        ]

        return components.url
    }

    // MARK: - Extract

    /// Extrae el CKShare URL original de un invite URL branded.
    static func extractShareURL(from url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == host || components.host == "www.\(host)",
              components.path == path,
              let encoded = components.queryItems?.first(where: { $0.name == "s" })?.value,
              let data = base64URLDecode(encoded),
              let urlString = String(data: data, encoding: .utf8),
              let shareURL = URL(string: urlString)
        else { return nil }

        return shareURL
    }

    // MARK: - Check

    /// Verifica si una URL es un invite link de Yala.
    static func isInviteLink(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return (components.host == host || components.host == "www.\(host)")
            && components.path == path
            && components.queryItems?.contains(where: { $0.name == "s" }) == true
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
