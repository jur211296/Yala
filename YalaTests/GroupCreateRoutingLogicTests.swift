//
//  GroupCreateRoutingLogicTests.swift
//  YalaTests
//
//  Tabla del routing de CREAR GRUPO (G5-A, contrato C3 · **C4: la fábrica de zombis, cerrada**).
//  Pure-logic sin SwiftData/CloudKit, más el source-scan que fija lo que la tabla NO puede fijar.
//
//  ⚠️ **El escenario del canal apagado NO es ejercitable en el harness, y por eso la red es estructural.**
//  `CloudRemoteFlags.decide()` cortocircuita a `absentDefault` bajo `isRunningTests || isUITestHost` **sin
//  leer el snapshot** (`CloudRemoteConfig.swift:186`), y en `Yala Dev` —el scheme de los XCUITest—
//  `absentDefault` es `true` (`:120-126`) ⇒ `CloudSyncFlags.groupsBackendEnabled` nace ON en los dos
//  targets y `.channelOff` es inalcanzable desde cualquier test de integración. No lo busques ni escribas
//  un XCUITest para ello: lo que cubre este chip es esta tabla + `GroupCreateRoutingWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupCreateRoutingLogic · routing de crear grupo (G5-A · C4)")
struct GroupCreateRoutingLogicTests {

    typealias Route = GroupCreateRoutingLogic.Route

    // MARK: - Flag OFF → SIEMPRE channelOff (nunca se crea nada, sin importar sesión/consent)

    @Test("flag OFF ⇒ `.channelOff` en las cuatro combinaciones — la rama `.cloudKit` ya no existe")
    func flagOff_alwaysChannelOff_regardlessOfSessionAndConsent() {
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: false, consentAccepted: false) == .channelOff)
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: true, consentAccepted: false) == .channelOff)
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: false, consentAccepted: true) == .channelOff)
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: true, consentAccepted: true) == .channelOff)
    }

    /// El caso que más engaña: con sesión Y consent, todo «está listo» salvo el canal. Antes de C4 esta
    /// celda devolvía `.cloudKit` y el usuario acababa con un grupo local irrecuperable **sin ver ni un
    /// error** — el camino CloudKit funciona OFFLINE.
    @Test("flag OFF con sesión Y consent NO cae a backend: el canal manda")
    func flagOff_withSessionAndConsent_stillChannelOff() {
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: true, consentAccepted: true) != .backend)
        #expect(GroupCreateRoutingLogic.route(flagOn: false, hasSession: true, consentAccepted: true) == .channelOff)
    }

    /// Con el canal apagado NO se pide identidad: pedir sign-in o consent para después bloquear sería
    /// pedirlos en vano. El canal es el PRIMER término, como en `GroupsOrganizerGateLogic.decide`.
    @Test("flag OFF nunca pide sign-in ni consent")
    func flagOff_neverAsksForIdentity() {
        for hasSession in [false, true] {
            for consent in [false, true] {
                let route = GroupCreateRoutingLogic.route(
                    flagOn: false, hasSession: hasSession, consentAccepted: consent)
                #expect(route != .needsSignIn)
                #expect(route != .needsConsent)
            }
        }
    }

    // MARK: - Flag ON → precedencia sign-in → consent → backend

    @Test func flagOn_noSession_needsSignIn() {
        #expect(GroupCreateRoutingLogic.route(flagOn: true, hasSession: false, consentAccepted: false) == .needsSignIn)
        // Sin sesión, el consent no importa: sign-in primero.
        #expect(GroupCreateRoutingLogic.route(flagOn: true, hasSession: false, consentAccepted: true) == .needsSignIn)
    }

    @Test func flagOn_sessionButNoConsent_needsConsent() {
        #expect(GroupCreateRoutingLogic.route(flagOn: true, hasSession: true, consentAccepted: false) == .needsConsent)
    }

    @Test func flagOn_sessionAndConsent_backend() {
        #expect(GroupCreateRoutingLogic.route(flagOn: true, hasSession: true, consentAccepted: true) == .backend)
    }

    /// El dominio COMPLETO (2×2×2), para que añadir un caso nuevo a `Route` sin decidir su celda no pase
    /// en verde por omisión.
    @Test("las 8 celdas del dominio están decididas y solo `.backend` crea algo")
    func fullDomain_isExhaustive() {
        var creating = 0
        for flagOn in [false, true] {
            for hasSession in [false, true] {
                for consent in [false, true] {
                    let route = GroupCreateRoutingLogic.route(
                        flagOn: flagOn, hasSession: hasSession, consentAccepted: consent)
                    if route == .backend { creating += 1 }
                    if !flagOn { #expect(route == .channelOff) }
                }
            }
        }
        #expect(creating == 1, "solo (ON, sesión, consent) puede crear; encontrado: \(creating)")
    }
}

// MARK: -

