//
//  PrivateGateWipeFailureCopyTests.swift
//  YalaTests
//
//  Ticket `private-gate-wipe-failure-copy-claims-icloud-is-intact`.
//
//  La puerta privada borra primero la zona de iCloud y después las filas del teléfono. Un fallo en la segunda mitad
//  le decía «Tus datos siguen en iCloud, intactos» con la zona ya borrada. Ahora la fase de fallo lleva dentro si la
//  zona se había ido, y el texto sale de ahí.
//
//  (A) El TEXTO que lee la persona en cada caso, comparado como texto.
//  (B) La marca de la zona sobrevive a un re-arme: es lo que hace honesto el copy de un reintento que falla EN la zona.
//  (C) El cableado: la fase se construye con la marca leída tras el borrado, y la pantalla no pinta el texto viejo a
//      pelo.
//

import Foundation
import Testing
@testable import Yala

// MARK: - (A) El texto

/// `@MainActor` porque el copy sale de `L10n`, aislado al MainActor en este target (mismo motivo que
/// `ICloudCorpusCountsTests`).
@Suite("Puerta privada · el copy del borrado de iCloud que falla")
@MainActor
struct PrivateGateWipeFailureCopyTests {

    private typealias PrivateICloud = L10n.Welcome.PrivateICloud

    /// Premisa de los dos tests de abajo: si las dos claves dijeran lo mismo, compararlas no probaría nada.
    @Test("premisa: los dos textos son distintos")
    func premise_theTwoBodiesDiffer() {
        #expect(PrivateICloud.wipeFailedBody != PrivateICloud.wipeDeviceFailedBody)
        #expect(!PrivateICloud.wipeFailedBody.isEmpty)
        #expect(!PrivateICloud.wipeDeviceFailedBody.isEmpty)
    }

    /// Falló antes de la zona —red, cuenta, import en vuelo—: no se tocó nada y «intactos» es verdad.
    @Test("fallo sin tocar la zona ⇒ dice que iCloud sigue intacto")
    func zoneUntouched_saysICloudIsIntact() {
        #expect(WelcomePrivateICloudGateView.wipeFailedBody(zoneGone: false) == PrivateICloud.wipeFailedBody)
    }

