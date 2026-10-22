//
//  RemoteWipeSharedSurfacesTests.swift
//  YalaTests
//
//  Ticket `after-session-redesign-review-widgets-siri-applepay-and-web-copy`: tras el vaciado del dueño desde otro
//  dispositivo, el widget, el snapshot de Siri y los avisos programados seguían enseñando sus datos.
//
//  Cuatro suites, porque el receptor tiene dos ramas y ninguna de las dos se puede invocar desde un test (son
//  funciones `private` de `ContentView`, ver `remote-wipe-receiver-has-no-behaviour-test`):
//    · la rama de la SEÑAL, por su camino real (`DataWipeService.wipeLocallyForRemoteWipeSignal`) contra un store en
//      disco y el App Group del host: es la que sale ROJA con el código de antes (el snapshot de Siri sobrevivía);
//    · la rama de «Empezar de cero», por su helper con stores aislados y un centro de avisos de mentira;
//    · el cableado de las dos ramas a sus limpiezas, por source-scan (lo único que alcanza a la vista);
//    · la invitación del widget en una sesión solo grupos: la publicación del eje y su espejo en el target del widget.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Rama de la señal: el borrado real

@Suite("Vaciado remoto · la señal deja vacío el snapshot de Siri", .serialized, .wipeAppGroupMirrorIsolated)
@MainActor
struct RemoteWipeSignalSurfacesTests {

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "RWS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "RWS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "RWS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        // Sin autosave: un guardado por temporizador DESPUÉS de borrar la carpeta tumba el proceso de tests (molde de
        // `RemoteWipeCutBehaviourTests`).
        context.autosaveEnabled = false
        return context
    }

    /// El borrado resetea las preferencias de `.standard` (el host de test es la app): se restauran al salir. El App
    /// Group lo cubren el trait de la suite (snapshot de Siri) y `TestProcessGuard` (snapshot del widget).
    private func withStandardRestored(_ body: () throws -> Void) rethrows {
        let standard = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.yala.app"
        let snapshot = standard.persistentDomain(forName: domain) ?? [:]
        defer { standard.setPersistentDomain(snapshot, forName: domain) }
        try body()
    }

    @Test func tarde_laSenalVaciaElSnapshotDeSiri() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemoteWipeSurfaces-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: dir)
            } catch {
                #if DEBUG
                print("RemoteWipeSurfacesTests: cleanup: \(error)")
                #endif
            }
        }
        let context = try makeContext(dir)

        // Lo que dejó el dueño: sus subcategorías en el snapshot de Siri.
        SiriIntentContextCache.write(SiriIntentContext(
            expenseSubcategories: ["Gimnasio de Ana"], incomeSubcategories: ["Sueldo de Ana"],
            defaultCurrency: "PEN", hasRealAccount: true))
        // Control del escenario: con el snapshot vacío desde el principio el caso no probaría nada.
        #expect(SiriIntentContextCache.read() != nil)

        try withStandardRestored {
            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: context, signaledAt: Date.now.addingTimeInterval(-3600), fleetStartedOver: false,
                rescheduleReminders: { _ in })
        }

        #expect(SiriIntentContextCache.read() == nil, "Siri sigue ofreciendo las subcategorías del dueño.")
        // El snapshot del widget NO se afirma aquí, aunque esta rama también lo vacía: `widget_data_cache` lo
        // reescriben los ViewModels de otras suites que corren en paralelo, y la aserción daría rojos sueltos. Lo
        // fija `RemoteWipeSurfacesWiringTests.elBorradoVaciaElSnapshotDeSiriJuntoAlDelWidget`.
    }
}

// MARK: - Rama «Empezar de cero»: el helper

@Suite("Vaciado remoto · «Empezar de cero» limpia lo que el espejo no alcanza")
@MainActor
struct RemoteWipeStartFreshSurfacesTests {

    /// Un centro de avisos de mentira: lo único que la purga le pide es retirar TODO lo programado.
    private final class FakeNotificationCenter {
        var pending: Set<String>
        init(pending: Set<String>) { self.pending = pending }
        func removeAllPending() { pending.removeAll() }
    }

    private let todayKey = ScheduledPaymentNotificationTracker.summaryKeyPrefix + "20261008"
    private let deliveredMark = ScheduledPaymentNotificationTracker.keyPrefix + "6F1C9E0A-0000-4000-8000-000000000001_20261008_dayOf"
    private let creditCardMark = ScheduledPaymentNotificationTracker.creditCardKeyPrefix + "6F1C9E0A-0000-4000-8000-000000000002_20261008"

    private func seed(appGroup: UserDefaults, standard: UserDefaults) {
        appGroup.set(Data("saldo-de-ana".utf8), forKey: WidgetDataCache.cacheKey)
        SiriIntentContextCache.write(SiriIntentContext(
            expenseSubcategories: ["Gimnasio de Ana"], incomeSubcategories: [],
            defaultCurrency: "PEN", hasRealAccount: true), defaults: appGroup)
        appGroup.set(true, forKey: WidgetDataCache.groupsOnlySessionKey)
        appGroup.set("otra-cosa", forKey: "ajeno")
        standard.set(Date.now, forKey: todayKey)
        standard.set(true, forKey: deliveredMark)
        standard.set(true, forKey: creditCardMark)
        standard.set(7, forKey: "transactionsSavedCount")
    }

