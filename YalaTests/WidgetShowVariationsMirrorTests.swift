//
//  WidgetShowVariationsMirrorTests.swift
//  YalaTests
//
//  «Comparar con el período anterior» (`AppPreferences.showVariations`) llega a los widgets (S35f1): la app la copia al
//  App Group y los widgets, con ella apagada, no enseñan variaciones. `YalaTests` no compila `YalaWidgets`, así que el
//  lado del widget se fija leyendo su fuente.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct WidgetShowVariationsMirrorTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    private static func isolated() -> UserDefaults {
        let name = "test.showVariations.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func publish_escribeSoloSiCambia() {
        let defaults = Self.isolated()
        #expect(WidgetDataCache.publishShowVariations(false, in: defaults))
        #expect(defaults.object(forKey: WidgetDataCache.showVariationsKey) as? Bool == false)
        #expect(!WidgetDataCache.publishShowVariations(false, in: defaults), "el mismo valor no vuelve a escribir")
        #expect(WidgetDataCache.publishShowVariations(true, in: defaults))
        #expect(defaults.object(forKey: WidgetDataCache.showVariationsKey) as? Bool == true)
    }

    @Test func laClaveEsLaMismaEnLosTresLados() throws {
        #expect(WidgetDataCache.showVariationsKey == AppPreferences.Keys.showVariations)
        #expect(AppPreferences.Keys.showVariations == "showVariations")
        let reader = try Self.source("YalaWidgets/Services/WidgetDataService.swift")
        #expect(reader.contains(#"sharedDefaults?.object(forKey: "showVariations") as? Bool ?? true"#),
                "El widget lee otra clave, o ausente deja de ser «activada».")
    }

    @Test func losDosEscritoresLaCopian() throws {
        let prefs = try Self.source("Yala/App/Services/AppPreferences.swift")
        #expect(prefs.contains("if publishesToSync { WidgetDataCache.mirrorShowVariations(showVariations) }"),
                "Cambiarla en Ajustes no llega a los widgets hasta la próxima foto.")
        let cache = try Self.source("Yala/Services/WidgetDataCache.swift")
        let save = try #require(cache.range(of: "private static func saveSnapshot("))
        #expect(String(cache[save.upperBound...].prefix(1_600)).contains("publishShowVariations(showVariations, in: defaults)"),
                "La foto no la copia: una instalación que la apagó antes de 2.2 no llega nunca a los widgets.")
    }

    @Test func losTresWidgetsConVariacionLaObedecen() throws {
        let expense = try Self.source("YalaWidgets/Widgets/ExpenseWidget.swift")
        #expect(expense.contains("comparison: WidgetDataService.showsVariations"))
        let balance = try Self.source("YalaWidgets/Widgets/BalanceWidget.swift")
        #expect(balance.contains("change: WidgetDataService.showsVariations ? Self.change("))
        let flow = try Self.source("YalaWidgets/Widgets/CashFlowWidget.swift")
        #expect(flow.contains("comparison: isExpensesOnly || !WidgetDataService.showsVariations"))
    }

    @Test func losBorradosSeLaLlevan() throws {
        let wipe = try Self.source("Yala/Utils/DataWipeService.swift")
        #expect(wipe.contains("appGroup.removeObject(forKey: WidgetDataCache.showVariationsKey)"))
    }
}
