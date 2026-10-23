//
//  UXAudit22Decidido14Tests.swift
//  YalaTests
//
//  Lote decidido 2.2 · 14 (Grupos: invitar, la web de invitación, unirse, aprobar solicitudes y avisos). Tres mitades:
//  la lógica pura de cada card (tablas), el manejador de invitaciones con la tarjeta del grupo delante de la cuenta
//  (L12-17, el cambio de orden que más puede romper) y el cableado de las vistas (source-scan).
//

import Foundation
import Testing
import UserNotifications

@testable import Yala

// MARK: - Lógica pura

@MainActor
@Suite("Lote decidido 2.2 · 14 · lógica pura")
struct UXAudit22Decidido14LogicTests {

    // L12-8

    @Test func notificationsOptIn_state_table() {
        typealias L = GroupNotificationsOptInLogic
        #expect(L.state(itemActive: true, authorization: .authorized) == .enabled)
        #expect(L.state(itemActive: true, authorization: .provisional) == .enabled)
        #expect(L.state(itemActive: false, authorization: .authorized) == .ask, "el aviso de Yala apagado también falta")
        #expect(L.state(itemActive: true, authorization: .notDetermined) == .ask)
        #expect(L.state(itemActive: false, authorization: .notDetermined) == .ask)
        #expect(L.state(itemActive: true, authorization: .denied) == .denied, "con iOS en no, solo queda Ajustes")
        #expect(L.state(itemActive: false, authorization: .denied) == .denied)
    }

    /// A quien ya tiene los avisos no se le pregunta nada; a quien le falta algo, sí.
    @Test func notificationsOptIn_showsCardOnlyWhenSomethingIsMissing() {
        #expect(!GroupNotificationsOptInLogic.showsCard(initialState: .enabled))
        #expect(GroupNotificationsOptInLogic.showsCard(initialState: .ask))
        #expect(GroupNotificationsOptInLogic.showsCard(initialState: .denied))
    }

    // L12-14

    @Test func shareMessage_carriesTheInviterTheGroupTheInstructionAndTheLinkLast() throws {
        let url = try #require(URL(string: "https://yala-app.pe/invite?g=G1&t=tok"))
        let text = GroupInviteShareMessage.text(
            inviterName: "Lucía", defaultName: "Usuario", groupName: "Depa Miraflores", url: url)
        #expect(text == L10n.UXD14.shareMessage(inviter: "Lucía", group: "Depa Miraflores") + "\n" + url.absoluteString)
        #expect(text.hasSuffix("\n" + url.absoluteString), "el enlace tiene que ir en su propia línea, al final")
    }

