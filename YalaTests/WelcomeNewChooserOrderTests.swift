//
//  WelcomeNewChooserOrderTests.swift
//  YalaTests
//
//  W2 (decisiones del owner 2026-08-11, puntos 6 y 10 de MODO-NUBE-REVISION-FLUJOS-NOTAS):
//  en el sub-chooser de "Soy nuevo" la card de NUBE va primero, y la renuncia inline
//  (`welcome.new.cloudWarning`) se retira.
//
//  Las dos mitades hacen falta y ninguna cubre a la otra: el orden es una función pura y
//  se aserja como comportamiento; que la VISTA la use —y que no haya quedado un `ForEach`
//  sobre `options` a secas— solo lo ve un source-scan, porque un `displayOrder` perfecto
//  con la vista ignorándolo pasa en verde (familia `AttestWiringTests`).
//

import Foundation
import Testing

@testable import Yala

@Suite("W2 · el sub-chooser pinta la nube primero")
struct WelcomeNewChooserOrderTests {

    @Test("con las dos cards visibles, la nube va primero y la privada después")
    func bothOptions_cloudComesFirst() {
        // La ENTRADA es la que produce hoy la lógica de visibilidad, que W2 dejó intacta a
        // propósito: si el orden dependiera de ella, este test pasaría por accidente.
        let visibles = WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true)
        #expect(visibles == [.privateAccount, .cloudAccount], "la lógica sigue emitiendo su orden histórico")
        #expect(WelcomeNewChooserView.displayOrder(visibles) == [.cloudAccount, .privateAccount])
    }

    @Test("el orden no inventa cards: solo reordena las visibles")
    func displayOrder_onlyReordersWhatItReceives() {
        #expect(WelcomeNewChooserView.displayOrder([.privateAccount]) == [.privateAccount])
        #expect(WelcomeNewChooserView.displayOrder([.cloudAccount]) == [.cloudAccount])
        #expect(WelcomeNewChooserView.displayOrder([]).isEmpty)
    }

    /// El bypass del container mira `visibleNewOptions.count`, no este orden — reordenar la
    /// presentación no puede convertir un bypass en pantalla ni al revés.
    @Test("el bypass de una sola opción sigue siendo bypass tras reordenar")
    func singleOption_stillBypasses() {
        let single = WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: false)
        #expect(WelcomeNewChooserView.displayOrder(single).count == 1)
        #expect(WelcomeAccountChoiceLogic.bypass(single) == .privateAccount)
    }
}

@Suite("W2 · sub-chooser · cableado y copy (source-scan)")
struct WelcomeNewChooserCopyWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Solo el CÓDIGO: el docblock de la vista nombra a propósito lo retirado y las tres
    /// supersesiones del §k.6, así que un `!contains` sobre el fichero crudo se rompería al
    /// documentar el invariante.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let viewPath = "Yala/App/Views/Onboarding/WelcomeNewChooserView.swift"

    @Test("la vista pinta por `displayOrder`, no por el array que recibe")
    func view_rendersThroughDisplayOrder() throws {
        let src = try Self.code(Self.viewPath)
        #expect(src.contains("ForEach(Self.displayOrder(options)"),
                "un `ForEach(options)` a secas devuelve el orden de la lógica y el punto 6 se pierde en silencio")
    }

    @Test("la renuncia inline no vive en la vista ni en la etiqueta de accesibilidad")
    func cloudWarning_isGoneFromTheView() throws {
        let src = try Self.code(Self.viewPath)
        #expect(!src.contains("cloudWarning"))
        // La etiqueta dejó de ramificar por opción: si vuelve un `switch` aquí es que alguien
        // le está contando a VoiceOver algo que la pantalla no dice (pasó con el badge y con
        // la renuncia, en ese orden).
        let label = try #require(src.range(of: "private func accessibilityLabel(for option:"))
        let resto = String(src[label.upperBound...].prefix(220))
        #expect(!resto.contains("switch option"))
    }

    /// Con conteo de locales: sin él, un escáner que no case ningún fichero pasaría en verde.
    @Test("`welcome.new.cloudWarning` está retirada de los 16 locales")
    func cloudWarningKey_isGoneFromEveryLocale() {
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            #expect(strings["welcome.new.cloudWarning"] == nil,
                    "la renuncia inline reapareció en \(locale.code)")
        }
        #expect(scanned == 16, "se esperaban 16 locales con strings, se leyeron \(scanned)")
    }

    /// El punto 4 —«la card de reentrada no debe prometer solo iCloud»— **no es unit-asertable
    /// y no se finge que lo sea**: comprobar que una frase habla de dos mundos exige leerla, y
    /// la palabra «cuenta» cambia en cada uno de los 16 locales. Eso lo cubre la revisión de
    /// copy, no un test.
    ///
    /// Lo que SÍ es verificable en los 16 y es el riesgo REAL de este barrido: que al
    /// des-iCloudizar el cuerpo se cayera la mención de iCloud, dejando sin nombrar la vía por
    /// la que hoy vuelve la mayoría. `iCloud` es marca y se escribe igual en los 16.
    @Test("el cuerpo de «Ya tengo una cuenta» sigue nombrando iCloud en los 16 locales")
    func existingCardBody_stillNamesICloud() {
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard let body = strings["welcome.chooser.optionExisting.body"] else { continue }
            scanned += 1
            #expect(body.contains("iCloud"),
                    "\(locale.code): iCloud sigue siendo una de las dos vías y tiene que nombrarse")
        }
        #expect(scanned == 16, "se esperaban 16 locales con la key, se leyeron \(scanned)")
    }
}
