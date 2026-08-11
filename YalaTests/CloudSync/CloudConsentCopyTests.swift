//
//  CloudConsentCopyTests.swift
//  YalaTests
//
//  W3 (decisión del owner 2026-08-11, puntos 12-14 de MODO-NUBE-REVISION-FLUJOS-NOTAS): el consent del
//  Modo Nube deja de leerse como una alerta grave y pasa a leerse como una lectura de términos —título
//  nuevo, sin iconografía de alarma y SIETE bullets podados a TRES + un pie.
//
//  Lo que hay que impedir es que la poda pierda el rastro de lo que se retiró, así que el peso lo cargan
//  dos pines y no el conteo de bullets: (a) el HORIZONTE del resumen que viaja al proveedor de IA sigue
//  dicho en el consent de IA —era el punto 4 y ahí es donde se movió— y además CASA con el código que lo
//  produce; (b) las keys retiradas no pueden reaparecer por copia de otro flujo.
//
//  Lo que NO se finge testear: que un texto «suene a términos y no a alerta» no es unit-asertable en 16
//  idiomas. Eso es revisión de copy contra BRAND-VOICE, y decirlo aquí es más honesto que colar una
//  aserción que pasaría por el motivo equivocado.
//

import Foundation
import Testing

@testable import Yala

@Suite("W3 · el consent es una lectura de términos, no una alerta")
struct CloudConsentCopyTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Solo el CÓDIGO: los docblocks nombran a propósito lo retirado (el `hand.raised.fill`, los
    /// `point1…point7`), así que un `!contains` sobre el fichero crudo se rompería al documentar el
    /// invariante — la trampa que ya cazaron `WelcomeHeroReentryTests` y el escáner de `TestProcessGuard`.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let viewPath = "Yala/App/Views/Settings/CloudConsentView.swift"
    private static let builderPath = "Yala/Services/Chat/FullFinancialContextBuilder.swift"

    // MARK: - El contrato versionado

    /// El bump es lo que separa «se cambió la redacción» de «se cambió el contrato», y aquí cambió el
    /// contrato: dos de los siete puntos salieron de esta pantalla. Fijar el número obliga a que una poda
    /// futura toque los DOS sitios (el texto y la versión) en vez de solo el texto.
    @Test("la versión del contrato subió con la poda")
    func consentTextVersion_wasBumpedWithThePruning() {
        #expect(CloudConsentText.version == 2)
    }

    // MARK: - La pantalla

    @Test("la pantalla pinta tres puntos y un pie, y ninguno es un bullet numerado viejo")
    func view_rendersThreePointsAndAFooter() throws {
        let src = try Self.code(Self.viewPath)
        for key in ["pointServers", "pointPhotos", "pointAccess", "footer"] {
            #expect(src.contains("Consent.\(key)"), "la vista dejó de pintar '\(key)'")
        }
        for old in (1...7).map({ "Consent.point\($0)" }) {
            #expect(!src.contains(old), "'\(old)' volvió a la pantalla: la poda se deshizo")
        }
    }

    /// El punto 12 del owner es sobre el TONO, y la mitad visual de ese tono son los iconos: una mano de
    /// alto en el header y un `info.circle.fill` por bullet leen como advertencia por sí solos.
    @Test("no hay iconografía de alarma en el consent")
    func view_hasNoAlarmIconography() throws {
        let src = try Self.code(Self.viewPath)
        #expect(!src.contains("hand.raised"))
        #expect(!src.contains("info.circle"))
        #expect(!src.contains("exclamationmark"))
    }

    /// La MISMA pantalla sirve al alta born-cloud, a la migración desde iCloud y a la re-entrada. El
    /// `path` existe solo para separar las tres series en el dashboard: en cuanto decida COPY, el texto
    /// podado deja de estar verificado en los tres contextos por construcción y hay que probarlos uno a uno.
    @Test("el contexto no ramifica el texto: `path` solo alimenta la telemetría")
    func consentPath_doesNotBranchTheCopy() throws {
        let src = try Self.code(Self.viewPath)
        #expect(src.contains("MetricsService.cloudConsentAccepted(path: path.rawValue)"))
        // Su declaración y la llamada de telemetría. Una tercera línea que lo mencione es una
        // ramificación, y con ella el copy deja de estar verificado en los tres contextos.
        let lines = src.split(separator: "\n").filter { $0.contains("path") }
        #expect(lines.count == 2, "el `path` aparece en \(lines.count) líneas: ¿está decidiendo copy?")
    }

    // MARK: - Lo que se movió (punto 4 → consent de IA)

    /// El punto 4 decía que el chat manda un resumen «hasta unos 13 meses» al proveedor de IA. El consent
    /// de IA ya describía el resumen y le faltaba el horizonte; sin esta aserción, la poda se lo lleva por
    /// delante en silencio y el usuario acepta un contrato con menos información que antes.
    @Test("el consent de IA dice el horizonte del resumen, en los 16 locales")
    func aiConsent_statesTheSummaryHorizon() {
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            let message = strings["aiConsent.chatMessage"] ?? ""
            #expect(message.contains("13"),
                    "'aiConsent.chatMessage' perdió el horizonte de 13 meses en \(locale.code)")
        }
        #expect(scanned == 16, "se esperaban 16 locales con strings, se leyeron \(scanned)")
    }

    /// Y el horizonte del copy CASA con el que produce el código: si alguien mueve la ventana del builder,
    /// las 16 traducciones se quedan mintiendo sobre lo que de verdad sale del dispositivo.
    @Test("el horizonte del copy es el que el builder recorta de verdad")
    func aiConsentHorizon_matchesTheContextBuilder() throws {
        let src = try Self.code(Self.builderPath)
        #expect(src.contains("byAdding: .month, value: -13"),
                "el builder ya no recorta a 13 meses: actualiza el copy del consent de IA en los 16 locales")
    }

    // MARK: - Las keys

    /// Sin el conteo de locales esto pasaría en verde con el escáner roto o con las `.lproj` fuera del
    /// bundle — la familia de «Executed 0 tests».
    @Test("las keys podadas no existen en ninguno de los 16 locales")
    func prunedKeys_areGoneFromEveryLocale() {
        let retired = (1...7).map { "storage.consent.point\($0)" }
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            for key in retired {
                #expect(strings[key] == nil, "'\(key)' reapareció en \(locale.code)")
            }
        }
        #expect(scanned == 16, "se esperaban 16 locales con strings, se leyeron \(scanned)")
    }

    @Test("las cuatro keys nuevas existen y tienen texto en los 16 locales")
    func newKeys_haveContentInEveryLocale() {
        let added = [
            "storage.consent.title",
            "storage.consent.pointServers",
            "storage.consent.pointPhotos",
            "storage.consent.pointAccess",
            "storage.consent.footer",
        ]
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            for key in added {
                let value = strings[key] ?? ""
                #expect(!value.isEmpty, "'\(key)' falta o está vacía en \(locale.code)")
            }
        }
        #expect(scanned == 16, "se esperaban 16 locales con strings, se leyeron \(scanned)")
    }
}