    /// Sin nombre propio (vacío, espacios o el «Usuario» por defecto) no se firma con un nombre que no es de nadie.
    @Test func shareMessage_withoutARealName_usesTheNeutralLine() throws {
        let url = try #require(URL(string: "https://yala-app.pe/invite?g=G1&t=tok"))
        let neutral = L10n.UXD14.shareMessageNoInviter(group: "Depa") + "\n" + url.absoluteString
        for name in [nil, "", "   ", "Usuario"] as [String?] {
            #expect(GroupInviteShareMessage.text(inviterName: name, defaultName: "Usuario", groupName: "Depa", url: url)
                    == neutral, "nombre «\(name ?? "nil")»")
        }
    }

    // L12-16

    @Test func linkExtraction_findsTheLinkInsideAWholeWhatsAppMessage() {
        let link = "https://yala-app.pe/invite?g=11111111-2222-3333-4444-555555555555&t=tok&n=Depa"
        let message = "Lucía te invita a «Depa» en Yala para dividir los gastos. Toca el enlace para entrar; si no tienes "
            + "Yala, descárgala y vuelve a tocarlo.\n\(link)"
        #expect(InviteLinkTextExtraction.firstInviteLink(in: message)?.absoluteString == link)
    }

    @Test func linkExtraction_stripsSurroundingPunctuation() {
        let link = "https://yala-app.pe/invite?g=G1&t=tok"
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "Entra aquí: \(link).")?.absoluteString == link)
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "(\(link))")?.absoluteString == link)
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "«\(link)»")?.absoluteString == link)
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "  \(link)  ")?.absoluteString == link)
    }

    @Test func linkExtraction_acceptsTheAppScheme_andRejectsWhatIsNotAYalaInvite() {
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "yala://invite?g=G1&t=tok") != nil)
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "Mira https://example.com/invite?g=G1&t=tok") == nil)
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "https://yala-app.pe/") == nil, "sin invitación dentro")
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "Hola, ¿vienes el sábado?") == nil)
        #expect(InviteLinkTextExtraction.firstInviteLink(in: "") == nil)
    }

    // L12-17

    @Test func groupFirst_showsTheCardOnlyWhileAccountOrConsentIsMissing() {
        typealias L = GroupInviteGroupFirstLogic
        func shows(_ s: Bool, _ c: Bool, confirmed: Bool = false, accepted: Bool = false, canPresent: Bool = true) -> Bool {
            L.showsGroupBeforeAccount(hasSession: s, isConsented: c, hasConfirmedInvite: confirmed,
                                      hasAcceptedGroupCard: accepted, canPresentOnboarding: canPresent)
        }
        #expect(shows(false, false), "sin cuenta: primero el grupo")
        #expect(shows(true, false), "sin consentimiento: primero el grupo")
        #expect(shows(false, true))
        #expect(!shows(true, true), "con los dos, la hoja de siempre decide (y es la misma tarjeta)")
        #expect(!shows(false, false, accepted: true), "ya dijo «Unirme» en la tarjeta: sigue a la cuenta")
        #expect(!shows(false, false, confirmed: true))
        #expect(!shows(false, false, canPresent: false), "el paso que viene del propio CTA no re-presenta la hoja")
    }

    @Test func groupFirst_joinTapRoute() {
        typealias L = GroupInviteGroupFirstLogic
        #expect(L.joinTapRoute(hasPendingZone: true, hasSession: false, isConsented: false) == .continueToAccount)
        #expect(L.joinTapRoute(hasPendingZone: true, hasSession: true, isConsented: false) == .continueToAccount)
        #expect(L.joinTapRoute(hasPendingZone: true, hasSession: true, isConsented: true) == .joinNow)
        #expect(L.joinTapRoute(hasPendingZone: false, hasSession: false, isConsented: false) == .joinNow,
                "sin invitación detrás (vista previa, XCUITest) no hay nada que apuntar")
    }

    @Test func groupFirst_joinsOnAppearOnlyAfterTheCardAndWithBothSteps() {
        typealias L = GroupInviteGroupFirstLogic
        let now = Date(timeIntervalSince1970: 1_000_000)
        let recent = now.addingTimeInterval(-60)
        #expect(L.joinsOnAppear(groupCardAcceptedAt: recent, hasSession: true, isConsented: true, now: now))
        #expect(!L.joinsOnAppear(groupCardAcceptedAt: nil, hasSession: true, isConsented: true, now: now),
                "sin el «Unirme» de la tarjeta, la persona todavía no dijo que sí")
        #expect(!L.joinsOnAppear(groupCardAcceptedAt: recent, hasSession: false, isConsented: true, now: now))
        #expect(!L.joinsOnAppear(groupCardAcceptedAt: recent, hasSession: true, isConsented: false, now: now))
    }

    /// La ventana del «Unirme» de la tarjeta, clavada con sus dos vecinos: pasado el rato (el consentimiento aceptado días
    /// después por otro camino), la tarjeta vuelve a preguntar en vez de unir sola.
    @Test func groupFirst_autoJoinWindow_isThirtyMinutes_andNotAFutureStamp() {
        typealias L = GroupInviteGroupFirstLogic
        let now = Date(timeIntervalSince1970: 1_000_000)
        func joins(_ ago: TimeInterval) -> Bool {
            L.joinsOnAppear(groupCardAcceptedAt: now.addingTimeInterval(-ago), hasSession: true, isConsented: true, now: now)
        }
        #expect(L.autoJoinWindow == 1_800)
        #expect(joins(1_799))
        #expect(!joins(1_800))
        #expect(!joins(3 * 86_400), "días después ya no une sola")
        #expect(!joins(-60), "un sello del futuro (reloj movido) no cuenta como reciente")
    }

    /// La tarjeta ya aceptada con la cuenta o el consentimiento pendientes no se vuelve a enseñar: sigue la cadena.
    @Test func groupFirst_acceptedCardSkipsTheSheetWhileTheChainIsPending() {
        typealias L = GroupInviteGroupFirstLogic
        #expect(L.skipsSheetToContinueChain(hasAcceptedGroupCard: true, hasSession: false, isConsented: false))
        #expect(L.skipsSheetToContinueChain(hasAcceptedGroupCard: true, hasSession: true, isConsented: false))
        #expect(!L.skipsSheetToContinueChain(hasAcceptedGroupCard: true, hasSession: true, isConsented: true),
                "con los dos hechos, la hoja tiene que salir: es la que une")
        #expect(!L.skipsSheetToContinueChain(hasAcceptedGroupCard: false, hasSession: false, isConsented: false),
                "sin aceptar, la tarjeta es justo lo que hay que enseñar")
    }

    // L12-20

    /// El genérico de membresía del servidor se reconoce por su clave; el resto de avisos, no.
    @Test func approvalNotice_recognisesOnlyTheServerMembershipNotice() {
        let generic: [AnyHashable: Any] = ["aps": ["alert": ["title-loc-key": "notifications.groups.name",
                                                             "loc-key": "notifications.groups.remoteMembershipUpdate"]],
                                           "yala": ["kind": "groups-sync"]]
        let activity: [AnyHashable: Any] = ["aps": ["alert": ["loc-key": "notifications.groups.remoteActivity"]]]
        let local: [AnyHashable: Any] = ["deepLink": "groups/123"]
        #expect(GroupApprovalNoticeLogic.isServerMembershipNotice(generic))
        #expect(!GroupApprovalNoticeLogic.isServerMembershipNotice(activity))
        #expect(!GroupApprovalNoticeLogic.isServerMembershipNotice(local))
    }

    /// Quién invita viaja en `u`, y una marca persistida antes de este cambio (sin la clave) sigue decodificando.
    @Test func brandedMetadata_readsTheInviter_andOldJSONStillDecodes() throws {
        let url = try #require(URL(string: "https://yala-app.pe/invite?g=G&t=T&n=Depa&m=Luc%C3%ADa,Ana&u=Luc%C3%ADa"))
        let meta = InviteLinkService.extractMetadata(from: url)
        #expect(meta.inviter == "Lucía")
        #expect(meta.name == "Depa")

        let old = Data(#"{"name":"Depa","icon":"house.fill","color":"E91E63","members":["Ana"]}"#.utf8)
        let decoded = try JSONDecoder().decode(InviteLinkService.BrandedMetadata.self, from: old)
        #expect(decoded.name == "Depa")
        #expect(decoded.inviter == nil)
    }

    // L12-19

    @Test func onTheWay_onlyWhileTheJoinIsStillAlive() {
        typealias L = GroupsJoinOnTheWayLogic
        #expect(L.showsOnTheWay(phase: .accepting))
        #expect(L.showsOnTheWay(phase: .waitingForZone))
        #expect(L.showsOnTheWay(phase: .creatingMember))
        #expect(L.showsOnTheWay(phase: .pendingApproval))
        #expect(L.showsOnTheWay(phase: .failed(.acceptFailed(recoverable: true))), "con reintento sigue en camino")
        #expect(L.showsOnTheWay(phase: .failed(.memberSaveFailed)))
        #expect(!L.showsOnTheWay(phase: .failed(.acceptFailed(recoverable: false))))
        #expect(!L.showsOnTheWay(phase: .failed(.expired)), "caducada: vuelve el estado vacío de siempre")
        #expect(!L.showsOnTheWay(phase: .idle))
        #expect(!L.showsOnTheWay(phase: .active))
    }

    // L19-1

    @Test func joinRequestsBanner_titleByCount_andOnlyForWhoCanReview() {
        typealias L = GroupJoinRequestsLogic
        #expect(L.bannerTitle(pendingNames: ["Carla"], canReview: true) == L10n.UXD14.requestsBannerOne("Carla"))
        #expect(L.bannerTitle(pendingNames: ["Carla", "Diego"], canReview: true) == L10n.UXD14.requestsBannerMany)
        #expect(L.bannerTitle(pendingNames: [], canReview: true) == nil)
        #expect(L.bannerTitle(pendingNames: ["Carla"], canReview: false) == nil, "quien no puede aceptar no ve el aviso")
    }

    @Test func requestOpened_todayYesterdayOrTheDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 18)))
        let earlierToday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 1)))
        let yesterday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 23)))
        let older = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 9)))
        #expect(L10n.UXD14.requestOpened(earlierToday, now: now, calendar: calendar) == L10n.UXD14.requestsOpenedToday)
        #expect(L10n.UXD14.requestOpened(yesterday, now: now, calendar: calendar) == L10n.UXD14.requestsOpenedYesterday)
        let olderText = L10n.UXD14.requestOpened(older, now: now, calendar: calendar)
        #expect(olderText != L10n.UXD14.requestsOpenedToday && olderText != L10n.UXD14.requestsOpenedYesterday)
        #expect(olderText.contains("12"))
    }
}

