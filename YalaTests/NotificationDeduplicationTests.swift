//
//  NotificationDeduplicationTests.swift
//  YalaTests
//
//  La limpieza de avisos duplicados del arranque (`NotificationService.deduplicateNotifications`) junta los avisos de
//  sistema que se siembran por dispositivo y no toca los recordatorios de la persona (`custom`). Ticket
//  `notification-dedup-deletes-all-custom-reminders-but-one`: agrupaba TODO por `typeRaw` y borraba en cada arranque
//  todos los recordatorios propios menos uno.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Limpieza de avisos del arranque: contra el store", .serialized)
@MainActor
struct NotificationDeduplicationStoreTests {

    private func custom(_ name: String, active: Bool = true) -> NotificationItem {
        NotificationItem(name: name, text: "Texto de \(name)", hour: 9, minute: 0, type: .custom, isActive: active)
    }

    private func system(_ type: NotificationType, active: Bool) -> NotificationItem {
        NotificationItem(name: "", text: "", hour: 20, minute: 0, type: type, isActive: active)
    }

    private func fetchAll(_ context: ModelContext) throws -> [NotificationItem] {
        try context.fetch(FetchDescriptor<NotificationItem>())
    }

    /// El caso del ticket: tres recordatorios propios y un aviso de sistema duplicado. Con el código viejo quedaba UN
    /// recordatorio; ahora quedan los tres, y el duplicado de sistema se sigue limpiando (se queda el activo).
    @Test("tres recordatorios propios sobreviven; el aviso de sistema duplicado se limpia")
    func threeCustomsSurvive_systemDuplicateIsCleaned() throws {
        let context = try makeTestContext()
        #expect(iCloudSyncService.shared.isImportQuiescent, "control: sin quiescencia la limpieza no corre y el caso no mide nada")
        let names = ["Agua", "Gimnasio", "Pagar la luz"]
        for name in names { context.insert(custom(name)) }
        let keptSystem = system(.endOfDay, active: true)
        context.insert(system(.endOfDay, active: false))
        context.insert(keptSystem)
        context.insert(system(.lunchTime, active: false))
        try context.save()

        NotificationService.shared.deduplicateNotifications(context: context)

        let all = try fetchAll(context)
        let customs = all.filter { $0.typeRaw == "custom" }
        #expect(Set(customs.map(\.name)) == Set(names), "La limpieza borró recordatorios propios: \(customs.map(\.name))")
        let endOfDay = all.filter { $0.typeRaw == "endOfDay" }
        #expect(endOfDay.count == 1, "El aviso de sistema duplicado no se limpió")
        #expect(endOfDay.first?.id == keptSystem.id, "Se quedó el inactivo en vez del activo")
        #expect(all.filter { $0.typeRaw == "lunchTime" }.count == 1, "Un aviso de sistema sin duplicado no se toca")
        #expect(all.count == 5)
    }

    /// Dos recordatorios propios IDÉNTICOS (mismo nombre, texto y hora) son dos decisiones de la persona, no una copia: la
    /// limpieza no los junta por contenido.
    @Test("dos recordatorios propios idénticos no se juntan")
    func identicalCustoms_areNotMerged() throws {
        let context = try makeTestContext()
        context.insert(custom("Agua"))
        context.insert(custom("Agua", active: false))
        try context.save()

        NotificationService.shared.deduplicateNotifications(context: context)

        #expect(try fetchAll(context).count == 2)
    }

    /// Lo que la limpieza borra lo desprograma, y solo eso: sin quitar sus avisos, la fila borrada seguía sonando cada día.
    @Test("desprograma los avisos de lo que borra, y nada más")
    func removesTheScheduledRequestsOfWhatItDeletes() throws {
        let context = try makeTestContext()
        let customs = [custom("Agua"), custom("Gimnasio")]
        for item in customs { context.insert(item) }
        let duplicate = system(.endOfDay, active: false)
        context.insert(duplicate)
        context.insert(system(.endOfDay, active: true))
        try context.save()
        let duplicateID = duplicate.id

        var removed: [String] = []
        NotificationService.shared.deduplicateNotifications(context: context, removePendingRequests: { removed += $0 })

        #expect(removed == NotificationService.scheduledRequestIdentifiers(for: duplicateID))
        #expect(try fetchAll(context).count == 3)
    }

