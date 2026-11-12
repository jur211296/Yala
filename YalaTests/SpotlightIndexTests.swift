//
//  SpotlightIndexTests.swift
//  YalaTests
//
//  Card ste6 (opción C de `docs/siri-ios-27-2026-10.md`): tus cuentas y movimientos en Spotlight, respetando lo que la
//  app oculta, el borrado y la vista de solo grupos. La lógica es pura; el cableado (los dos embudos de la foto de
//  Siri, abrir un resultado) se fija leyendo el árbol.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

private enum Fixture {
    static let presentation = SpotlightIndexLogic.Presentation(
        untitledTransaction: "Movimiento",
        accountKind: "Cuenta",
        formatAmount: { amount, code in "\(code) \(amount)" },
        formatDate: { _ in "12 oct 2026" }
    )

    static let open = SpotlightIndexLogic.Context(
        isGroupsFocusedShell: false, isExpensesOnlyMode: false, includeGroupTransactions: true)

    static func tx(
        token: String? = "dG9rZW4",
        amount: Double = -25,
        note: String? = "Cine",
        category: String? = "Ocio",
        subcategory: String? = nil,
        account: String? = "BCP",
        tags: [String] = [],
        isIncome: Bool = false,
        isTransfer: Bool = false,
        isBalanceAdjustment: Bool = false,
        excluded: Bool = false,
        bridged: Bool = false,
        pendingDeletion: Bool = false
    ) -> SpotlightIndexLogic.TransactionInput {
        SpotlightIndexLogic.TransactionInput(
            recordToken: token, date: Date(timeIntervalSince1970: 1_760_000_000), amount: amount, currencyCode: "PEN",
            note: note, categoryName: category, subcategoryName: subcategory, accountName: account, tagNames: tags,
            isIncome: isIncome, isTransfer: isTransfer, isBalanceAdjustment: isBalanceAdjustment,
            accountExcludedFromStatistics: excluded, isGroupBridged: bridged, isPendingDeletion: pendingDeletion)
    }

    static let bcp = SiriFinanceSnapshot.Account(
        id: "11111111-1111-1111-1111-111111111111", name: "BCP",
        lines: [.init(currencyCode: "PEN", balance: 1200), .init(currencyCode: "USD", balance: 40)])
}

@Suite("Spotlight · qué entra en el índice")
struct SpotlightIndexEligibilityTests {

    @Test func unGastoNormal_entra() {
        #expect(SpotlightIndexLogic.isIndexable(Fixture.tx(), context: Fixture.open))
    }

    /// Lo que Registros no enseña sin filtros tampoco se busca desde fuera.
    @Test func loOculto_noEntra() {
        let hidden = [
            Fixture.tx(excluded: true),
            Fixture.tx(pendingDeletion: true),
            Fixture.tx(isTransfer: true),
            Fixture.tx(isBalanceAdjustment: true),
            Fixture.tx(token: nil)
        ]
        for tx in hidden { #expect(!SpotlightIndexLogic.isIndexable(tx, context: Fixture.open)) }
    }

    @Test func losGastosDeGrupo_siguenElAjusteDeRegistros() {
        let bridged = Fixture.tx(bridged: true)
        #expect(SpotlightIndexLogic.isIndexable(bridged, context: Fixture.open))
        let off = SpotlightIndexLogic.Context(
            isGroupsFocusedShell: false, isExpensesOnlyMode: false, includeGroupTransactions: false)
        #expect(!SpotlightIndexLogic.isIndexable(bridged, context: off))
        #expect(SpotlightIndexLogic.isIndexable(Fixture.tx(), context: off), "Control: un gasto propio sigue entrando.")
    }

    @Test func soloGastos_dejaFueraLosIngresos() {
        let expensesOnly = SpotlightIndexLogic.Context(
            isGroupsFocusedShell: false, isExpensesOnlyMode: true, includeGroupTransactions: true)
        #expect(!SpotlightIndexLogic.isIndexable(Fixture.tx(amount: 3000, isIncome: true), context: expensesOnly))
        #expect(SpotlightIndexLogic.isIndexable(Fixture.tx(), context: expensesOnly))
        #expect(SpotlightIndexLogic.isIndexable(Fixture.tx(amount: 3000, isIncome: true), context: Fixture.open))
    }

    @Test func conLaVistaDeSoloGrupos_elIndiceQuedaVacio() {
        let groups = SpotlightIndexLogic.Context(
            isGroupsFocusedShell: true, isExpensesOnlyMode: false, includeGroupTransactions: true)
        let entries = SpotlightIndexLogic.entries(
            accounts: [Fixture.bcp], transactions: [Fixture.tx()], context: groups, presentation: Fixture.presentation)
        #expect(entries.isEmpty)
        let open = SpotlightIndexLogic.entries(
            accounts: [Fixture.bcp], transactions: [Fixture.tx()], context: Fixture.open,
            presentation: Fixture.presentation)
        #expect(open.count == 2, "Control: sin la vista de solo grupos entran la cuenta y el gasto.")
    }
}

@Suite("Spotlight · cómo se enseña cada resultado")
struct SpotlightIndexPresentationTests {

