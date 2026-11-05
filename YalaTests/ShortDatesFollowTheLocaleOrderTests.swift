//
//  ShortDatesFollowTheLocaleOrderTests.swift
//  YalaTests
//
//  Card «Las fechas cortas salen "13 Oct" también en inglés de EE. UU.» (lote 12.4). ~40 sitios fijaban el orden con
//  `dateFormat = "d MMM"` (y «d MMM yyyy», «MMM yy», «MMMM yyyy»…) en vez de pedir una plantilla, que da el orden y las
//  preposiciones de cada idioma. Ahora piden `setLocalizedDateFormatFromTemplate`, con el `locale` puesto ANTES (la
//  plantilla se resuelve con el idioma que tenga el formatter en ese instante).
//

import Foundation
import Testing

struct ShortDatesFollowTheLocaleOrderTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// Formatos fijos de día y mes que el lote retiró. Se buscan en el código de la app y de los widgets.
    private static let fixedPatterns = [
        #"dateFormat = "d MMM"#, #"dateFormat = "MMM yy"#, #"dateFormat = "EEE d MMM"#, #"dateFormat = "MMMM yyyy""#,
        #"dateFormat = "MMM yyyy""#,
    ]

    /// Los que se quedan, con su porqué.
    /// - `PreviousPeriodHelper`: el «vs oct 2026» se capitaliza palabra a palabra, y con la plantilla de pt
    ///   («out. de 2026») saldría «Out De 2026». Los compactos «vs 29dic-4ene» son de diseño y ya no son `d MMM`.
    /// - `FullFinancialContextBuilder`: etiqueta para el prompt de Yala IA, no la ve el usuario.
    private static let allowed: Set<String> = [
        "Yala/App/Logic/Helpers/PreviousPeriodHelper.swift",
        "Yala/Services/Chat/FullFinancialContextBuilder.swift",
    ]

    private func swiftFiles(under folder: String) -> [URL] {
        let root = Self.repoRoot.appendingPathComponent(folder)
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    @Test func noFixedDayMonthOrderLeft() throws {
        let files = swiftFiles(under: "Yala") + swiftFiles(under: "YalaWidgets")
        #expect(files.count > 500, "no encontré el código: \(files.count) ficheros")
        var offenders: [String] = []
        for url in files {
            let rel = String(url.path.dropFirst(Self.repoRoot.path.count + 1))
            if Self.allowed.contains(rel) { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where Self.fixedPatterns.contains(where: { line.contains($0) }) {
                offenders.append("\(rel):\(n + 1)")
            }
        }
        #expect(offenders.isEmpty, "Formato fijo de día y mes (usa setLocalizedDateFormatFromTemplate): \(offenders)")
    }

    @Test func templateNeedsTheLocaleFirst() throws {
        // Un `locale` puesto DESPUÉS de la plantilla no la cambia: el formato ya quedó resuelto con el otro idioma.
        let files = swiftFiles(under: "Yala") + swiftFiles(under: "YalaWidgets")
        var offenders: [String] = []
        for url in files {
            let rel = String(url.path.dropFirst(Self.repoRoot.path.count + 1))
            let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
            for i in lines.indices.dropLast() {
                guard let range = lines[i].range(of: ".setLocalizedDateFormatFromTemplate(") else { continue }
                let receiver = lines[i][..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                if lines[i + 1].trimmingCharacters(in: .whitespaces).hasPrefix("\(receiver).locale = ") {
                    offenders.append("\(rel):\(i + 1)")
                }
            }
        }
        #expect(offenders.isEmpty, "locale después de la plantilla: \(offenders)")
    }

    /// Lo que la plantilla da en cada idioma, para que el arreglo no dependa de una suposición.
    @Test(arguments: [
        ("en_US", "dMMM", "Oct 13"),
        ("es_419", "dMMMy", "13 oct 2026"),
        ("en_US", "EEEdMMM", "Tue, Oct 13"),
        ("en_GB", "dMMM", "13 Oct"),
        ("en_US", "dMMMy", "Oct 13, 2026"),
        ("pt_BR", "MMMMy", "outubro de 2026"),
        ("es_419", "MMMMy", "octubre de 2026"),
    ])
    func templateGivesEachLocaleItsOrder(_ locale: String, _ template: String, _ expected: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 12)))
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: locale)
        f.setLocalizedDateFormatFromTemplate(template)
        #expect(f.string(from: date) == expected, "\(locale) \(template): «\(f.string(from: date))»")
    }
}