    /// **El caso del ticket.** La zona ya se borró y lo del teléfono quedó a medias: «intactos» es falso.
    @Test("fallo con la zona ya borrada ⇒ dice que parte ya no está, no que iCloud sigue intacto")
    func zoneGone_saysPartIsAlreadyGone() {
        let body = WelcomePrivateICloudGateView.wipeFailedBody(zoneGone: true)
        #expect(body == PrivateICloud.wipeDeviceFailedBody)
        #expect(body != PrivateICloud.wipeFailedBody, """
            con la zona ya borrada la pantalla vuelve a decir «Tus datos siguen en iCloud, intactos»
            """)
    }
}

// MARK: - (B) La marca en la que se apoya el copy

/// El copy se elige por la marca y no por el motivo del fallo. Eso solo es correcto si la marca describe la ZONA y no
/// el intento: un reintento que falla EN la zona devuelve un error de CloudKit, y la zona sigue borrada por el intento
/// anterior. Lo sostiene que re-armar no la borre.
@Suite("Puerta privada · la marca de la zona entre intentos", .serialized)
struct PrivateGateZoneMarkAcrossRetriesTests {

    private func freshDefaults(_ name: String = #function) throws -> UserDefaults {
        let suite = "test.privateGateZoneMark.\(name).\(UUID().uuidString)"
        UserDefaults().removePersistentDomain(forName: suite)
        return try #require(UserDefaults(suiteName: suite))
    }

    @Test("re-armar para reintentar no borra que la zona ya se había ido")
    func rearming_keepsTheZoneMark() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        #expect(StorageModePersistence.isICloudCorpusWipeZoneDone(d), "premisa: la zona quedó marcada")

        // «Volver a intentarlo» pasa por `.wiping`, que vuelve a armar antes de llamar.
        StorageModePersistence.armICloudCorpusWipe(d)

        #expect(StorageModePersistence.isICloudCorpusWipeZoneDone(d), """
            re-armar borró la marca: un reintento que falla en la zona volvería a decir «intactos» con iCloud vacío
            """)
    }

    @Test("sin haber cruzado la zona, un fallo no la marca")
    func withoutCrossingTheZone_noMark() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeZoneDone(d))
    }
}

// MARK: - (C) El cableado

@Suite("Puerta privada · el fallo lleva la zona dentro (source-scan)")
struct PrivateGateWipeFailureWiringTests {

    private static let gate = "Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift"

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    /// Sin las líneas de comentario: los docblocks citan los literales que aquí se cuentan.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func slice(from start: String, to end: String, in text: String) throws -> String {
        let a = try #require(text.range(of: start), "no está: \(start)")
        let b = try #require(text.range(of: end, range: a.upperBound..<text.endIndex), "no está: \(end)")
        return String(text[a.upperBound..<b.lowerBound])
    }

    /// Un solo sitio construye la fase, y con la marca leída: un `.wipeFailed(zoneGone: false)` escrito a mano en otro
    /// sitio volvería a decir «intactos» sin mirar la zona.
    @Test("la fase de fallo se construye en un solo sitio, con la marca leída tras el borrado")
    func phase_isBuiltOnceFromTheMark() throws {
        let src = try Self.code(Self.gate)
        let builds = src.components(separatedBy: ".wipeFailed(zoneGone:").count - 1
        #expect(builds == 1, "`.wipeFailed(zoneGone:` aparece \(builds) veces; se construye solo en `wipe()`")
        #expect(src.contains("?? .wipeFailed(zoneGone: zoneGone)"))
        #expect(src.contains("let zoneGone = StorageModePersistence.isICloudCorpusWipeZoneDone()"))
    }

    /// La pantalla pinta el cuerpo que elige la función, no la clave vieja. Un `L10n…wipeFailedBody` a pelo en esa rama
    /// es el bug del ticket con otra forma.
    @Test("la rama del fallo pinta el texto que elige la zona")
    func branch_rendersTheBodyForTheZone() throws {
        let src = try Self.code(Self.gate)
        let branch = try Self.slice(from: "case .wipeFailed(let zoneGone):", to: "case .wipingDevice:", in: src)
        #expect(branch.contains("body: Self.wipeFailedBody(zoneGone: zoneGone),"), "rama leída: \(branch)")
        #expect(!branch.contains("L10n.Welcome.PrivateICloud.wipeFailedBody"), "rama leída: \(branch)")
        // El reintento vuelve al borrado, que relee la marca: no arrastra el `zoneGone` del intento anterior.
        #expect(branch.contains("primaryAction: { phase = .wiping },"), "rama leída: \(branch)")
        #expect(branch.contains("secondaryAction: leaveGate)"), "rama leída: \(branch)")
    }

    /// Irse desde el fallo sigue retirando el arm con la zona ida o sin tocarla: el predicado es por patrón y cubre los
    /// dos valores. Con `==` contra un valor concreto, uno de los dos se quedaría armado y el arranque lo reanudaría a
    /// ciegas.
    @Test("irse desde el fallo retira el arm con cualquier valor de la zona")
    func leaving_disarmsForBothValues() throws {
        let src = try Self.code(Self.gate)
        let predicate = try Self.slice(from: "private var isWipeFailed: Bool {", to: "return false", in: src)
        #expect(predicate.contains("if case .wipeFailed = phase { return true }"), "leído: \(predicate)")
        let leave = try Self.slice(from: "private func leaveGate() {", to: "onBack()", in: src)
        #expect(leave.contains("if isWipeFailed || "), "leído: \(leave)")
    }
}
