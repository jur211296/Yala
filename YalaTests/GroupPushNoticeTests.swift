//
//  GroupPushNoticeTests.swift
//  YalaTests
//
//  Card sztn (2026-10-30): el aviso de actividad de un grupo dice quién, qué, concepto, importe y grupo, y no le llega a
//  quien hizo la acción. Lo que fija esta suite, del lado de la app:
//  1. las `loc-key` que compone el Worker (`gateway/src/groups/notice.ts`) son las que la app conoce, existen en los 16
//     `.lproj` con su número de huecos, y la app las sustituye por su aviso rico como a los genéricos;
//  2. lo que el teléfono adjunta al subir (`GroupPushNoticeBuilder`) trae quién, el grupo, concepto, importe, saldo
//     inicial, el gasto de una cuota y quién paga a quién;
//  3. el body del push lleva esa `notice` al lado de los deltas, y sin ella es byte-idéntico al de antes.
//  Los destinatarios (nadie del autor, ni su device a nombre de otra cuenta) los fijan los tests del Worker.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Aviso de grupo · textos y contrato", .serialized)
struct GroupPushNoticeTests {

    // MARK: - 1. Contrato de claves con el Worker y los .lproj

    @Test func workerKeysMatchTheApp() throws {
        let ts = try Self.source("gateway/src/groups/notice.ts")
        let start = try #require(ts.range(of: "export const GROUP_NOTICE_LOC_KEYS: Record<string, number> = {"))
        let rest = ts[start.upperBound...]
        let end = try #require(rest.range(of: "};"))
        var worker: [String: Int] = [:]
        for line in rest[..<end.lowerBound].split(separator: "\n") {
            let parts = line.split(separator: ":").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \",")) }
            guard parts.count == 2, let n = Int(parts[1]) else { continue }
            worker[parts[0]] = n
        }
        #expect(worker.count == 12, "el escáner no leyó el bloque: \(worker)")
        #expect(worker == GroupServerNoticeReplacementLogic.pushNoticeLocKeys)
    }

    @Test func everyKeyExistsInEveryLocale_withItsPlaceholders() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let resources = root.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        let placeholder = try Regex("%([0-9]+)\\$@")
        for locale in locales {
            let url = resources.appendingPathComponent(locale).appendingPathComponent("Localizable.strings")
            let dict = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            for (key, count) in GroupServerNoticeReplacementLogic.pushNoticeLocKeys {
                let value = try #require(dict[key], "\(locale) no tiene \(key)")
                let indices = Set(value.matches(of: placeholder).compactMap { Int(String($0.output[1].substring ?? "")) })
                #expect(indices == Set(1...count), "\(locale) \(key): \(value)")
            }
        }
    }

    @Test func theRichNoticeReplacesTheConcreteServerOnes_butNotWhatItCannotCount() {
        let links: Set<String> = ["groups/SplitGroup-1"]
        // Borrados y ajustes no entran en `RemoteChangeSet`: un aviso rico de otro cambio no puede retirarlos.
        let kept: Set<String> = [
            "notifications.groups.push.expenseDeleted",
            "notifications.groups.push.settlementDeleted",
            "notifications.groups.push.groupUpdated",
        ]
        for key in GroupServerNoticeReplacementLogic.pushNoticeLocKeys.keys {
            let info: [AnyHashable: Any] = [
                "aps": ["alert": ["title": "Jurpi", "loc-key": key, "loc-args": ["Ana"]]],
                "deepLink": "groups/SplitGroup-1",
            ]
            #expect(GroupServerNoticeReplacementLogic.isServerNotice(info, groupLinks: links) == !kept.contains(key), "\(key)")
        }
        // Control: una clave ajena no se retira.
        let other: [AnyHashable: Any] = ["aps": ["alert": ["loc-key": "notifications.otra"]], "deepLink": "groups/SplitGroup-1"]
        #expect(!GroupServerNoticeReplacementLogic.isServerNotice(other, groupLinks: links))
    }

    // MARK: - 2. Lo que adjunta el teléfono

    private let zone = "SplitGroup-ABC"

    @Test func expenseRow_carriesActorGroupConceptAndAmount() throws {
        let context = try makeTestContext()
        let group = SplitGroup(name: "Jurpi ❤️")
        group.cloudKitZoneID = zone
        context.insert(group)
        let expense = SplitExpense(groupZoneID: zone, amount: 40.6, currencyCode: "PEN", expenseDescription: "Foppy Pet Store")
        context.insert(expense)
        try context.save()

        let notice = try #require(GroupPushNoticeBuilder.notice(
            for: [.init(entityType: GroupSyncEntityType.splitExpense, groupID: zone, syncID: expense.id, isTombstone: false)],
            context: context, actorName: { _, _ in "María P." }))

        #expect(notice["actors"] as? [String: String] == [zone: "María P."])
        #expect(notice["groups"] as? [String: String] == [zone: "Jurpi ❤️"])
        let rows = try #require(notice["rows"] as? [String: [String: Any]])
        let row = try #require(rows[expense.id.uuidString.lowercased()])
        #expect(row["concept"] as? String == "Foppy Pet Store")
        // El formato (decimales, símbolo o código) es preferencia del autor y global: se compara con el mismo formateador.
        #expect(row["amount"] as? String == YalaFormatterStatic.currency(value: 40.6, currencyCode: "PEN"))
        #expect(row["opening"] == nil)
    }

    @Test func openingBalance_isMarked_andAShareLeadsToItsExpense() throws {
        let context = try makeTestContext()
        let expense = SplitExpense(groupZoneID: zone, amount: 40, currencyCode: "PEN", isOpeningBalance: true)
        context.insert(expense)
        let share = SplitShare(expenseID: expense.id, memberID: UUID().uuidString, amount: 40, groupZoneID: zone)
        context.insert(share)
        try context.save()

        let notice = try #require(GroupPushNoticeBuilder.notice(
            for: [.init(entityType: GroupSyncEntityType.splitShare, groupID: zone, syncID: share.id, isTombstone: false)],
            context: context, actorName: { _, _ in "Jürgen" }))
        let rows = try #require(notice["rows"] as? [String: [String: Any]])
        let parentKey = expense.id.uuidString.lowercased()
        #expect(rows[share.id.uuidString.lowercased()]?["parent"] as? String == parentKey)
        // El gasto de la cuota viaja aunque no suba en esta tanda: sin él, el Worker no sabría que es un saldo inicial.
        #expect(rows[parentKey]?["opening"] as? Bool == true)
        #expect(rows[parentKey]?["concept"] == nil)
    }

    @Test func settlementRow_namesWhoPaysWhom() throws {
        let context = try makeTestContext()
        let ana = SplitMember(groupZoneID: zone, displayName: "Ana")
        let jur = SplitMember(groupZoneID: zone, displayName: "Jürgen")
        context.insert(ana)
        context.insert(jur)
        let settlement = SplitSettlement(
            groupZoneID: zone, fromMemberID: ana.id.uuidString, toMemberID: jur.id.uuidString, amount: 20, currencyCode: "PEN")
        context.insert(settlement)
        try context.save()

        let notice = try #require(GroupPushNoticeBuilder.notice(
            for: [.init(entityType: GroupSyncEntityType.splitSettlement, groupID: zone, syncID: settlement.id, isTombstone: false)],
            context: context, actorName: { _, _ in "Ana" }))
        let row = try #require((notice["rows"] as? [String: [String: Any]])?[settlement.id.uuidString.lowercased()])
        #expect(row["from"] as? String == "Ana")
        #expect(row["to"] as? String == "Jürgen")
    }

    @Test func tombstones_addNoRow_andNothingToSayIsNil() throws {
        let context = try makeTestContext()
        let id = UUID()
        let notice = GroupPushNoticeBuilder.notice(
            for: [.init(entityType: GroupSyncEntityType.splitExpense, groupID: zone, syncID: id, isTombstone: true)],
            context: context, actorName: { _, _ in nil })
        #expect(notice == nil)
        #expect(GroupPushNoticeBuilder.notice(for: [], context: context) == nil)
    }

    // MARK: - 3. El body del push

    @Test func wireBody_carriesTheNotice_andWithoutItIsTheOldBody() throws {
        let delta = GroupSyncDelta(
            entityType: "split_expenses", groupID: zone, syncID: UUID(), op: .upsert,
            fieldsRawJSON: "{}", fieldHlcsRawJSON: "{}", hlc: "h", clientMutationID: UUID(), schemaVersion: 1)
        let plain = String(decoding: GroupsSyncClient.wireBody([delta]), as: UTF8.self)
        #expect(plain.hasPrefix("{\"deltas\":[") && !plain.contains("notice"))

        let json = try #require(GroupPushNoticeBuilder.noticeJSON(["actors": [zone: "Ana"], "groups": [zone: "Jurpi"], "rows": [:]]))
        let body = GroupsSyncClient.wireBody([delta], notice: json)
        let parsed = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect((parsed["deltas"] as? [Any])?.count == 1)
        #expect((parsed["notice"] as? [String: Any])?["groups"] as? [String: String] == [zone: "Jurpi"])
    }

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