    @Test func dejaVaciosElWidgetSiriYLosAvisos_yNoTocaLoDemas() {
        let appGroup = makeIsolatedDefaults(prefix: "test.rwss.appgroup")
        let standard = makeIsolatedDefaults(prefix: "test.rwss.standard")
        let center = FakeNotificationCenter(pending: ["reminder_1", "spDailySummary_20261008"])
        seed(appGroup: appGroup, standard: standard)

        RemoteWipeSharedSurfaces.purgeAfterMirrorWipe(
            appGroup: appGroup, standard: standard, cancelPendingNotifications: center.removeAllPending)

        #expect(appGroup.data(forKey: WidgetDataCache.cacheKey) == nil)
        #expect(SiriIntentContextCache.read(defaults: appGroup) == nil)
        #expect(center.pending.isEmpty)
        // La marca del resumen se va: con lo programado retirado, mentiría y silenciaría el día.
        #expect(standard.object(forKey: todayKey) == nil)
        // Las de avisos YA ENTREGADOS se quedan: si las filas vuelven (el aviso sale también por un hueco pasajero de
        // CloudKit), barrerlas repetiría los banners del día.
        #expect(standard.bool(forKey: deliveredMark))
        #expect(standard.bool(forKey: creditCardMark))
        // Lo que no es de esta purga se queda: QUIÉN usa el teléfono no cambió, y el resto lo decide otro camino.
        #expect(appGroup.bool(forKey: WidgetDataCache.groupsOnlySessionKey))
        #expect(appGroup.string(forKey: "ajeno") == "otra-cosa")
        #expect(standard.integer(forKey: "transactionsSavedCount") == 7)
    }
}

// MARK: - El cableado de las dos ramas

@Suite("Vaciado remoto · cada rama del receptor cablea su limpieza (source-scan)")
struct RemoteWipeSurfacesWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Líneas sin comentarios enteros, recortadas: el repo explica sus invariantes nombrando el símbolo del que habla.
    private static func codeLines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    /// El cuerpo de una función, de su firma a la llave que la cierra (cuenta llaves; las del código de este repo no
    /// van dentro de strings en estas funciones).
    private static func body(of signature: String, in source: String) throws -> [String] {
        let lines = codeLines(source)
        let start = try #require(lines.firstIndex { $0.contains(signature) }, "No encuentro «\(signature)».")
        var depth = 0
        var opened = false
        var out: [String] = []
        for line in lines[start...] {
            out.append(line)
            depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            if depth > 0 { opened = true }
            if opened && depth == 0 { break }
        }
        return out
    }

    /// «Empezar de cero» llama a la purga, y la rama de la señal NO: allí la limpieza la hace el borrado orquestado, y
    /// cancelar los avisos otra vez correría contra la reprogramación de los que sobreviven al corte.
    @Test func elAvisoLimpia_yLaSenalNoDuplica() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let startFresh = try Self.body(of: "private func startFreshAfterRemoteWipeNotice()", in: src)
        #expect(startFresh.contains("RemoteWipeSharedSurfaces.purgeAfterMirrorWipe()"))
        let signal = try Self.body(of: "private func handleRemoteWipeSignal(", in: src)
        #expect(signal.count > 5)
        #expect(!signal.contains { $0.contains("RemoteWipeSharedSurfaces") })
        #expect(Self.codeLines(src).filter { $0.contains("RemoteWipeSharedSurfaces.purgeAfterMirrorWipe()") }.count == 1)
    }

    /// El PASO 3 del borrado vacía los dos snapshots del App Group seguidos: el del widget y el de Siri.
    @Test func elBorradoVaciaElSnapshotDeSiriJuntoAlDelWidget() throws {
        let lines = Self.codeLines(try Self.source("Yala/Utils/DataWipeService.swift"))
        let wipe = try Self.body(of: "static func wipeAllUserData(", in: lines.joined(separator: "\n"))
        let widget = try #require(wipe.firstIndex(of: "WidgetDataCache.clearCache()"))
        #expect(wipe.indices.contains(widget + 1) && wipe[widget + 1] == "SiriIntentContextCache.clear()")
    }

    /// El enlace del widget solo abre la activación en solo grupos; si ya hay vida personal, al Panel.
    @Test func elEnlaceDelWidgetDecideConElEjeVivo() throws {
        let lines = Self.codeLines(try Self.source("Yala/App/AppBootstrapper.swift"))
        let start = try #require(lines.firstIndex(of: "case \"activate-full\":"))
        #expect(Array(lines[(start + 1)...(start + 5)]) == [
            "if sessionState.isGroupsFocusedShell {",
            "RouterEntryGate.shared.submit(.presentFullModeActivation)",
            "} else {",
            "setOrDeferDeepLink(.panel)",
            "}",
        ])
    }

    /// El embudo del eje publica para el widget ANTES del guard del re-lector: el valor cambió igual.
    @Test func elEmbudoDelEjePublicaParaElWidget() throws {
        let lines = Self.codeLines(try Self.source("Yala/App/Models/SessionState.swift"))
        let start = try #require(lines.firstIndex { $0.hasPrefix("var hasPrivateSession: Bool = PrivateSessionMark") })
        #expect(Array(lines[(start + 1)...(start + 5)]) == [
            "didSet {",
            "WidgetDataCache.publishSessionShell(hasPrivateSession: hasPrivateSession)",
            "guard !isRefreshingPrivateSessionMirror else { return }",
            "PrivateSessionMark.set(hasPrivateSession)",
            "}",
        ])
    }
}

