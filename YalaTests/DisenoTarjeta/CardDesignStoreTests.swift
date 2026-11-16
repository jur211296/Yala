//
//  CardDesignStoreTests.swift
//  YalaTests
//
//  Tarjetas de cuenta personalizables (2026-11-16): cómo se guarda y se lee el diseño de cada cuenta en la preferencia
//  sincronizada `accountCardDesigns`, el diseño por defecto y que la preferencia viaje por el canal de siempre, sin campo
//  nuevo en ningún esquema.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Diseño de tarjeta · guardar y leer por cuenta")
struct CardDesignStoreTests {

    private let viajes = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let ahorro = UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!

    private var aurora: CardDesign {
        CardDesign(templateID: "aurora", pattern: .grid, iconName: "airplane", showsChip: true, lastFour: "1256")
    }

    // MARK: - Diseño por defecto

    @Test("Por defecto: «Tu color», patrón según el tipo y chip solo en las cuentas con tarjeta")
    func defaultDesignByType() {
        for type in AccountType.allCases {
            let design = CardDesignLogic.defaultDesign(type: type)
            #expect(design.templateID == CardTemplateCatalog.accountColorID)
            #expect(design.colorHex == nil && design.pattern == nil && design.iconName == nil && design.lastFour == nil)
        }
        #expect(CardDesignLogic.defaultDesign(type: .creditCard).showsChip)
        #expect(CardDesignLogic.defaultDesign(type: .checking).showsChip)
        #expect(CardDesignLogic.defaultDesign(type: .general).showsChip)
        #expect(!CardDesignLogic.defaultDesign(type: .savings).showsChip)
        #expect(!CardDesignLogic.defaultDesign(type: .cash).showsChip)
        #expect(CardDesignLogic.defaultPattern(type: .creditCard) == .grid)
        #expect(CardDesignLogic.defaultPattern(type: .savings) == .waves)
    }