// MARK: - L12-17 · El manejador: la tarjeta del grupo antes de la cuenta

@MainActor
@Suite("Lote decidido 2.2 · 14 · la tarjeta del grupo va antes que la cuenta", .serialized)
struct UXAudit22Decidido14GroupFirstTests {

    final class JoinSpy { var calls = 0 }

    /// Molde de `GroupInviteSheetAlwaysShownTests.makeEnv`, con sesión y consentimiento como parámetros.
    private func makeEnv(_ spy: JoinSpy, session: Bool, consent: Bool) -> () -> Void {
        let suite = "test.groupfirst.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        PendingJoinStore.defaults = d
        let savedJoin = GroupBackendInviteEntryHandler.joinProvider
        let savedSession = GroupBackendInviteEntryHandler.hasSessionProvider
        let savedConsent = GroupBackendInviteEntryHandler.isConsentedProvider
        let savedProfile = GroupBackendInviteEntryHandler.profileNameProvider
        let savedReadiness = RouterEntryGate.shared.readinessProvider
        let savedMirror = GroupBackendInviteEntryHandler.mountAttachesMirrorProvider

        GroupBackendInviteEntryHandler.hasSessionProvider = { session }
        GroupBackendInviteEntryHandler.isConsentedProvider = { consent }
        GroupBackendInviteEntryHandler.profileNameProvider = { "Pia" }
        GroupBackendInviteEntryHandler.joinProvider = { _, _, _ in
            spy.calls += 1
            return JoinGroupResult(groupID: "G1", memberKey: "sub", status: "pendingApproval", rebound: false)
        }
        // El testigo del mount miente en el host de test (ver el molde): sin esto `drive` saldría por la puerta del
        // neutro antes de decidir.
        GroupBackendInviteEntryHandler.mountAttachesMirrorProvider = { false }
        RouterEntryGate.shared.readinessProvider = { (hasCompletedOnboarding: true, isBootstrapInitialized: true) }
        CloudSyncFlags.groupsBackendEnabled = true
        AppRouter.shared._testReset()
        GroupBackendInviteEntryHandler.clearInviteTapArms()
        GroupJoinIntentTracker.shared.clear()

        return {
            GroupBackendInviteEntryHandler.joinProvider = savedJoin
            GroupBackendInviteEntryHandler.hasSessionProvider = savedSession
            GroupBackendInviteEntryHandler.isConsentedProvider = savedConsent
            GroupBackendInviteEntryHandler.profileNameProvider = savedProfile
            GroupBackendInviteEntryHandler.mountAttachesMirrorProvider = savedMirror
            RouterEntryGate.shared.readinessProvider = savedReadiness
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            AppRouter.shared._testReset()
            PendingJoinStore.defaults = .standard
            d.removePersistentDomain(forName: suite)
            GroupBackendInviteEntryHandler.clearInviteTapArms()
            GroupJoinIntentTracker.shared.clear()
        }
    }