// MARK: - La invitación del widget en solo grupos

@Suite("Widget · en una sesión solo grupos invita a activar Yala completo")
@MainActor
struct WidgetGroupsOnlyInviteTests {

    @Test func publica_soloGrupos_yLoRetiraAlActivar() {
        let appGroup = makeIsolatedDefaults(prefix: "test.widget.groupsonly")
        #expect(WidgetDataCache.publishSessionShell(hasPrivateSession: false, in: appGroup))
        #expect(appGroup.object(forKey: WidgetDataCache.groupsOnlySessionKey) as? Bool == true)
        // Sin cambio no reescribe ni recarga las líneas de tiempo.
        #expect(!WidgetDataCache.publishSessionShell(hasPrivateSession: false, in: appGroup))
        #expect(WidgetDataCache.publishSessionShell(hasPrivateSession: true, in: appGroup))
        #expect(appGroup.object(forKey: WidgetDataCache.groupsOnlySessionKey) as? Bool == false)
    }

    /// Vaciar los datos no cambia quién usa el teléfono: el borrado del snapshot no se lleva la clave.
    @Test func vaciarElSnapshotNoTocaLaInvitacion() {
        let appGroup = makeIsolatedDefaults(prefix: "test.widget.groupsonly.clear")
        WidgetDataCache.publishSessionShell(hasPrivateSession: false, in: appGroup)
        appGroup.set(Data("x".utf8), forKey: WidgetDataCache.cacheKey)
        WidgetDataCache.clearCache(in: appGroup)
        #expect(appGroup.data(forKey: WidgetDataCache.cacheKey) == nil)
        #expect(appGroup.bool(forKey: WidgetDataCache.groupsOnlySessionKey))
    }
}

/// El widget es OTRO target y la suite no lo compila (`YalaWidgets` no es miembro de `YalaTests`): la paridad de la
/// clave y el cableado de la vista solo se pueden fijar leyendo el fuente.
@Suite("Widget · invitación solo grupos: espejo y cableado en el target del widget (source-scan)")
struct WidgetGroupsOnlyInviteParityTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test func elLectorUsaLaMismaClave() throws {
        let reader = try Self.code("YalaWidgets/Services/WidgetDataService.swift")
        #expect(reader.contains("static let groupsOnlySessionKey = \"\(WidgetDataCache.groupsOnlySessionKey)\""))
        #expect(reader.contains("sharedDefaults?.bool(forKey: groupsOnlySessionKey) ?? false"))
    }

    /// Los once widgets de datos y los cuatro de la pantalla bloqueada; los de entrada rápida, no.
    @Test func cadaWidgetDeDatosLlevaLaInvitacion() throws {
        let widgets = ["Balance", "Budgets", "CashFlow", "CategoriesPie", "Expense", "LatestRecords", "MonthSummary",
                       "ScheduledPayments", "SubcategoriesPie", "TopCategories", "TopSubcategories"]
        for name in widgets {
            let src = try Self.code("YalaWidgets/Widgets/\(name)Widget.swift")
            #expect(src.contains("\(name)WidgetView(entry: entry)\n.invitesToActivateFullWhenGroupsOnly()\n.containerBackground("),
                    "\(name)Widget no invita en solo grupos.")
        }
        let accessory = try Self.code("YalaWidgets/Widgets/AccessoryWidgets.swift")
        #expect(accessory.components(separatedBy: ".invitesToActivateFullWhenGroupsOnly()\n.containerBackground(.clear, for: .widget)\n}").count - 1 == 4)
        // Ningún `widgetURL` FUERA del modificador: la invitación no podría sustituirlo y quedarían dos enlaces.
        for name in widgets {
            let src = try Self.code("YalaWidgets/Widgets/\(name)Widget.swift")
            #expect(!src.contains(".containerBackground(Color(.secondarySystemGroupedBackground), for: .widget)\n.widgetURL("))
        }
        #expect(!(try Self.code("YalaWidgets/Widgets/QuickEntryWidgets.swift")).contains("invitesToActivateFullWhenGroupsOnly"))
    }

    @Test func laInvitacionLlevaAActivarYalaCompleto() throws {
        let view = try Self.code("YalaWidgets/Views/GroupsOnlyInviteView.swift")
        #expect(view.contains("if WidgetDataService.isGroupsOnlySession {\nGroupsOnlyInviteView()\n} else {\ncontent\n}"))
        #expect(view.contains(".widgetURL(WidgetURLHelper.url(for: \"activate-full\"))"))
    }
}