    @Test func laCuenta_llevaNombreYDivisas_sinSaldo() {
        let entry = SpotlightIndexLogic.accountEntry(Fixture.bcp, presentation: Fixture.presentation)
        #expect(entry.identifier == "account.11111111-1111-1111-1111-111111111111")
        #expect(entry.title == "BCP")
        #expect(entry.detail == "Cuenta · PEN · USD")
        #expect(!entry.detail.contains("1200") && !entry.detail.contains("40"))
        #expect(entry.accountID == Fixture.bcp.id)
        #expect(entry.accountCurrencyCodes == ["PEN", "USD"])
    }

    @Test func elMovimiento_seTitulaConLaNota_yLlevaImporteCuentaYFecha() throws {
        let entry = try #require(SpotlightIndexLogic.transactionEntry(
            Fixture.tx(tags: ["Viaje"]), presentation: Fixture.presentation))
        #expect(entry.identifier == "transaction.dG9rZW4")
        #expect(entry.title == "Cine")
        #expect(entry.detail == "PEN 25.0 · Ocio · BCP · 12 oct 2026")
        #expect(entry.keywords == ["Ocio", "BCP", "Viaje"])
    }

    @Test func sinNota_elTituloEsLaSubcategoria_yNoSeRepite() throws {
        let entry = try #require(SpotlightIndexLogic.transactionEntry(
            Fixture.tx(note: "  ", subcategory: "Cine y teatro"), presentation: Fixture.presentation))
        #expect(entry.title == "Cine y teatro")
        #expect(entry.detail == "PEN 25.0 · BCP · 12 oct 2026")
        let bare = try #require(SpotlightIndexLogic.transactionEntry(
            Fixture.tx(note: nil, category: nil, account: nil), presentation: Fixture.presentation))
        #expect(bare.title == "Movimiento")
        #expect(bare.detail == "PEN 25.0 · 12 oct 2026")
    }
}

@Suite("Spotlight · qué cambia en el índice")
struct SpotlightIndexPlanTests {

    private func entry(_ id: String, title: String = "x") -> SpotlightEntry {
        SpotlightEntry(kind: .transaction, identifier: id, title: title, detail: "d", keywords: [], date: nil,
                       accountID: nil, accountCurrencyCodes: [])
    }

    @Test func sinEstadoGuardado_seVaciaYSeIndexaEntero() {
        let plan = SpotlightIndexLogic.plan(desired: [entry("a"), entry("b")], indexed: nil)
        #expect(plan.deletesEverythingFirst)
        #expect(plan.toIndex.map(\.identifier) == ["a", "b"])
        #expect(plan.resulting.keys.sorted() == ["a", "b"])
    }

    @Test func soloSeTocaLoQueCambio_yLoBorradoSale() {
        let a = entry("a"), b = entry("b"), bNew = entry("b", title: "nuevo")
        let plan = SpotlightIndexLogic.plan(
            desired: [a, bNew], indexed: ["a": a.fingerprint, "b": b.fingerprint, "c": "viejo"])
        #expect(!plan.deletesEverythingFirst)
        #expect(plan.toIndex.map(\.identifier) == ["b"])
        #expect(plan.toDelete == ["c"])
        #expect(plan.resulting == ["a": a.fingerprint, "b": bNew.fingerprint])
    }

    @Test func sinCambios_elPlanEstaVacio() {
        let a = entry("a")
        #expect(SpotlightIndexLogic.plan(desired: [a], indexed: ["a": a.fingerprint]).isEmpty)
        #expect(!SpotlightIndexLogic.plan(desired: [], indexed: ["a": a.fingerprint]).isEmpty)
    }
}

@Suite("Spotlight · tocar un resultado", .serialized)
struct SpotlightIndexDeepLinkTests {

    @Test func cadaResultado_abreSuFichaOSuRegistro() {
        let id = "22222222-2222-2222-2222-222222222222"
        #expect(SpotlightIndexLogic.deepLink(forIdentifier: "account.\(id)") == "accounts/\(id)")
        #expect(SpotlightIndexLogic.deepLink(forIdentifier: "account.no-uuid") == nil)
        #expect(SpotlightIndexLogic.deepLink(forIdentifier: "transaction.dG9r-ZW4_") == "records/dG9r-ZW4_")
        #expect(SpotlightIndexLogic.deepLink(forIdentifier: "transaction.a/b") == nil, "Una barra rompería la ruta.")
        #expect(SpotlightIndexLogic.deepLink(forIdentifier: "transaction.") == nil)
        #expect(SpotlightIndexLogic.deepLink(forIdentifier: "otro.\(id)") == nil)
        #expect(SpotlightRecordLink.token(fromDeepLink: "records/dG9r-ZW4_") == "dG9r-ZW4_")
        #expect(SpotlightRecordLink.token(fromDeepLink: "records/") == nil)
    }