/// **C4 · lo que la tabla de arriba NO puede fijar: QUIÉN llama y en qué ORDEN.**
///
/// `route` es pura y recibe `flagOn` ya leído, así que puede estar perfecta y con sus 7 tests en verde
/// mientras el call-site mide un snapshot de hasta 6 h — que es *exactamente* el caso del bug
/// (`refreshIfDue` tiene min-interval de 6 h y el arranque ya gastó la ventana con su refresh
/// fire-and-forget). Molde: `GroupsOrganizerBranchTests` (§«MUTACIÓN (a)») y `AttestWiringTests`.
///
/// El scan lee el CÓDIGO sin líneas de comentario: los docblocks de esta rama nombran a propósito lo que
/// prohíben, y contar la prosa haría que documentar el invariante lo «cumpliera».
@Suite("C4 · cableado del gate de creación (source-scan)")
struct GroupCreateRoutingWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let containerView = "Yala/App/Views/Groups/GroupsContainerView.swift"
    private static let routingLogic = "Yala/App/Logic/GroupCreateRoutingLogic.swift"

    // MARK: - El orden: force ANTES de leer el flag

    @Test("MUTACIÓN (a): el gate de creación refresca el remote-config con `force: true`")
    func gateRefreshesWithForce() throws {
        let code = try Self.code(Self.containerView)
        #expect(code.contains("refreshIfDue(force: true)"), """
            sin el `force`, `refreshIfDue` es un NO-OP en el caso exacto del bug: el min-interval es de 6 h
            y el arranque ya gastó la ventana con su propio refresh fire-and-forget. Las cuatro entradas
            medirían el flag stale y el usuario acabaría con un grupo local irrecuperable.
            """)
        #expect(!code.contains("refreshIfDue()"),
                "un `refreshIfDue()` sin argumentos aquí es el no-op que el chip prohíbe")
    }

    @Test("MUTACIÓN (b): el flag se lee DESPUÉS del refresh forzado")
    func flagIsReadAfterTheForcedRefresh() throws {
        let code = try Self.code(Self.containerView)
        let refresh = try #require(code.range(of: "refreshIfDue(force: true)"))
        let route = try #require(code.range(of: "GroupCreateRoutingLogic.route("))
        #expect(refresh.upperBound < route.lowerBound, """
            leer `groupsBackendEnabled` ANTES del refresh mide el snapshot viejo, que es justamente lo que
            el `force` existe para invalidar.
            """)
    }

    // MARK: - El choke-point: las CUATRO entradas pasan por él

    @Test("MUTACIÓN (c): las cuatro entradas de creación pasan por `requestCreateGroup`")
    func allFourEntryPointsGoThroughTheGate() throws {
        let code = try Self.code(Self.containerView)

        // Empty state, FAB simple, FAB expandible y el `pendingNewGroupForm` del Welcome. El conteo
        // esperado es lo que impide que una entrada nueva se cuelgue del form sin pasar por el gate —
        // y lo que hace caer este test si alguien borra una llamada en vez de re-cablearla.
        let calls = code.components(separatedBy: "await requestCreateGroup()").count - 1
        #expect(calls == 4, "se esperaban 4 entradas por el choke-point, encontradas: \(calls)")

        // El gate es el ÚNICO que decide en esta vista: nadie puede leer la tabla por su cuenta y
        // saltarse el refresh forzado.
        let decisions = code.components(separatedBy: "GroupCreateRoutingLogic.route(").count - 1
        #expect(decisions == 1, """
            `GroupCreateRoutingLogic.route(` debe aparecer UNA vez en esta vista (dentro de
            `requestCreateGroup`); encontradas: \(decisions). Una segunda decisión es una entrada que se
            salta el `force`.
            """)
    }

    // MARK: - Contrato de salida: la fábrica está cerrada

    @Test("MUTACIÓN (d): la rama `.cloudKit` no existe en la tabla de routing")
    func cloudKitRouteIsGone() throws {
        let code = try Self.code(Self.routingLogic)
        #expect(!code.contains("case cloudKit"), """
            `.cloudKit` era la fábrica: acuñaba un `SplitGroup` con `isBackendGroup == false`, y eso no
            tiene vuelta atrás (sin `migrate_group`, sin `fetchCandidates`, sin escritor de
            `movedToBackendAt` y con `createShareLink` fallando siempre).
            """)
        #expect(code.contains("case channelOff"),
                "el caso que sustituye a `.cloudKit` tiene que existir y llamarse por su hecho")
    }

    @Test("MUTACIÓN (e): ningún camino de producción construye un `SplitGroup` fuera del canal backend")
    func splitGroupHasNoLegacyProducerInProduction() throws {
        // `DevSeedGroups.swift` está ENTERO bajo `#if DEBUG` y sí crea grupos legacy hoy: pasa a
        // `isBackendGroup: true` en C3 (arrastra 22 XCUITest y va en SU commit), no aquí.
        let allowed: Set<String> = [
            "GroupBackendMembershipService.swift",   // RPC server-first, isBackendGroup = true
            "GroupsSyncClient.swift",                // born-remote del pull, isBackendGroup = true
            "DevSeedGroups.swift"                    // #if DEBUG — C3
        ]

        let root = Self.repoRoot.appendingPathComponent("Yala")
        var producers: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let stripped = body
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if stripped.contains("SplitGroup(") && !allowed.contains(url.lastPathComponent) {
                producers.append(url.lastPathComponent)
            }
        }

        #expect(producers.isEmpty, """
            un `SplitGroup` construido fuera del canal backend nace con `isBackendGroup == false` (el
            default del modelo) y es irrecuperable. Productores no autorizados: \(producers)
            """)
    }

    @Test("MUTACIÓN (f): `GroupService.createGroup` no vuelve — la creación local no tiene camino")
    func groupServiceCreateGroupStaysDead() throws {
        let code = try Self.code("Yala/Services/Groups/GroupService.swift")
        #expect(!code.contains("func createGroup("), """
            resucitar `GroupService.createGroup` reabre la fábrica entera: es el único sitio del repo que
            insertaba un `SplitGroup` legacy con su `SplitMember` admin. La creación vive en
            `GroupBackendMembershipService.createGroup`.
            """)
    }
}