    private enum Presented: Equatable { case card, signIn, consent, other, nothing }

    private func presented() -> Presented {
        let queue = AppRouter.shared.queueSnapshot
        if queue.isEmpty { return .nothing }
        if queue.contains(where: { if case .presentGroupBackendInviteOnboarding = $0 { return true }; return false }) {
            return .card
        }
        if queue.contains(where: { if case .presentGroupsSignIn = $0 { return true }; return false }) { return .signIn }
        if queue.contains(where: { if case .presentGroupsConsent = $0 { return true }; return false }) { return .consent }
        return .other
    }

    /// EL CASO. Sin cuenta, el enlace enseña primero el grupo — antes, `drive` pedía el inicio de sesión de entrada.
    @Test func noSession_linkShowsTheGroupCardFirst() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy, session: false, consent: false); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: .universalLink)

        #expect(presented() == .card, "se pidió la cuenta antes de enseñar a qué grupo te unes")
        #expect(spy.calls == 0)
    }

    /// Con cuenta y sin consentimiento, también la tarjeta antes del consentimiento.
    @Test func sessionWithoutConsent_showsTheGroupCardBeforeTheConsent() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy, session: true, consent: false); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: .boot)

        #expect(presented() == .card)
    }

    /// Tras «Unirme» en la tarjeta, la cadena sigue a la cuenta y NO vuelve a enseñarla.
    @Test func afterTheCard_theChainGoesOnToSignIn() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy, session: false, consent: false); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        PendingJoinStore.markGroupCardAccepted(zoneName: "G1")
        await GroupBackendInviteEntryHandler.continueFlow(zoneName: "G1")

        #expect(presented() == .signIn)
        #expect(spy.calls == 0, "la tarjeta no confirma el join: une el toque de después, con su alta")
        #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == false)
    }

    /// Con cuenta y consentimiento ya hechos tras la tarjeta, vuelve la hoja (que une sola al aparecer) y todavía no se
    /// unió nadie.
    @Test func afterTheCardAndBothSteps_theSheetComesBackWithoutJoiningYet() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy, session: true, consent: true); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        PendingJoinStore.markGroupCardAccepted(zoneName: "G1")
        await GroupBackendInviteEntryHandler.continueFlow(zoneName: "G1")

        #expect(presented() == .card)
        #expect(spy.calls == 0)
    }

    /// Re-tocar el MISMO enlace mientras se hace la cuenta conserva el «sí» de la tarjeta; un enlace nuevo, no.
    @Test func groupCardMark_survivesTheSameLink_andDiesWithANewOne() {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy, session: false, consent: false); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        PendingJoinStore.markGroupCardAccepted(zoneName: "G1")
        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        #expect(PendingJoinStore.entry(zoneName: "G1")?.hasAcceptedGroupCard == true)

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "otro")
        #expect(PendingJoinStore.entry(zoneName: "G1")?.hasAcceptedGroupCard == false)
    }

    @Test func markGroupCardAccepted_isIdempotent_andWithoutEntryDoesNothing() {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy, session: false, consent: false); defer { cleanup() }

        PendingJoinStore.markGroupCardAccepted(zoneName: "nadie")
        #expect(PendingJoinStore.entry(zoneName: "nadie") == nil)

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        let first = Date(timeIntervalSince1970: 1_000)
        PendingJoinStore.markGroupCardAccepted(zoneName: "G1", at: first)
        PendingJoinStore.markGroupCardAccepted(zoneName: "G1", at: Date(timeIntervalSince1970: 2_000))
        #expect(PendingJoinStore.entry(zoneName: "G1")?.groupCardAcceptedAt == first)
    }
}

