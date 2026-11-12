//
//  NoticeOrderTests.swift
//  YalaTests
//
//  Ticket `notices-come-out-one-after-another-by-priority`: entre los avisos del shell de una ventana sale primero el que
//  va delante en la cola, aunque sean de consumidores distintos (`.contentView` y `.mainTab`). La regla vive en
//  `NoticeOrderLogic`; quién va delante y quién está listo, en `AppRouter.shellNoticeAhead(of:in:)`. Y los dos avisos
//  genéricos de Grupos que el aviso rico sustituye, en `GroupServerNoticeReplacementLogic`.
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct NoticeOrderTests {

    private let inbox = RouterIntent.showInboxAlert(
        PendingInboxNotification(scheduledPayments: 1, subscriptions: 0, automations: 0))

    @MainActor
    private func freshRouter(ready: [AppRouter.ConsumerID] = [.contentView, .mainTab]) -> AppRouter {
        let router = AppRouter.shared
        router._testReset()
        for consumer in ready { router.markReady(consumer, in: nil) }
        return router
    }

    // MARK: - La regla

    @Test func mainTabSheets_yieldToAnyShellIntentAhead() {
        for sheet in [RouterIntent.presentMilestoneUpgrade(10), .presentTrialExpired, .presentDowngradeResolution] {
            #expect(NoticeOrderLogic.yields(sheet, to: inbox))
            #expect(NoticeOrderLogic.yields(sheet, to: .presentRemoteWipeNotice))
        }
    }

    @Test func mainTabNonModal_neverYields() {
        #expect(!NoticeOrderLogic.yields(.navigate(.panel), to: inbox))
        #expect(!NoticeOrderLogic.yields(.requestAppStoreReview, to: inbox))
    }

    @Test func contentViewDeferrables_yieldOnlyToAMainTabSheet() {
        for notice in [inbox, .presentTrialOffer, .presentWhatsNew(features: [], version: "9.9")] {
            #expect(NoticeOrderLogic.yields(notice, to: .presentTrialExpired))
            #expect(!NoticeOrderLogic.yields(notice, to: .navigate(.panel)), "un cambio de pestaña no presenta nada")
            #expect(!NoticeOrderLogic.yields(notice, to: .requestAppStoreReview))
        }
    }

    @Test func contentViewCriticalAndTapAnswers_neverYield() {
        let neverYield: [RouterIntent] = [
            .remoteWipe(skipOnboarding: false), .iCloudMismatch, .appleIDChangedClosePrivate, .presentRemoteWipeNotice,
            .presentLateICloudMirrorNotice(.wipeLeftHalfway), .remoteOnboardingCompleted, .showGroupSyncError("x"),
            .presentFullModeActivation, .presentGroupsOrganizerStep,
        ]
        for intent in neverYield {
            #expect(!NoticeOrderLogic.yields(intent, to: .presentTrialExpired), "\(intent.id) no cede")
        }
    }

    /// Review adversarial: la cadena de la invitación cierra el Welcome para drenar (B4-04); si cediera después, la hoja
    /// de fin de prueba saldría sobre una app sin onboarding y la invitación esperaría detrás.
    @Test func answersToALinkTap_neverYield_evenIfDeferrable() {
        let linkAnswers: [RouterIntent] = [
            .showInviteError("x"), .showGroupArchivedNotice(groupID: "g", groupName: "G"),
            .presentGroupsConsent(pendingJoin: "z"), .presentGroupsSignIn(pendingJoin: "z"),
            .presentGroupBackendInviteOnboarding(pendingJoin: "z"), .presentGroupsInviteNeutralGate(pendingJoin: "z"),
        ]
        for intent in linkAnswers {
            #expect(RouterConsumerGateLogic.waitsForForeignPresentation(intent), "\(intent.id) es diferible")
            #expect(!NoticeOrderLogic.yields(intent, to: .presentTrialExpired), "\(intent.id) no cede")
        }
    }

    @Test func panelAndPlanning_areOutOfTheRule() {
        #expect(!NoticeOrderLogic.yields(.presentInboxSheet, to: inbox))
        #expect(!NoticeOrderLogic.yields(.autoOpenBudgetEditor, to: .presentTrialExpired))
        #expect(!NoticeOrderLogic.yields(inbox, to: .presentSharedImage(URL(fileURLWithPath: "/tmp/a.jpg"))))
        #expect(!NoticeOrderLogic.yields(.presentMilestoneUpgrade(1), to: .presentNewTransaction))
    }

    @Test func sameConsumer_neverYieldsToItself() {
        #expect(!NoticeOrderLogic.yields(.presentTrialOffer, to: inbox))
        #expect(!NoticeOrderLogic.yields(.presentMilestoneUpgrade(1), to: .presentTrialExpired))
    }

    // MARK: - La cola

    /// El caso del ticket: Novedades (`.low`) iba antes que «Tu prueba terminó» (`.high`) si `.contentView` miraba antes.
    @Test func lowNoticeWaitsForAHigherMainTabSheet() {
        let router = freshRouter()
        let whatsNew = RouterIntent.presentWhatsNew(features: [], version: "9.9")
        router.enqueue(whatsNew)
        router.enqueue(.presentTrialExpired)

        #expect(router.shellNoticeAhead(of: whatsNew, in: nil) == .presentTrialExpired)
        #expect(router.shellNoticeAhead(of: .presentTrialExpired, in: nil) == nil, "el de delante no espera a nadie")
    }

    @Test func mainTabSheetWaitsForAShellNoticeAhead() {
        let router = freshRouter()
        router.enqueue(.presentMilestoneUpgrade(10))
        router.enqueue(inbox)  // `.high`: se pone delante del hito (`.normal`)

        #expect(router.shellNoticeAhead(of: .presentMilestoneUpgrade(10), in: nil) == inbox)
        #expect(router.shellNoticeAhead(of: inbox, in: nil) == nil)
    }

    /// Misma prioridad: manda la llegada.
    @Test func samePriority_arrivalDecides() {
        let router = freshRouter()
        router.enqueue(.presentMilestoneUpgrade(10))
        router.enqueue(.presentTrialOffer)

        #expect(router.shellNoticeAhead(of: .presentTrialOffer, in: nil) == .presentMilestoneUpgrade(10))
        #expect(router.shellNoticeAhead(of: .presentMilestoneUpgrade(10), in: nil) == nil)
    }

    /// Nunca se espera a un consumidor que no está listo: no va a drenar y el aviso se quedaría colgado.
    @Test func otherConsumerNotReady_doesNotHold() {
        let router = freshRouter(ready: [.contentView])
        let whatsNew = RouterIntent.presentWhatsNew(features: [], version: "9.9")
        router.enqueue(.presentTrialExpired)
        router.enqueue(whatsNew)

        #expect(router.shellNoticeAhead(of: whatsNew, in: nil) == nil)
    }

    @Test func criticalBehindAMainTabSheet_doesNotWait() {
        let router = freshRouter()
        router.enqueue(.presentTrialExpired)
        router.enqueue(.presentRemoteWipeNotice)  // `.high` también, llega después

        #expect(router.shellNoticeAhead(of: .presentRemoteWipeNotice, in: nil) == nil)
    }

    @Test func aNavigateAhead_doesNotHoldANotice() {
        let router = freshRouter()
        router.enqueue(.navigate(.panel))
        router.enqueue(.presentTrialOffer)

        #expect(router.shellNoticeAhead(of: .presentTrialOffer, in: nil) == nil)
    }

    @Test func anIntentNotInTheQueue_hasNothingAhead() {
        let router = freshRouter()
        router.enqueue(.presentTrialExpired)

        #expect(router.shellNoticeAhead(of: .presentTrialOffer, in: nil) == nil)
    }

    /// Lo que el drenaje de `.contentView` le pasa a `drainNext(skipping:)`: con la hoja de MainTab delante, el aviso no
    /// sale; se queda en la cola, en su sitio.
    @Test func contentViewDrain_skipsTheYieldingNotice_andKeepsIt() {
        let router = freshRouter()
        let whatsNew = RouterIntent.presentWhatsNew(features: [], version: "9.9")
        router.enqueue(.presentTrialExpired)
        router.enqueue(whatsNew)

        let drained = router.drainNext(for: .contentView, in: nil, skipping: {
            router.shellNoticeAhead(of: $0, in: nil) != nil
        })
        #expect(drained == nil)
        #expect(router._testQueue.contains(whatsNew))

        // MainTab drena la suya y el aviso queda libre.
        #expect(router.drainNext(for: .mainTab, in: nil) == .presentTrialExpired)
        #expect(router.shellNoticeAhead(of: whatsNew, in: nil) == nil)
    }

    // MARK: - Push genérico de Grupos sustituido por el aviso rico

    private func serverNotice(locKey: String, deepLink: String?) -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = ["aps": ["alert": ["title-loc-key": "notifications.groups.name", "loc-key": locKey]]]
        if let deepLink { info["deepLink"] = deepLink }
        return info
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func replaced(_ info: [AnyHashable: Any], secondsAgo: TimeInterval = 5, links: Set<String>) -> Bool {
        GroupServerNoticeReplacementLogic.isReplacedServerNotice(
            info, deliveredAt: now.addingTimeInterval(-secondsAgo), now: now, groupLinks: links)
    }

    @Test func genericActivityOfTheSameGroup_isReplaced() {
        let id = UUID()
        let links = GroupServerNoticeReplacementLogic.groupLinks(groupID: id, zoneID: "SplitGroup-ABC")
        for key in ["notifications.groups.remoteActivity", "notifications.groups.remotePendingRequest"] {
            #expect(replaced(serverNotice(locKey: key, deepLink: "groups/SplitGroup-ABC"), links: links))
            #expect(replaced(serverNotice(locKey: key, deepLink: "groups/\(id.uuidString)"), links: links))
        }
    }

    /// Review adversarial: el genérico que llegó durante el límite de 5 min no tuvo su aviso rico, y el rico siguiente
    /// solo cuenta su tanda. Retirarlo lo borraba sin sustituto: solo cuenta el que trajo esta tanda.
    @Test func olderGenericOfTheSameGroup_staysPut() {
        let links = GroupServerNoticeReplacementLogic.groupLinks(groupID: UUID(), zoneID: "SplitGroup-ABC")
        let info = serverNotice(locKey: "notifications.groups.remoteActivity", deepLink: "groups/SplitGroup-ABC")
        let window = GroupServerNoticeReplacementLogic.freshWindow
        #expect(replaced(info, secondsAgo: window, links: links), "el borde de la ventana cuenta")
        #expect(!replaced(info, secondsAgo: window + 1, links: links))
        #expect(!replaced(info, secondsAgo: 4 * 60, links: links), "el de hace 4 min es de otra tanda")
    }

    @Test func genericOfAnotherGroup_orOfSeveral_staysPut() {
        let links = GroupServerNoticeReplacementLogic.groupLinks(groupID: UUID(), zoneID: "SplitGroup-ABC")
        let key = "notifications.groups.remoteActivity"
        #expect(!replaced(serverNotice(locKey: key, deepLink: "groups/SplitGroup-OTRO"), links: links))
        #expect(!replaced(serverNotice(locKey: key, deepLink: "groups"), links: links), "el de varios grupos no habla de uno")
        #expect(!replaced(serverNotice(locKey: key, deepLink: nil), links: links))
    }

    @Test func membershipNoticeAndLocalNotices_areNotThisRule() {
        let links = GroupServerNoticeReplacementLogic.groupLinks(groupID: UUID(), zoneID: "SplitGroup-ABC")
        // El de membresía lo retira su propio aviso («Ya estás en X»).
        #expect(!replaced(
            serverNotice(locKey: "notifications.groups.remoteMembershipUpdate", deepLink: "groups/SplitGroup-ABC"),
            links: links))
        // Un aviso local (sin `aps`) nunca es del servidor, aunque apunte al grupo.
        #expect(!replaced(["deepLink": "groups/SplitGroup-ABC"], links: links))
    }

    @Test func emptyZone_onlyNamesTheLocalID() {
        let id = UUID()
        #expect(GroupServerNoticeReplacementLogic.groupLinks(groupID: id, zoneID: "") == ["groups/\(id.uuidString)"])
        #expect(GroupServerNoticeReplacementLogic.groupLinks(groupID: id, zoneID: nil) == ["groups/\(id.uuidString)"])
    }

    // MARK: - Cableado (review adversarial: quitar la llamada de un drenaje dejaba todos los unit tests en verde)

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/YalaTests
        .deletingLastPathComponent()   // raíz

    /// Texto sin comentarios y con los espacios colapsados a uno.
    private static func code(_ path: String) throws -> String {
        var raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        raw = raw.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
        return raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// El cuerpo entre llaves balanceadas que abre la primera `{` tras `marker`.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let tail = source[start.upperBound...]
        let open = try #require(tail.firstIndex(of: "{"), "sin llave tras el marcador: \(marker)")
        var depth = 0
        var index = open
        while index < tail.endIndex {
            if tail[index] == "{" { depth += 1 }
            if tail[index] == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            index = tail.index(after: index)
        }
        return String(tail[tail.index(after: open)..<index])
    }

    /// `.contentView` salta, al drenar, lo que cede ante una hoja de MainTab — en el MISMO `skipping` que lo retenido por
    /// una hoja ajena, para que lo de detrás que no cede salga igual.
    @Test func contentViewDrain_skipsWhatYields() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")
        let drain = try Self.body(of: "private func drainContentViewIntents()", in: vista)
        #expect(drain.contains(
            "skipping: { heldForForeignPresentation($0) || AppRouter.shared.shellNoticeAhead(of: $0, in: windowID) != nil }"))
        #expect(drain.contains("let windowID = navigation.id"))
    }

    /// `.mainTab` pregunta antes de drenar su hoja, deja pasar lo que no presenta hoja y no drena la cabeza si cede.
    @Test func mainTabDrain_asksBeforeDrainingItsSheet() throws {
        let vista = try Self.code("Yala/App/ContentView.swift")
        let drain = try Self.body(of: "private func drainMainTabIntents()", in: vista)
        let ask = try #require(drain.range(of: "if AppRouter.shared.shellNoticeAhead(of: next, in: navigation.id) != nil {"))
        let headDrain = try #require(
            drain.range(of: "guard let intent = AppRouter.shared.drainNext(for: .mainTab, in: navigation.id) else { return }"))
        #expect(ask.lowerBound < headDrain.lowerBound, "la pregunta va antes de drenar la cabeza")
        let yieldBranch = try Self.body(
            of: "if AppRouter.shared.shellNoticeAhead(of: next, in: navigation.id) != nil", in: drain)
        #expect(yieldBranch.contains("skipping: { RouterConsumerGateLogic.presentsModal($0) }"))
        #expect(yieldBranch.contains("return"))
    }
}
