//
//  CloudSessionRevisionWiringTests.swift
//  YalaTests
//
//  Card n533 · las vistas que pintan con `CloudAuthService.shared.hasSession` se repintan al cambiar la sesión porque leen
//  `CloudSessionRevision` junto a esa lectura, y el contador sube en el único emisor del aviso de nve0.
//
//  Es un scan de fuente: lo que se fija es que la lectura que ATA el body vaya pegada a la de la sesión, y eso no se ve
//  desde un test de lógica. Que repinta de verdad lo mide `YalaAccountUITests` (la fila «Tu cuenta de Yala» con Ajustes
//  abierto: rojo sin el arreglo).
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite(.serialized)
struct CloudSessionRevisionWiringTests {

    private static let track = "CloudSessionRevision.shared.track()"

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") && !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Las líneas de código que siguen a `anchor`, las `count` primeras.
    private static func lines(after anchor: String, in src: String, count: Int) throws -> [String] {
        let start = try #require(src.range(of: anchor), "No está «\(anchor)»")
        return Array(src[start.upperBound...].split(separator: "\n").map(String.init).prefix(count))
    }

    // MARK: - El contador

    @Test func bump_movesTheValue() {
        let before = CloudSessionRevision.shared.value
        CloudSessionRevision.shared.bump()
        #expect(CloudSessionRevision.shared.value == before &+ 1)
    }

    /// Un solo emisor, y el contador sube ahí antes de avisar: un aviso emitido por otro camino no repintaría a nadie.
    @Test func theOnlyEmitterBumpsTheCounter() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudAuthService.swift")
        #expect(src.components(separatedBy: "NotificationCenter.default.post(name:").count - 1 == 1,
                "El aviso de sesión sale por más de un sitio")
        #expect(try Self.lines(after: "private static func postSessionDidChange() {", in: src, count: 2) == [
            "CloudSessionRevision.shared.bump()",
            "NotificationCenter.default.post(name: sessionDidChangeNotification, object: nil)",
        ])
    }

    // MARK: - Las lecturas que pintan

    /// Cada accesor que el body lee abre atando la dependencia, y lee la sesión justo después.
    @Test(arguments: [
        ("Yala/App/Views/Profile/ProfileView.swift",
         "private var signOutRowPath: CloudSignOutFlowLogic.Path {", "return CloudSignOutFlowLogic.path("),
        ("Yala/App/Views/Profile/ProfileView.swift",
         "private var deleteAccountRowHasSession: Bool {",
         "return UITestHooks.fakeBackendSession || CloudAuthService.shared.hasSession"),
        ("Yala/App/Views/Profile/YalaAccountView.swift",
         "if let previewModel { return previewModel }", "return YalaAccountLogic.model("),
        ("Yala/App/Views/Shared/CloudAttestNoticeBanner.swift",
         "guard verdictIsTerminal else { return false }", "return CloudAttestNoticeLogic.showsNotice("),
        ("Yala/App/Views/Shared/AppleIDCloseNoticeView.swift",
         "private var currentCell: CloudSignOutFlowLogic.Path {", "return CloudSignOutFlowLogic.path("),
        ("Yala/App/Views/Groups/GroupInviteOnboardingView.swift",
         "private var joinTapRoute: GroupInviteGroupFirstLogic.JoinTapRoute {",
         "return GroupInviteGroupFirstLogic.joinTapRoute("),
    ])
    func readerTracksTheSession(file: String, anchor: String, read: String) throws {
        let src = try Self.source(file)
        #expect(try Self.lines(after: anchor, in: src, count: 2) == [Self.track, read], "\(file): «\(anchor)»")
    }

    /// El CTA del último paso del educativo se decide en `ctaSection`, que abre atando la dependencia.
    @Test func groupsOnboarding_ctaSectionTracksTheSession() throws {
        let src = try Self.source("Yala/App/Views/Groups/Onboarding/GroupsOnboardingView.swift")
        #expect(try Self.lines(after: "private var ctaSection: some View {", in: src, count: 1)
                == ["let _ = \(Self.track)"])
    }
}