    @Test("El diseño por defecto sale del color de la cuenta: nadie ve un cambio de color al actualizar")
    func defaultLookUsesTheAccountColor() {
        let look = CardLookLogic.look(
            for: CardDesignLogic.defaultDesign(type: .checking), type: .checking,
            accountColorHex: "#4CB963", accountIconName: "building.columns.fill")
        let green = CardRGB(hex: "#4CB963")!
        // El tono del medio de la receta «vivid» es el color de la cuenta, salvo el ajuste de contraste.
        let middle = look.stops[1]
        #expect(abs(middle.green - green.green) < 0.35 && middle.green > middle.red && middle.green > middle.blue,
                "La tarjeta por defecto no conserva el verde de la cuenta.")
        #expect(look.iconName == "building.columns.fill")
        #expect(look.pattern == .lines)
        #expect(look.showsChip)
    }

    @Test("Una cuenta sin diseño guardado lee el de por defecto de su tipo")
    func missingEntryReadsTheDefault() {
        #expect(CardDesignLogic.design(for: viajes, type: .savings, in: "") == CardDesignLogic.defaultDesign(type: .savings))
        let stored = CardDesignLogic.setting(aurora, for: ahorro, type: .creditCard, in: "")
        #expect(CardDesignLogic.design(for: viajes, type: .cash, in: stored) == CardDesignLogic.defaultDesign(type: .cash))
    }

    // MARK: - Guardar y leer

    @Test("Guardar y leer el diseño de una cuenta lo devuelve igual, y no toca el de otra")
    func roundTripPerAccount() {
        var stored = CardDesignLogic.setting(aurora, for: viajes, type: .creditCard, in: "")
        #expect(CardDesignLogic.design(for: viajes, type: .creditCard, in: stored) == aurora)

        let verde = CardDesign(templateID: "forest", colorHex: "#4cb963", pattern: .waves, showsChip: false)
        stored = CardDesignLogic.setting(verde, for: ahorro, type: .savings, in: stored)
        #expect(CardDesignLogic.design(for: viajes, type: .creditCard, in: stored) == aurora)
        let readBack = CardDesignLogic.design(for: ahorro, type: .savings, in: stored)
        #expect(readBack.templateID == "forest" && readBack.pattern == .waves && !readBack.showsChip)
        #expect(readBack.colorHex == "#4CB963", "El color se guarda normalizado.")
    }

    @Test("Un diseño igual al de por defecto se retira: la cuenta vuelve a seguir su color y su tipo")
    func defaultDesignIsNotStored() {
        let stored = CardDesignLogic.setting(aurora, for: viajes, type: .creditCard, in: "")
        let back = CardDesignLogic.setting(CardDesignLogic.defaultDesign(type: .creditCard), for: viajes,
                                           type: .creditCard, in: stored)
        #expect(back == "")
        #expect(CardDesignLogic.removing(viajes, in: stored) == "")
    }

    @Test("El mismo mapa da siempre el mismo texto (la sincronización no ve cambios falsos)")
    func encodingIsDeterministic() {
        let a = CardDesignLogic.setting(aurora, for: viajes, type: .creditCard, in: "")
        let both = CardDesignLogic.setting(aurora, for: ahorro, type: .creditCard, in: a)
        let other = CardDesignLogic.setting(aurora, for: viajes, type: .creditCard,
                                            in: CardDesignLogic.setting(aurora, for: ahorro, type: .creditCard, in: ""))
        #expect(both == other)
        #expect(CardDesignLogic.encode(CardDesignLogic.decode(both)) == both)
    }

    @Test("Lo ilegible se ignora sin perder lo demás: JSON roto, plantilla o patrón desconocidos")
    func tolerantReading() throws {
        #expect(CardDesignLogic.decode("no es json").isEmpty)
        #expect(CardDesignLogic.decode("[1,2]").isEmpty)
        let raw = """
        {"\(viajes.uuidString)":{"t":"plantilla-del-futuro","p":"espiral","ch":true,"d":"12a4","c":"verde"},\
        "no-es-uuid":{"t":"gold","ch":false},\
        "\(ahorro.uuidString)":{"sin":"plantilla"}}
        """
        let designs = CardDesignLogic.decode(raw)
        #expect(designs.count == 1, "Solo la entrada con id y plantilla válidos se lee.")
        let read = try #require(designs[viajes])
        #expect(read.pattern == nil, "Un patrón desconocido deja mandar a la plantilla.")
        #expect(read.lastFour == nil, "Unos dígitos que no son 4 números no se leen.")
        #expect(read.colorHex == nil)
        // La plantilla desconocida se pinta como «Tu color».
        #expect(CardTemplateCatalog.template(id: "plantilla-del-futuro").id == CardTemplateCatalog.accountColorID)
    }

    // MARK: - La preferencia viaja por el canal de siempre

    @Test("La preferencia es una key sincronizada más, con «vacío» como estado válido")
    func syncedPreferenceKey() {
        #expect(PrefSyncKey(rawValue: "accountCardDesigns") == .accountCardDesigns)
        #expect(PrefSyncKey.accountCardDesigns.family == .panelPresenceEmptyValid)
        #expect(AppPreferences.Keys.accountCardDesigns == PrefSyncKey.accountCardDesigns.rawValue)
    }

    @Test("AppPreferences guarda y relee el diseño en su almacén")
    func appPreferencesPersistsTheDesigns() throws {
        let defaults = try #require(testDefaults(suiteName: "CardDesignStoreTests.\(UUID().uuidString)"))
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.accountCardDesigns == "")
        let stored = CardDesignLogic.setting(aurora, for: viajes, type: .creditCard, in: prefs.accountCardDesigns)
        prefs.accountCardDesigns = stored
        #expect(defaults.string(forKey: AppPreferences.Keys.accountCardDesigns) == stored)

        let reopened = AppPreferences(defaults: defaults)
        #expect(CardDesignLogic.design(for: viajes, type: .creditCard, in: reopened.accountCardDesigns) == aurora)
    }

    @Test("Sin campo nuevo en ningún esquema: el modelo de cuenta no tiene nada de diseño")
    func noSchemaChange() throws {
        let source = try String(contentsOf: Self.repoFile("Yala/Models/Account.swift"), encoding: .utf8)
        for word in ["cardDesign", "lastFour", "templateID"] {
            #expect(!source.contains(word), "El modelo de cuenta ganó «\(word)»: eso es un campo de CloudKit y Supabase.")
        }
    }

    @Test("«Vaciar mis datos» borra también los diseños")
    func wipeRemovesTheDesigns() throws {
        let source = try String(contentsOf: Self.repoFile("Yala/Utils/DataWipeService.swift"), encoding: .utf8)
        #expect(source.contains("removeObject(forKey: AppPreferences.Keys.accountCardDesigns)"))
    }

    static func repoFile(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(relative)
    }
}