    @Test("sin duplicados no desprograma nada")
    func nothingToClean_removesNothing() throws {
        let context = try makeTestContext()
        context.insert(custom("Agua"))
        context.insert(custom("Gimnasio"))
        context.insert(system(.endOfDay, active: true))
        try context.save()

        var calls = 0
        NotificationService.shared.deduplicateNotifications(context: context, removePendingRequests: { _ in calls += 1 })

        #expect(calls == 0)
        #expect(try fetchAll(context).count == 3)
    }
}

@Suite("Limpieza de avisos del arranque: qué se junta")
struct NotificationDeduplicationLogicTests {

    private typealias C = NotificationDeduplicationLogic.Candidate

    private static func c(_ typeRaw: String, _ isActive: Bool = false) -> C { C(typeRaw: typeRaw, isActive: isActive) }

    struct Row: CustomTestStringConvertible, Sendable {
        let label: String
        let candidates: [(String, Bool)]
        let deleted: [Int]
        var testDescription: String { label }
    }

    /// La tabla del ticket. Cada fila: los avisos en el orden en que los devuelve el fetch y los índices que sobran.
    static let table: [Row] = [
        Row(label: "un aviso de sistema duplicado: sobra el inactivo",
            candidates: [("endOfDay", false), ("endOfDay", true)], deleted: [0]),
        Row(label: "duplicado sin ninguno activo: se queda el primero",
            candidates: [("lunchTime", false), ("lunchTime", false), ("lunchTime", false)], deleted: [1, 2]),
        Row(label: "duplicado con dos activos: se queda el primer activo",
            candidates: [("dailyReport", false), ("dailyReport", true), ("dailyReport", true)], deleted: [0, 2]),
        Row(label: "varios recordatorios propios: no sobra ninguno",
            candidates: [("custom", true), ("custom", true), ("custom", false)], deleted: []),
        Row(label: "mezcla: tres propios y un sistema duplicado, solo sobra el duplicado",
            candidates: [("custom", true), ("endOfDay", false), ("custom", false), ("endOfDay", true), ("custom", true),
                         ("groups", false)],
            deleted: [1]),
        Row(label: "un tipo que este build no conoce se junta como uno de sistema",
            candidates: [("weeklyDigest", true), ("weeklyDigest", false), ("custom", true)], deleted: [1]),
        Row(label: "sin duplicados no sobra nada",
            candidates: NotificationType.allCases.map { ($0.rawValue, false) }, deleted: []),
    ]

    @Test("qué sobra", arguments: table)
    func whatIsDeleted(_ row: Row) {
        let candidates = row.candidates.map { Self.c($0.0, $0.1) }
        #expect(NotificationDeduplicationLogic.indicesToDelete(candidates) == row.deleted)
    }

    /// El control del bug: la limpieza vieja juntaba por `typeRaw` a secas. Con esa clave la fila de la mezcla borra dos
    /// recordatorios propios; si este control deja de dar dos, la fila de arriba no mide el bug.
    @Test("control: juntar por typeRaw a secas borra recordatorios propios")
    func oldGroupingDeletesCustoms() {
        let mixed = Self.table[4].candidates
        let byTypeOnly = Dictionary(grouping: mixed.indices) { mixed[$0].0 }
        let oldDeleted = byTypeOnly.values.flatMap { group in
            group.sorted { (mixed[$0].1 ? 1 : 0) > (mixed[$1].1 ? 1 : 0) }.dropFirst()
        }
        #expect(oldDeleted.filter { mixed[$0].0 == "custom" }.count == 2)
        #expect(Self.table[4].deleted.allSatisfy { mixed[$0].0 != "custom" })
    }

    /// La clave de la limpieza y la de fusión del linaje dicen lo mismo de cada tipo: el linaje da por fundida con otra la
    /// fila que tiene clave de fusión, y esa fusión la hace esta limpieza.
    @Test("la clave de la limpieza y la de fusión del linaje coinciden en qué se junta",
          arguments: NotificationType.allCases.map(\.rawValue) + ["weeklyDigest", ""])
    func matchesLineageFusion(_ typeRaw: String) {
        #expect((NotificationDeduplicationLogic.groupKey(typeRaw: typeRaw) == nil)
                == (LineageTwinKey.notificationFusion(typeRaw: typeRaw) == nil))
    }

    @Test("los identificadores que desprograma: el del aviso y uno por día de la semana")
    func scheduledIdentifiers() {
        let id = UUID()
        let ids = NotificationService.scheduledRequestIdentifiers(for: id)
        #expect(ids == [id.uuidString] + (1...7).map { "\(id.uuidString)-\($0)" })
    }
}