// MARK: - Cableado (source-scan)

@MainActor
@Suite("Lote decidido 2.2 · 14 · cableado")
struct UXAudit22Decidido14WiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// L12-8: el permiso se pide dentro de «está listo», «Ya estás en» y «Solicitud enviada», y la alerta suelta se fue.
    @Test func notificationsPermission_livesInsideTheScreensNotInALooseAlert() throws {
        let created = try Self.source("Yala/App/Views/Groups/GroupCreatedInviteSheet.swift")
        #expect(created.contains("GroupNotificationsOptInCard()"))
        let invite = try Self.source("Yala/App/Views/Groups/GroupInviteOnboardingView.swift")
        let completion = try #require(invite.components(separatedBy: "private var completionStep: some View {").dropFirst().first)
        #expect((completion.components(separatedBy: "// MARK:").first ?? "").contains("GroupNotificationsOptInCard()"))
        let pending = try #require(invite.components(separatedBy: "private var pendingApprovalStep: some View {").dropFirst().first)
        #expect((pending.components(separatedBy: "// MARK:").first ?? "").contains("GroupNotificationsOptInCard()"))

        let tab = try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(!tab.contains("L10n.Groups.Notifications.promptTitle"), "vuelve la alerta suelta de avisos")
        #expect(!tab.contains("showNotificationPrompt"))
    }

    /// L12-14: las tres salidas de compartir mandan el mensaje, no el enlace a secas.
    @Test func everyShareExit_sendsTheMessageWithTheLink() throws {
        for path in ["Yala/App/Views/Groups/GroupCreatedInviteSheet.swift",
                     "Yala/App/Views/Groups/GroupMembersView.swift",
                     "Yala/App/Views/Groups/GroupDetailView.swift"] {
            let src = try Self.source(path)
            #expect(src.contains("ActivityView(activityItems: [GroupInviteShareMessage.text("), "\(path) comparte el enlace solo")
            #expect(!src.contains("ActivityView(activityItems: [item.url]"), "\(path)")
            #expect(!src.contains("ActivityView(activityItems: [url]"), "\(path)")
        }
    }

    /// L12-17: la tarjeta va DELANTE de la puerta del neutro y del switch de `nextStep` dentro de `drive`.
    @Test func drive_asksForTheGroupCardBeforeTheNeutralGateAndTheAccount() throws {
        let handler = try Self.source("Yala/App/Services/GroupBackendInviteEntryHandler.swift")
        let drive = try #require(handler.components(separatedBy: "static func drive(groupID: String, token: String, source: Source) async {").dropFirst().first)
        let card = try #require(drive.range(of: "GroupInviteGroupFirstLogic.showsGroupBeforeAccount("))
        let neutral = try #require(drive.range(of: "neutralGateDecision(groupID: groupID) == .returnsToNeutral"))
        let next = try #require(drive.range(of: "GroupBackendInviteEntryLogic.nextStep("))
        #expect(card.lowerBound < neutral.lowerBound)
        #expect(card.lowerBound < next.lowerBound)
        #expect(drive.contains("canPresentOnboarding: source != .userAction && pendingEntry != nil"))
    }

    /// L12-17: el «Unirme» de la tarjeta sigue a la cuenta en el `onDismiss` del cover (con el ancla libre), y no marca
    /// el alta como hecha.
    @Test func groupCard_continuesTheChainOnDismiss_withoutCompletingOnboarding() throws {
        let content = try Self.source("Yala/App/ContentView.swift")
        let cover = try #require(content.components(separatedBy: ".fullScreenCover(isPresented: $showGroupInviteOnboarding, onDismiss: {").dropFirst().first)
        let onDismiss = cover.components(separatedBy: "}) {").first ?? ""
        #expect(onDismiss.contains("GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)"))
        #expect(cover.contains("case .continueToAccount:\n                        zoneAwaitingAccount = pendingInviteZone"))
    }

    /// L12-17: el drenado de la hoja pregunta lo mismo que `drive` antes de volver a enseñar una tarjeta ya aceptada.
    @Test func sheetDrain_continuesTheChainForAnAcceptedCard() throws {
        let content = try Self.source("Yala/App/ContentView.swift")
        let drain = try #require(content.components(separatedBy: "case .presentGroupBackendInviteOnboarding(let zone):").dropFirst().first)
        let skip = try #require(drain.range(of: "GroupInviteGroupFirstLogic.skipsSheetToContinueChain("))
        let present = try #require(drain.range(of: "showGroupInviteOnboarding = true"))
        #expect(skip.lowerBound < present.lowerBound)
        let between = String(drain[skip.lowerBound..<present.lowerBound])
        #expect(between.contains("GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)"))
    }

    /// L12-18: «Apuntar un gasto»/«Ver el grupo» se aplican en el `onDismiss` del cover, no con la hoja aún encima.
    @Test func readyFollowUps_applyAfterTheCoverIsGone() throws {
        let invite = try Self.source("Yala/App/Views/Groups/GroupInviteOnboardingView.swift")
        let finish = try #require(invite.components(separatedBy: "private func finishJoined(addExpense: Bool, group: SplitGroup?) {").dropFirst().first)
        let body = finish.components(separatedBy: "\n    }").first ?? ""
        #expect(body.contains("navigation.pendingInviteFollowUp ="))
        #expect(!body.contains("pendingNewGroupExpense = true"), "pedir el formulario con el cover aún encima")
        let content = try Self.source("Yala/App/ContentView.swift")
        let cover = try #require(content.components(separatedBy: ".fullScreenCover(isPresented: $showGroupInviteOnboarding, onDismiss: {").dropFirst().first)
        let onDismiss = cover.components(separatedBy: "}) {").first ?? ""
        #expect(onDismiss.contains("navigation.pendingNewGroupExpense = true"))
        #expect(onDismiss.contains("navigation.pendingGroupID = groupID.uuidString"))
    }

    /// L12-19: el estado «en camino» gana a los cinco estados vacíos y no ofrece crear.
    @Test func onTheWay_preemptsTheEmptyStates_withoutAnAction() throws {
        let tab = try Self.source("Yala/App/Views/Groups/GroupsContainerView.swift")
        let fn = try #require(tab.components(separatedBy: "private func emptyState(standardAccessibilityID: String?, hasArchivedGroups: Bool) -> some View {").dropFirst().first)
        let onTheWay = try #require(fn.range(of: "GroupsJoinOnTheWayLogic.showsOnTheWay(phase: GroupJoinIntentTracker.shared.phase)"))
        let switchKind = try #require(fn.range(of: "switch kind {"))
        #expect(onTheWay.lowerBound < switchKind.lowerBound)
        let branch = String(fn[onTheWay.lowerBound..<switchKind.lowerBound])
        #expect(branch.contains("actionTitle: nil"))
    }

    /// L12-20: la aprobación propia sale en el changeset en la MISMA rama que resetea el cursor del grupo.
    @Test func selfApproval_isCollectedWhereTheCursorIsReset() throws {
        let client = try Self.source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")
        let branch = try #require(client.components(separatedBy: "if priorStatus == SplitMemberStatus.pendingApproval.rawValue {").dropFirst().first)
        let body = branch.components(separatedBy: "\n            }").first ?? ""
        #expect(body.contains("cursorResetGroupIDs.insert(delta.groupID)"))
        #expect(body.contains("notify.selfApprovedZones.append(delta.groupID)"))

        let service = try Self.source("Yala/Services/Groups/GroupNotificationService.swift")
        #expect(service.contains("newPendingMembers.isEmpty && selfApprovedGroups.isEmpty"), "un changeset solo con la aprobación se descartaría")
        let process = try #require(service.components(separatedBy: "guard let item, item.isActive else { return }").dropFirst().first)
        let selfApproved = try #require(process.range(of: "notifySelfApproved(groupID: groupID)"))
        let rateLimit = try #require(process.range(of: "isRateLimited(groupID: groupID)"))
        #expect(selfApproved.lowerBound < rateLimit.lowerBound, "el aviso de aprobado no puede quedar tapado por el límite de 5 min")
    }

    /// L19-1: quien puede aceptar ve las solicitudes en su sección y no repetidas en la lista; la confirmación usa el
    /// mismo verbo.
    @Test func joinRequests_haveTheirSection_andLeaveTheList() throws {
        let members = try Self.source("Yala/App/Views/Groups/GroupMembersView.swift")
        // Desde el lote 12 decidido Miembros es una lista agrupada: la sección de solicitudes va en su propia `Section`.
        #expect(members.contains("if canActAsAdmin && !viewModel.pendingApprovalMembers.isEmpty {\n                    Section {\n                        joinRequestsSection"))
        #expect(members.contains("canActAsAdmin ? viewModel.visibleMembers.filter { !$0.isPendingApproval } : viewModel.visibleMembers"))
        #expect(members.contains("ForEach(listedMembers, id: \\.id)"))
        #expect(members.contains("Button(L10n.UXD14.requestsAccept) { performApprove() }\n                    .accessibilityIdentifier(\"group_member_approve_confirm\")"))

        let detail = try Self.source("Yala/App/Views/Groups/GroupDetailView.swift")
        #expect(detail.contains("canReview: viewModel.isCurrentUserAdmin && !group.isMigratedFrozen"))
        #expect(detail.contains("onReview: { viewModel.activeSheet = .members }"))
    }
}
