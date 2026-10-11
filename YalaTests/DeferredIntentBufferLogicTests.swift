//
//  DeferredIntentBufferLogicTests.swift
//  YalaTests
//

import Testing
import Foundation
@testable import Yala

@Suite("DeferredIntentBufferLogic")
struct DeferredIntentBufferLogicTests {

    @Test func serialize_navigate_returnsRouterKey() {
        let s = DeferredIntentBufferLogic.serialize(.navigate(.statistics))
        if case .navigate(let key) = s { #expect(key == "statistics") } else { Issue.record("wrong case") }
    }

    /// Hasta el 2026-10-10 devolvía `nil` «a propósito» y el aplazamiento perdía la foto compartida en silencio
    /// (ticket share-image-reading-does-not-always-start). Ahora guarda la RUTA del fichero de `PendingImages/`.
    @Test func serialize_sharedImage_keepsTheFilePath() {
        let url = URL(fileURLWithPath: "/tmp/PendingImages/foo.jpg")
        #expect(DeferredIntentBufferLogic.serialize(.presentSharedImage(url)) == .presentSharedImage(path: url.path))
        #expect(DeferredIntentBufferLogic.canSerialize(.presentSharedImage(url)))
    }

    @Test func serialize_sharedImage_nonFileURL_returnsNil() {
        let url = URL(string: "https://example.com/foo.jpg")!
        #expect(DeferredIntentBufferLogic.serialize(.presentSharedImage(url)) == nil)
    }

    @Test func deserialize_sharedImage_withTheFileStillThere_rebuildsTheIntent() {
        let intent = DeferredIntentBufferLogic.deserialize(.presentSharedImage(path: "/tmp/PendingImages/foo.jpg"),
                                                           fileExists: { _ in true })
        #expect(intent == .presentSharedImage(URL(fileURLWithPath: "/tmp/PendingImages/foo.jpg")))
        #expect(intent?.id == "sharedImage:foo.jpg")
    }

    /// La hoja ya leyó la foto (y la borró) o la purga de 24 h se la llevó: no hay nada que presentar.
    @Test func deserialize_sharedImage_withTheFileGone_returnsNil() {
        #expect(DeferredIntentBufferLogic.deserialize(.presentSharedImage(path: "/tmp/PendingImages/foo.jpg"),
                                                      fileExists: { _ in false }) == nil)
    }

    @Test func roundTrip_sharedImage_throughJSON() {
        // ISO-8601 guarda segundos enteros: la fecha va truncada, como en el round-trip de groupDetail.
        let createdAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let entry = DeferredEntry(payload: .presentSharedImage(path: "/tmp/PendingImages/foo.jpg"), createdAt: createdAt)
        let data = DeferredIntentBufferLogic.encode([entry])
        #expect(DeferredIntentBufferLogic.decode(data) == [entry])
    }

    @Test func serialize_navigateGroupDetail_preservesGroupID() {
        // groupDetail routes through the dedicated case so a group deep link
        // (yala://groups/<id>) survives a pre-bootstrap defer in cold launch
        // instead of being dropped. Regression: Bugs/qa_cold-launch-groupdetail-deeplink-no-routing.
        let s = DeferredIntentBufferLogic.serialize(.navigate(.groupDetail(groupID: "abc")))
        if case .navigateGroupDetail(let groupID) = s {
            #expect(groupID == "abc")
        } else {
            Issue.record("expected .navigateGroupDetail, got \(String(describing: s))")
        }
    }

    @Test func serialize_showInboxAlert_preservesCounters() {
        let notif = PendingInboxNotification(scheduledPayments: 2, subscriptions: 1, automations: 3)
        let s = DeferredIntentBufferLogic.serialize(.showInboxAlert(notif))
        if case .showInboxAlert(let sched, let subs, let autos) = s {
            #expect(sched == 2); #expect(subs == 1); #expect(autos == 3)
        } else {
            Issue.record("wrong case")
        }
    }

    @Test func serialize_nonSerializable_returnsNil() {
        // Only intents with stable proxy survive defer. `.presentNewTransaction` lo fue hasta el 2026-10-11 («sin payload
        // que persistir»); desde entonces se aparca al pasar a segundo plano para que el toque del widget no se pierda
        // (`WidgetAndSiriEntriesBackgroundTests`).
        #expect(DeferredIntentBufferLogic.serialize(.presentUpgradeSheet(.voice)) == nil)
        #expect(DeferredIntentBufferLogic.serialize(.iCloudMismatch) == nil)
    }

    @Test func canSerialize_consistentWithSerialize() {
        #expect(DeferredIntentBufferLogic.canSerialize(.navigate(.inbox)))
        // groupDetail is now serializable → the RouterEntryGate "DROP non-serializable"
        // canary must no longer fire for a group deep link.
        #expect(DeferredIntentBufferLogic.canSerialize(.navigate(.groupDetail(groupID: "g1"))))
        #expect(!DeferredIntentBufferLogic.canSerialize(.presentTrialOffer))
    }

    @Test func roundTrip_navigate() {
        // Build with a date truncated to whole seconds — ISO8601 default does
        // NOT preserve fractional seconds, so equality otherwise drifts.
        let createdAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let entry = DeferredEntry(payload: .navigate(routerKey: "inbox"), createdAt: createdAt)
        let data = DeferredIntentBufferLogic.encode([entry])
        #expect(data != nil)
        let decoded = DeferredIntentBufferLogic.decode(data)
        #expect(decoded == [entry])
    }

    @Test func decode_emptyData_returnsEmpty() {
        #expect(DeferredIntentBufferLogic.decode(Data()) == [])
        #expect(DeferredIntentBufferLogic.decode(nil) == [])
    }

    @Test func decode_malformedJSON_returnsEmpty_noCrash() {
        let bad = "not valid json".data(using: .utf8)
        #expect(DeferredIntentBufferLogic.decode(bad) == [])
    }

    @Test func decode_unknownVersion_dropsEntry() {
        // Swift auto-derived Codable for `case navigate(routerKey: String)` produces
        // {"navigate":{"routerKey":"..."}} (NOT a `_0` wrapper — that's only for
        // unlabeled associated values). Version 999 → filter drops the entry but
        // the array-level decode must succeed first.
        let json = """
        [{"version":999,"createdAt":"2026-01-01T00:00:00Z","payload":{"navigate":{"routerKey":"inbox"}}}]
        """
        let data = json.data(using: .utf8)!
        let decoded = DeferredIntentBufferLogic.decode(data)
        #expect(decoded.isEmpty)
    }

    @Test func purgeExpired_dropsOldEntries() {
        let old = DeferredEntry(payload: .navigate(routerKey: "inbox"),
                                 createdAt: Date(timeIntervalSinceNow: -25 * 60 * 60))
        let recent = DeferredEntry(payload: .navigate(routerKey: "panel"),
                                    createdAt: Date(timeIntervalSinceNow: -1 * 60 * 60))
        let kept = DeferredIntentBufferLogic.purgeExpired(
            [old, recent], now: Date(), ttl: 24 * 60 * 60)
        #expect(kept.count == 1)
        if case .navigate(let key) = kept.first?.payload { #expect(key == "panel") }
    }

    @Test func purgeExpired_keepsAllRecent() {
        let recent = DeferredEntry(payload: .navigate(routerKey: "inbox"))
        let kept = DeferredIntentBufferLogic.purgeExpired([recent], now: Date())
        #expect(kept == [recent])
    }

    @Test func deserialize_navigate_roundtrips() {
        let s: SerializableIntent = .navigate(routerKey: "inbox")
        let intent = DeferredIntentBufferLogic.deserialize(s)
        if case .navigate(let dest) = intent { #expect(dest == .inbox) } else { Issue.record("wrong case") }
    }

    @Test func deserialize_unknownRouterKey_returnsNil() {
        let s: SerializableIntent = .navigate(routerKey: "futureTab")
        #expect(DeferredIntentBufferLogic.deserialize(s) == nil)
    }

    @Test func deserialize_inboxAlert_reconstructsNotification() {
        let s: SerializableIntent = .showInboxAlert(scheduledPayments: 1, subscriptions: 2, automations: 3)
        let intent = DeferredIntentBufferLogic.deserialize(s)
        if case .showInboxAlert(let notif) = intent {
            #expect(notif.scheduledPayments == 1)
            #expect(notif.subscriptions == 2)
            #expect(notif.automations == 3)
        } else {
            Issue.record("wrong case")
        }
    }

    @Test func deserialize_navigateGroupDetail_roundtrips() {
        let s: SerializableIntent = .navigateGroupDetail(groupID: "grp-42")
        let intent = DeferredIntentBufferLogic.deserialize(s)
        if case .navigate(let dest) = intent {
            #expect(dest == .groupDetail(groupID: "grp-42"))
        } else {
            Issue.record("wrong case")
        }
    }

    @Test func roundTrip_navigateGroupDetail_throughJSON() {
        // The deferred buffer persists as JSON in UserDefaults — verify the new
        // case survives the encode/decode path too, not just the enum mapping.
        let createdAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let entry = DeferredEntry(payload: .navigateGroupDetail(groupID: "grp-7"), createdAt: createdAt)
        let data = DeferredIntentBufferLogic.encode([entry])
        #expect(data != nil)
        let decoded = DeferredIntentBufferLogic.decode(data)
        #expect(decoded == [entry])
    }
}
