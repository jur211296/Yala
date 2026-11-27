//
//  CompartidoInvitarYEntradaLogicTests.swift
//  YalaTests
//
//  Lote 3 de Compartido (26-nov-2026): invitar a una persona y entrar sin grupo. Lógica pura: el nombre de la persona
//  nueva, la puerta (la misma de «Nuevo grupo»), la persona que ya existe, qué vacío enseña la vista completa, qué hace
//  «Nuevo gasto» sin nadie con quien apuntar, la persona recién añadida en la lista y la marca `k=p` del enlace.
//

import Foundation
import Testing
@testable import Yala

@Suite("Compartido · invitar a una persona y entrar sin grupo")
@MainActor
struct CompartidoInvitarYEntradaLogicTests {

    // MARK: Nombre y puerta

    @Test func cleanName_trimsAndCaps_andEmptyIsNil() {
        #expect(CompartidoPersonaAltaLogic.cleanName("  Marta  ") == "Marta")
        #expect(CompartidoPersonaAltaLogic.cleanName("   ") == nil)
        #expect(CompartidoPersonaAltaLogic.cleanName("") == nil)
        let long = String(repeating: "a", count: 200)
        #expect(CompartidoPersonaAltaLogic.cleanName(long)?.count == CompartidoPersonaAltaLogic.maxNameLength)
    }