    /// El token es el `PersistentIdentifier` del registro: vale para TODOS los registros, también los del modo iCloud,
    /// que no tienen `syncID`. Y vuelve al mismo registro.
    @Test @MainActor func elTokenDelRegistro_vuelveAlMismoRegistro() throws {
        let context = try makeTestContext()
        let record = TransactionItem(date: Date(timeIntervalSince1970: 1_760_000_000), amount: -25, currencyCode: "PEN")
        context.insert(record)
        try context.save()
        #expect(record.syncID == nil, "Control: el registro de iCloud no tiene syncID.")
        let token = try #require(SpotlightRecordLink.token(for: record.persistentModelID))
        #expect(SpotlightRecordLink.isToken(token))
        #expect(SpotlightRecordLink.identifier(fromToken: token) == record.persistentModelID)
        // El token no puede depender del orden de las claves del JSON, que cambia entre procesos: con claves ordenadas,
        // volver a codificar lo decodificado da el mismo token.
        let decoded = try #require(SpotlightRecordLink.identifier(fromToken: token))
        #expect(SpotlightRecordLink.token(for: decoded) == token)
        let json = try #require(Data(base64Encoded: Self.padded(token)))
        let keys = try #require(String(data: json, encoding: .utf8))
        let entityName = try #require(keys.range(of: "\"entityName\""))
        let primaryKey = try #require(keys.range(of: "\"primaryKey\""))
        #expect(entityName.lowerBound < primaryKey.lowerBound, "Las claves tienen que ir ordenadas.")
        let link = try #require(SpotlightIndexLogic.deepLink(forIdentifier: SpotlightIndexLogic.transactionPrefix + token))
        #expect(WidgetURLHelper.url(for: link) != nil, "El enlace tiene que ser una URL válida.")
    }

    private static func padded(_ token: String) -> String {
        let base = token.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        return base + String(repeating: "=", count: (4 - base.count % 4) % 4)
    }

    @Test @MainActor func elRegistroPedido_seEntregaUnaVez_yCaduca() throws {
        let context = try makeTestContext()
        let record = TransactionItem(date: Date(timeIntervalSince1970: 1_760_000_000), amount: -25, currencyCode: "PEN")
        context.insert(record)
        try context.save()
        let target = SpotlightRecordTarget()
        let now = Date(timeIntervalSince1970: 1_000_000)
        target.request(record.persistentModelID, now: now)
        #expect(target.consume(now: now.addingTimeInterval(5)) == record.persistentModelID)
        #expect(target.consume(now: now.addingTimeInterval(6)) == nil)
        target.request(record.persistentModelID, now: now)
        #expect(target.consume(now: now.addingTimeInterval(AlertDeepLinkTarget.maxAge + 1)) == nil)
    }
}

/// El cableado vive en ficheros que no se pueden ejercer sin el simulador: se lee del árbol, sin comentarios.
@Suite("Spotlight · cableado (source-scan)")
struct SpotlightIndexWiringTests {

    private static func code(_ path: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El índice vive y muere con la foto de Siri: se reconcilia donde se escribe y se vacía donde se borra.
    @Test func vivesYMuereConLaFotoDeSiri() throws {
        let cache = try Self.code("Yala/Services/WidgetDataCache.swift")
        let update = try #require(cache.range(of: "static func updateCache(context: ModelContext) {"))
        let updateBody = cache[update.upperBound...].prefix(1200)
        #expect(updateBody.contains("SpotlightIndexService.scheduleReconcile(context: context)"))
        let wipeGuard = try #require(updateBody.range(of: "guard !isWipeArmed"))
        let schedule = try #require(updateBody.range(of: "SpotlightIndexService.scheduleReconcile"))
        #expect(wipeGuard.lowerBound < schedule.lowerBound, "Con un borrado armado no se pide reconciliar.")

        let clear = try #require(cache.range(of: "static func clearCache() {"))
        #expect(cache[clear.upperBound...].prefix(200).contains("SpotlightIndexService.clear()"))
    }

    @Test func laReconciliacion_miraElBorradoArmadoAlEjecutarse() throws {
        let service = try Self.code("Yala/Services/Spotlight/SpotlightIndexService.swift")
        let reconcile = try #require(service.range(of: "private static func reconcile(context: ModelContext) {"))
        #expect(service[reconcile.upperBound...].prefix(120).contains("guard !WidgetDataCache.isWipeArmed"))
        #expect(service.contains("protectionClass: .complete"))
    }

    @Test func laVueltaAPrimerPlano_reconcilia() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains("SpotlightIndexService.scheduleReconcile(context: context)"))
    }

    @Test func tocarUnResultado_abreSuEnlace() throws {
        let scene = try Self.code("Yala/App/Scenes/SceneRoot.swift")
        #expect(scene.contains("onContinueUserActivity(CSSearchableItemActionType)"))
        #expect(scene.contains("SpotlightIndexLogic.deepLink(forIdentifier:"))
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains("SpotlightRecordTarget.shared.request("))
        let content = try Self.code("Yala/App/ContentView.swift")
        let records = try #require(content.range(of: "case .recordsStandalone:"))
        let body = content[records.upperBound...].prefix(500)
        #expect(body.contains("SpotlightRecordTarget.shared.consume()"))
        #expect(body.contains("navigation.pendingRecordID"))
    }
}
