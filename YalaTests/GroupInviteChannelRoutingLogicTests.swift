//
//  GroupInviteChannelRoutingLogicTests.swift
//  YalaTests
//
//  Tabla de `GroupInviteChannelRoutingLogic.route` + el PIN estructural del hallazgo que obliga al
//  orden de evaluación en `AppBootstrapper.handleInviteLink` (device, 2026-07-31).
//
//  Este fichero existe por dos cosas distintas y las dos importan:
//   1. La tabla del enrutado (4 filas × la fila de control del canal viejo).
//   2. `extractShareURL_acceptsBackendLink_…`, que es el test que de verdad protege contra la
//      regresión: mientras `extractShareURL` acepte un link backend, evaluar el parser backend
//      DESPUÉS de él enruta el invite al canal equivocado en silencio. Si algún día ese parser se
//      endurece para rechazar los links backend, ese test se pondrá rojo — y ese rojo es la señal
//      de que el orden ya no es crítico, no un test que haya que "arreglar".
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupInviteChannelRoutingLogicTests {

    private typealias L = GroupInviteChannelRoutingLogic

    // MARK: - Tabla del enrutado

    @Test func backendLink_flagOn_routesToBackend() {
        #expect(L.route(isBackendLink: true, flagEnabled: true, didRefreshFlags: false) == .backend)
        // Con el canal encendido, `didRefreshFlags` es irrelevante.
        #expect(L.route(isBackendLink: true, flagEnabled: true, didRefreshFlags: true) == .backend)
    }

    /// **La fila del bug.** Antes del fix, este caso caía al camino CKShare y moría sin UI. Si esta
    /// aserción vuelve a `.ckShare` (o a cualquier cosa que no reintente), el 401/silencio del
    /// 2026-07-31 está de vuelta: el invitado cuyo snapshot de remote-config es más viejo que el
    /// último `GROUPS_BACKEND_ROLLOUT_PERCENT` pierde la invitación durante horas.
    @Test func backendLink_flagOff_notYetRefreshed_forcesRefreshAndRetries() {
        #expect(L.route(isBackendLink: true, flagEnabled: false, didRefreshFlags: false)
                == .refreshFlagsThenRetry)
    }

    /// Kill-switch bajado a propósito, o un percent que de verdad excluye a este device: se le DICE
    /// al usuario. Un enlace que abre la app y no hace nada es el peor resultado posible.
    @Test func backendLink_flagOff_alreadyRefreshed_informsUser() {
        #expect(L.route(isBackendLink: true, flagEnabled: false, didRefreshFlags: true)
                == .backendUnavailable)
    }

    /// Anti-bucle: `.refreshFlagsThenRetry` NO puede ser un punto fijo. La continuación entra con
    /// `didRefreshFlags: true` y tiene que salir por otra rama, gane o pierda el refresh.
    @Test func refreshRetry_isNotAFixedPoint() {
        let first = L.route(isBackendLink: true, flagEnabled: false, didRefreshFlags: false)
        #expect(first == .refreshFlagsThenRetry)
        for flagAfterRefresh in [true, false] {
            let second = L.route(
                isBackendLink: true, flagEnabled: flagAfterRefresh, didRefreshFlags: true)
            #expect(second != .refreshFlagsThenRetry)
        }
    }

    /// Control del canal VIEJO: un link no-backend va a CKShare con el flag como esté y con
    /// `didRefreshFlags` como esté. Es lo que mantiene intacto el camino de los grupos no migrados.
    @Test func nonBackendLink_alwaysRoutesToCKShare() {
        for flag in [true, false] {
            for refreshed in [true, false] {
                #expect(L.route(isBackendLink: false, flagEnabled: flag, didRefreshFlags: refreshed)
                        == .ckShare)
            }
        }
    }

    // MARK: - PIN del hallazgo: `extractShareURL` ACEPTA un link backend

    /// El invariante de ORDEN, medido y no supuesto. `buildBackendInviteURL` mete en `s` el
    /// base64URL de `https://yala-app.pe/invite?g=..&t=..` (forma mínima self-referential que el
    /// AASA exige), y `extractShareURL` decodifica `s` → `URL(string:)` NO falla → el guard
    /// host/path valida el URL EXTERIOR, que es un invite legítimo ⇒ **devuelve una URL, no `nil`**.
    ///
    /// Consecuencia que costó el silencio en device: un link backend evaluado después de
    /// `extractShareURL` NO cae al `guard else` que avisa al usuario — se cuela al canal CKShare
    /// disfrazado (warm: `fetchShareMetadata` le pide a CloudKit metadata de `yala-app.pe`; cold: se
    /// PERSISTE en `PendingInviteStore` y se re-emite en cada foreground). Cero UI en ambos.
    @Test func extractShareURL_acceptsBackendLink_soParserOrderIsTheInvariant() {
        let group = SplitGroup(name: "Viaje", iconName: "airplane", colorHex: "#112233", currencyCode: "PEN")
        let backendLink = InviteLinkService.buildBackendInviteURL(
            groupID: group.cloudKitZoneID, token: "tok01",
            group: group, members: [], inviterName: "Alice")
        #expect(backendLink != nil)
        guard let backendLink else { return }

        // El link ES backend…
        #expect(InviteLinkService.extractBackendInvite(from: backendLink) != nil)

        // …y AUN ASÍ `extractShareURL` lo acepta. Esta es la línea que justifica el orden.
        let masquerading = InviteLinkService.extractShareURL(from: backendLink)
        #expect(masquerading != nil, """
            Si esto pasa a nil, `extractShareURL` empezó a rechazar links backend y el orden de \
            evaluación de handleInviteLink dejó de ser crítico. Revisa el fix, no este test.
            """)
        // Y lo que devuelve NO es un CKShare: es el propio host de invites.
        #expect(masquerading?.host == InviteLinkService.host)
    }

    /// Discriminante del anterior: un link CKShare de verdad decodifica a `icloud.com`. Sin esta
    /// fila, la aserción de arriba pasaría también con un parser que devolviera cualquier cosa.
    @Test func extractShareURL_realCKShareLink_decodesToICloudHost() {
        let share = "https://www.icloud.com/share/0ABCdef"
        let encoded = Data(share.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let url = URL(string: "https://yala-app.pe/invite?s=\(encoded)")!

        #expect(InviteLinkService.extractBackendInvite(from: url) == nil)
        #expect(InviteLinkService.extractShareURL(from: url)?.host == "www.icloud.com")
    }

    /// El enrutado se decide con el parser SIN gatear por el flag: un link backend sigue siendo un
    /// link backend con el canal apagado. Es la premisa de `.refreshFlagsThenRetry` — «recibir un
    /// link backend es evidencia de que el canal está encendido».
    @Test func backendParser_isIndependentOfTheFlag() {
        let url = URL(string: "https://yala-app.pe/invite?g=SplitGroup-A&t=tok01")!
        for flag in [true, false] {
            CloudSyncFlags.groupsBackendEnabled = flag
            #expect(InviteLinkService.extractBackendInvite(from: url) != nil)
        }
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()
    }
}

// MARK: - Source-scan del CALL-SITE

/// **La tabla de arriba NO caza la regresión que causó el incidente.** El bug no estaba en una
/// decisión mal calculada: estaba en QUIÉN se preguntaba primero. Con `extractShareURL` evaluado
/// antes del parser backend, `route` puede ser perfecta y los 8 tests de arriba verdes mientras el
/// invite se cuela al canal CKShare — porque `route` nunca llega a llamarse con `isBackendLink: true`.
///
/// Molde `AttestWiringTests`: un scan del FUENTE es la única forma de pinnear un invariante de orden
/// que ningún test funcional puede ejercer (`handleInviteLink` warm dispara red y CloudKit reales).
@Suite("Invite links · el orden de evaluación del call-site")
struct GroupInviteChannelRoutingWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func bootstrapperSource() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Yala/App/AppBootstrapper.swift"),
            encoding: .utf8)
    }

    /// Cuerpo de la función de enrutado, delimitado por la declaración siguiente. Se acota a la
    /// FUNCIÓN y no al fichero a propósito: un scan de orden textual global daría rojo espurio si
    /// alguien reordena los helpers privados sin cambiar nada de la semántica.
    private static func routingFunctionBody(in source: String) -> String? {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: {
            $0.contains("func handleInviteLink(_ url: URL, didRefreshFlags:")
        }) else { return nil }
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex(where: { $0.hasPrefix("    private func ") || $0.hasPrefix("    func ") })
            ?? lines.endIndex
        return lines[start..<end].joined(separator: "\n")
    }

    /// **El invariante, en su forma semántica.** El enrutado pregunta por el parser BACKEND y delega
    /// el canal viejo; `extractShareURL` no puede aparecer en su cuerpo. Si alguien vuelve a inlinear
    /// ahí el `guard let shareURL = …`, el link backend lo satisface (ver
    /// `extractShareURL_acceptsBackendLink_…`) y vuelve a colarse al canal CKShare en silencio.
    @Test func theRoutingFunctionAsksTheBackendParser_andDelegatesTheCKSharePath() throws {
        let source = try Self.bootstrapperSource()
        guard let body = Self.routingFunctionBody(in: source) else {
            Issue.record("No se encontró `handleInviteLink(_:didRefreshFlags:)` en AppBootstrapper.")
            return
        }
        #expect(body.contains("InviteLinkService.extractBackendInvite"),
                "El enrutado dejó de preguntar por el parser backend.")
        #expect(!body.contains("InviteLinkService.extractShareURL"), """
            `extractShareURL` volvió al cuerpo del enrutado. Ese parser ACEPTA un link backend (su \
            `s` decodifica a una URL válida y el guard valida el URL exterior), así que evaluarlo \
            junto al enrutado manda los invites del canal nuevo al canal CKShare sin una sola línea \
            de UI. Es el bug del 2026-07-31 exactamente. Déjalo en `processCKShareInviteLink`.
            """)
    }

    /// La otra mitad: preguntar primero no sirve si se pregunta DETRÁS del flag. Era la forma literal
    /// del bug (`if CloudSyncFlags.groupsBackendEnabled, let backendInvite = …extractBackendInvite`).
    @Test func backendParserIsNotGatedByTheFlag() throws {
        let source = try Self.bootstrapperSource()
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let callIndex = lines.firstIndex(where: { $0.contains("InviteLinkService.extractBackendInvite") })
        else {
            Issue.record("No hay ninguna llamada a extractBackendInvite en AppBootstrapper.")
            return
        }
        // La condición compuesta del bug ponía el flag en la línea inmediatamente anterior.
        let window = lines[max(0, callIndex - 3)...callIndex].joined(separator: "\n")
        #expect(!window.contains("groupsBackendEnabled"), """
            El parser backend volvió a quedar detrás de `groupsBackendEnabled`. Con el flag OFF el \
            link no se reconoce como backend y termina en el canal CKShare. El flag decide QUÉ hacer \
            (GroupInviteChannelRoutingLogic.route), no SI se mira el link.
            """)
    }

    /// El enrutado pasa por la lógica pura (si alguien vuelve a inlinear la decisión, la tabla de
    /// arriba deja de gobernar nada).
    @Test func routingGoesThroughThePureLogic() throws {
        let source = try Self.bootstrapperSource()
        #expect(source.contains("GroupInviteChannelRoutingLogic.route"),
                "El enrutado del invite ya no consume la lógica pura.")
    }

    /// `force: true` es lo que hace útil el refresh: sin él `refreshIfDue` es un no-op en el caso
    /// EXACTO del bug (snapshot de menos de 6 h). Un mutante que lo baje a `false` deja el fix
    /// cosmético — la app pediría el config, no lo traería, y el invitado seguiría fuera.
    @Test func theRemoteConfigRefreshBypassesTheMinInterval() throws {
        let source = try Self.bootstrapperSource()
        #expect(source.contains("refreshIfDue(force: true)"), """
            El refresh del remote-config en el camino del invite perdió `force: true`. Sin él \
            `RemoteFlagDecisionLogic.shouldRefresh` corta por el min-interval de 6 h, que es \
            precisamente la condición del bug.
            """)
    }
}