    /// La cuenta se pide al crear la persona, con la MISMA precedencia que «Nuevo grupo»: lo anunciado y lo pedido no
    /// pueden divergir.
    @Test(arguments: [false, true], [false, true])
    func route_isTheSameAsCreatingAGroup(hasSession: Bool, consent: Bool) {
        for flag in [false, true] {
            #expect(CompartidoPersonaAltaLogic.route(flagOn: flag, hasSession: hasSession, consentAccepted: consent)
                    == GroupCreateRoutingLogic.route(flagOn: flag, hasSession: hasSession, consentAccepted: consent))
        }
        #expect(CompartidoPersonaAltaLogic.route(flagOn: true, hasSession: false, consentAccepted: consent) == .needsSignIn)
    }

    @Test func colorHex_isStablePerName_andFromThePalette() {
        let first = CompartidoPersonaAltaLogic.colorHex(for: "Marta")
        #expect(first == CompartidoPersonaAltaLogic.colorHex(for: "marta"))
        #expect(CompartidoPersonaAltaLogic.palette.contains(first))
        #expect(CompartidoPersonaAltaLogic.palette.contains(CompartidoPersonaAltaLogic.colorHex(for: "Ñandú Pérez")))
    }

    /// Escribir «marta» con Marta ya en la lista elige a Marta: no se crea otra. Un GRUPO con ese nombre no cuenta.
    @Test func existingPerson_matchesIgnoringCaseAndAccents_onlyAmongPeople() {
        let marta = UUID(), grupo = UUID()
        let known = [(id: grupo, name: "Marta", isPerson: false), (id: marta, name: "Márta ", isPerson: true)]
        #expect(CompartidoPersonaAltaLogic.existingPerson(named: "marta", among: known) == marta)
        #expect(CompartidoPersonaAltaLogic.existingPerson(named: "Beto", among: known) == nil)
        #expect(CompartidoPersonaAltaLogic.existingPerson(
            named: "Marta", among: [(id: grupo, name: "Marta", isPerson: false)]) == nil)
    }

    // MARK: Entrada sin grupo obligatorio

    @Test func fullView_inEveryEmptyStateOnTheWayToTheFirstOne() {
        for kind in [GroupsEmptyStateLogic.Kind.standard, .needsEducational, .createAccount, .needsConsent] {
            #expect(CompartidoEntradaLogic.showsFullView(kind: kind, flagOn: true, joinOnTheWay: false), "\(kind)")
        }
    }

    /// Las tres excepciones: «vuelve a entrar» (sus grupos ya existen), una unión en curso y el canal apagado.
    @Test func fullView_notForSignInToView_norAJoinOnTheWay_norTheChannelOff() {
        #expect(!CompartidoEntradaLogic.showsFullView(kind: .signInToView, flagOn: true, joinOnTheWay: false))
        #expect(!CompartidoEntradaLogic.showsFullView(kind: .standard, flagOn: true, joinOnTheWay: true))
        #expect(!CompartidoEntradaLogic.showsFullView(kind: .standard, flagOn: false, joinOnTheWay: false))
    }

    @Test func newExpense_withNobody_asksWho() {
        #expect(CompartidoEntradaLogic.start(eligibleCount: 0) == .askWho)
        #expect(CompartidoEntradaLogic.start(eligibleCount: 1) == .direct)
        #expect(CompartidoEntradaLogic.start(eligibleCount: 4) == .pick)
    }

    /// El botón del vacío del chip Grupos conserva el id de la tarjeta de cada estado: lleva al mismo sitio.
    @Test func groupsCardIdentifier_keepsTheStepCardIDs() {
        #expect(CompartidoEntradaLogic.groupsCardIdentifier(kind: .standard) == "groups_empty_state")
        #expect(CompartidoEntradaLogic.groupsCardIdentifier(kind: .createAccount) == "groups_empty_state_create_account")
        #expect(CompartidoEntradaLogic.groupsCardIdentifier(kind: .needsConsent) == "groups_empty_state_consent")
        #expect(CompartidoEntradaLogic.groupsCardIdentifier(kind: .needsEducational) == "groups_empty_state_educational")
    }

    // MARK: La persona pendiente de la cuenta

    @Test func pendingPerson_isFreshForTenMinutes_only() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        #expect(CompartidoPersonFlowLogic.isFresh(createdAt: start, now: start.addingTimeInterval(9 * 60)))
        #expect(!CompartidoPersonFlowLogic.isFresh(createdAt: start, now: start.addingTimeInterval(11 * 60)))
        // Un reloj que retrocede no la da por buena.
        #expect(!CompartidoPersonFlowLogic.isFresh(createdAt: start, now: start.addingTimeInterval(-60)))
    }

    @Test func pendingPerson_isConsumedOnce() {
        let flow = CompartidoPersonFlowState()
        let now = Date()
        flow.waitForIdentity(name: "Marta", purpose: .newExpense, now: now)
        #expect(flow.takePendingIfFresh(now: now.addingTimeInterval(30))?.name == "Marta")
        #expect(flow.takePendingIfFresh(now: now.addingTimeInterval(31)) == nil)
    }

    @Test func pendingPerson_stale_isDropped() {
        let flow = CompartidoPersonFlowState()
        let now = Date()
        flow.waitForIdentity(name: "Marta", purpose: .invite, now: now)
        #expect(flow.takePendingIfFresh(now: now.addingTimeInterval(3_600)) == nil)
        #expect(flow.pendingAfterIdentity == nil)
    }

    // MARK: La persona recién añadida sale en Personas

    private func input(
        _ key: String, isPerson: Bool, members: [(String, String)], debts: [Debt] = [], interacted: Set<String> = []
    ) -> CompartidoPersonasLogic.GroupInput {
        CompartidoPersonasLogic.GroupInput(
            groupKey: key, groupName: key, isPerson: isPerson,
            members: [.init(id: "yo", name: "Yo", accountKey: "u:yo")]
                + members.map { .init(id: $0.0, name: $0.1, accountKey: nil) },
            myMemberIDs: ["yo"], debts: debts, interactedMemberIDs: interacted)
    }

    @Test func justAddedPerson_withoutExpenses_showsAtTheEndOfTheActiveOnes() {
        let result = CompartidoPersonasLogic.people(from: [
            input("viaje", isPerson: false, members: [("b", "Beto")],
                  debts: [Debt(fromMemberID: "b", toMemberID: "yo", amount: 20, currencyCode: "PEN")], interacted: ["b"]),
            input("marta", isPerson: true, members: [("m", "Marta")]),
        ], noGroupLabel: "Sin grupo")
        #expect(result.active.map(\.name) == ["Beto", "Marta"])
        #expect(result.active.last?.netByCurrency.isEmpty == true)
        #expect(result.settled.isEmpty)
    }

    /// Un miembro de un GRUPO sin gastos conmigo sigue sin salir (lo de antes no cambia).
    @Test func memberOfAGroup_withoutInteractions_stillHidden() {
        let result = CompartidoPersonasLogic.people(from: [input("viaje", isPerson: false, members: [("c", "Caro")])])
        #expect(result.isEmpty)
    }

    // MARK: El enlace de una persona

    @Test func inviteLink_ofAPerson_carriesTheMark_andTheLinkReadsIt() throws {
        let person = SplitGroup(name: "Marta", iconName: "person.fill", colorHex: "#14B8A6", currencyCode: "PEN")
        person.isPerson = true
        let url = try #require(InviteLinkService.buildBackendInviteURL(
            groupID: person.cloudKitZoneID, token: "tok123", group: person, members: [], inviterName: "Jürgen"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "k" }?.value == "p")
        let meta = InviteLinkService.extractMetadata(from: url)
        #expect(meta.isPerson == true)
        #expect(meta.name == "Marta")
        #expect(meta.inviter == "Jürgen")
        // El enlace sigue siendo una invitación de backend que se sabe leer.
        #expect(InviteLinkService.extractBackendInvite(from: url)?.token == "tok123")
    }

    @Test func inviteLink_ofAGroup_hasNoMark() throws {
        let group = SplitGroup(name: "Viaje", iconName: "airplane", colorHex: "#8B5CF6", currencyCode: "PEN")
        let url = try #require(InviteLinkService.buildBackendInviteURL(
            groupID: group.cloudKitZoneID, token: "tok", group: group, members: [], inviterName: "Jürgen"))
        #expect(!(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).contains { $0.name == "k" })
        #expect(InviteLinkService.extractMetadata(from: url).isPerson == nil)
    }

    // MARK: Textos en los 16 idiomas

    static let lote3Keys = [
        "who.title", "who.personSubtitle", "who.writeName", "who.namePlaceholder", "who.add", "who.hint",
        "addPerson.message", "empty.groups.title", "empty.groups.message", "empty.groups.action", "empty.people.title",
        "empty.people.message", "empty.people.action", "added.title", "added.message", "share.message",
        "share.messageNoInviter", "invite.cardTitle", "invite.cardTitleNoName", "invite.cardSubtitle", "invite.message",
        "invite.join", "invite.readyTitle", "invite.readyTitleNoName", "invite.readyMessage", "needed.withPerson",
        "needed.message",
    ]

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl", "pt-BR",
                          "pt-PT", "pt", "zh-Hans"]

    /// Cada clave del lote en los 16 idiomas, con texto propio (no la clave cruda) y los mismos huecos `%@` que el
    /// español. El inglés no puede ser una copia del español.
    @Test func everyKey_inEveryLocale_withTheSamePlaceholders() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Yala/Resources")
        func table(_ locale: String) throws -> [String: String] {
            let url = root.appendingPathComponent("\(locale).lproj/Compartido.strings")
            return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
        }
        let spanish = try table("es-419")
        let english = try table("en")
        for locale in Self.locales {
            let t = try table(locale)
            for key in Self.lote3Keys.map({ "compartido.\($0)" }) {
                let value = try #require(t[key], "\(locale) sin \(key)")
                #expect(!value.isEmpty && value != key, "\(locale) \(key)")
                let es = spanish[key] ?? ""
                #expect(value.components(separatedBy: "%@").count == es.components(separatedBy: "%@").count,
                        "\(locale) \(key) cambia los huecos")
            }
        }
        #expect(english["compartido.invite.message"] != spanish["compartido.invite.message"])
    }
}
