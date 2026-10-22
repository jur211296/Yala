//
//  WidgetDTOParityTests.swift
//  YalaTests
//
//  **Las dos copias del DTO del App Group decodifican lo mismo.**
//
//  El snapshot de los widgets se declara DOS veces: la app lo escribe con
//  `Yala/Services/WidgetDataCache.swift` y la extensión lo lee con
//  `YalaWidgets/Services/WidgetDataService.swift`. Viaja como una struct Codable entera y sin
//  versionado, así que una clave que el LECTOR exige y el ESCRITOR no garantiza lanza
//  `keyNotFound`, `loadSnapshot()` devuelve `nil` y todos los widgets de la pantalla de inicio se
//  quedan a cero hasta que la persona abra la app.
//
//  `YalaTests` compila `Yala` y no `YalaWidgets` (`project.pbxproj`), así que la copia del lector no
//  se puede instanciar aquí. Este fichero la mide de las dos formas que sí están a mano:
//
//  1. **Estructural** — extrae las propiedades guardadas de cada struct en los dos fuentes y exige
//     las mismas claves, el mismo tipo base y que nada obligatorio en el lector sea opcional (o
//     falte) en el escritor. Opcional en el lector y obligatorio en el escritor sí vale: es como se
//     añade un campo sin romper snapshots viejos.
//  2. **Round-trip** — el escritor REAL codifica un snapshot con todos sus opcionales a `nil` (el
//     peor caso: `JSONEncoder` omite esas claves) y se recorre el JSON con el esquema del lector,
//     comprobando cada clave obligatoria a cada nivel. Es lo que haría su `JSONDecoder`.
//
//  La retrocompatibilidad con snapshots VIEJOS ya escritos en disco es otra pregunta y la vigila
//  `WidgetSnapshotLegacyDecodeTests`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Widget · las dos copias del DTO decodifican igual")
@MainActor
struct WidgetDTOParityTests {

    /// Los structs que viajan dentro de `WidgetDataSnapshot`, raíz incluida.
    static let dtoNames = [
        "WidgetTransaction", "WidgetBudget", "WidgetScheduledPayment", "WidgetTrendPoint",
        "WidgetTrendData", "WidgetAccountBalance", "WidgetCategory", "WidgetSubcategory",
        "WidgetCashFlowPoint", "WidgetPeriodSummary", "WidgetDataSnapshot"
    ]

    static let writerPath = "Yala/Services/WidgetDataCache.swift"
    static let readerPath = "YalaWidgets/Services/WidgetDataService.swift"

    // MARK: - 1. Estructural

    @Test func lasDosCopiasDeclaranLosMismosStructs() throws {
        let writer = try Self.schema(Self.writerPath)
        let reader = try Self.schema(Self.readerPath)
        for name in Self.dtoNames {
            #expect(writer[name] != nil, "El escritor no declara \(name) — ¿se renombró?")
            #expect(reader[name] != nil, "El lector no declara \(name) — ¿se renombró?")
        }
    }

    @Test(arguments: dtoNames)
    func mismasClavesYMismoTipo(_ name: String) throws {
        let writer = try #require(try Self.schema(Self.writerPath)[name])
        let reader = try #require(try Self.schema(Self.readerPath)[name])
        #expect(!writer.isEmpty, "\(name): el parser no sacó ninguna propiedad del escritor")

        #expect(Set(writer.keys) == Set(reader.keys), """
            \(name): las claves divergen. Solo en el escritor: \(Set(writer.keys).subtracting(reader.keys).sorted()). \
            Solo en el lector: \(Set(reader.keys).subtracting(writer.keys).sorted()). Un campo nuevo va \
            en las DOS copias, y en el lector opcional.
            """)

        for (key, readerField) in reader {
            guard let writerField = writer[key] else { continue }
            #expect(writerField.base == readerField.base, """
                \(name).\(key): el escritor lo codifica como \(writerField.base) y el lector lo \
                decodifica como \(readerField.base).
                """)
            if !readerField.isOptional {
                #expect(!writerField.isOptional, """
                    \(name).\(key): el lector lo EXIGE y el escritor puede no mandarlo (es opcional allí). \
                    Un `nil` lo omite del JSON y el lector lanza keyNotFound: todos los widgets a cero.
                    """)
            }
        }
    }

    // MARK: - 2. Round-trip con el escritor real

    @Test func elSnapshotDelEscritorTraeCadaClaveQueElLectorExige() throws {
        let data = try JSONEncoder().encode(Self.worstCaseSnapshot())
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let reader = try Self.schema(Self.readerPath)

        var missing: [String] = []
        var visited: Set<String> = []
        Self.walk(json, as: "WidgetDataSnapshot", path: "snapshot", reader: reader,
                  missing: &missing, visited: &visited)

        #expect(missing.isEmpty, """
            El lector exige claves que el escritor no manda: \(missing). Ese snapshot no decodifica \
            en la extensión y los widgets se quedan a cero.
            """)
        #expect(visited == Set(Self.dtoNames), """
            El recorrido no pasó por \(Set(Self.dtoNames).subtracting(visited).sorted()): algún array \
            del snapshot de prueba va vacío y deja sin comprobar su struct.
            """)
    }

    /// Recorre `object` como si lo decodificara el lector: cada clave obligatoria de `type` tiene que
    /// estar, y las que apuntan a otro DTO se recorren a su vez.
    private static func walk(
        _ object: [String: Any], as type: String, path: String,
        reader: [String: [String: Field]], missing: inout [String], visited: inout Set<String>
    ) {
        guard let fields = reader[type] else { return }
        visited.insert(type)
        for (key, field) in fields.sorted(by: { $0.key < $1.key }) {
            guard let value = object[key], !(value is NSNull) else {
                if !field.isOptional { missing.append("\(path).\(key)") }
                continue
            }
            let base = field.base
            if reader[base] != nil, let child = value as? [String: Any] {
                walk(child, as: base, path: "\(path).\(key)", reader: reader, missing: &missing, visited: &visited)
            } else if base.hasPrefix("["), base.hasSuffix("]") {
                let inner = String(base.dropFirst().dropLast())
                if inner.hasPrefix("String:") {
                    let elementType = String(inner.dropFirst("String:".count))
                    for (dictKey, element) in (value as? [String: Any]) ?? [:] {
                        guard let child = element as? [String: Any] else { continue }
                        walk(child, as: elementType, path: "\(path).\(key)[\(dictKey)]", reader: reader,
                             missing: &missing, visited: &visited)
                    }
                } else if reader[inner] != nil {
                    for (index, element) in ((value as? [Any]) ?? []).enumerated() {
                        guard let child = element as? [String: Any] else { continue }
                        walk(child, as: inner, path: "\(path).\(key)[\(index)]", reader: reader,
                             missing: &missing, visited: &visited)
                    }
                }
            }
        }
    }

    /// Un snapshot con un elemento de cada tipo y TODOS los opcionales a `nil`.
    private static func worstCaseSnapshot() -> WidgetDataSnapshot {
        let date = Date(timeIntervalSince1970: 0)
        let summary = WidgetPeriodSummary(
            totalIncome: 0, totalExpense: 1, netCashFlow: -1,
            topCategories: [WidgetCategory(id: "c", name: "C", iconName: "i", colorHex: "#000000",
                                           amount: 1, percentage: 100)],
            topSubcategories: [WidgetSubcategory(id: "s", name: "S", categoryName: "C", iconName: nil,
                                                 colorHex: "#000000", amount: 1, percentage: 100)],
            cashFlowPoints: [WidgetCashFlowPoint(date: date, income: 0, expense: 1, net: -1)],
            periodBalance: nil,
            incomeIsApproximate: nil, expenseIsApproximate: nil,
            netCashFlowIsApproximate: nil, periodBalanceIsApproximate: nil
        )
        return WidgetDataSnapshot(
            lastUpdated: date,
            preferredCurrencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            accountBalances: [WidgetAccountBalance(id: "a", name: "A", balance: 0, currencyCode: "PEN",
                                                   isExcludedFromStats: false)],
            totalBalance: 0,
            transactions: [WidgetTransaction(
                id: "t", date: date, amount: -1, currencyCode: "PEN", note: nil, categoryName: nil,
                categoryColor: nil, categoryIcon: nil, subcategoryIcon: nil, subcategoryName: nil,
                isIncome: false, amountInPreferredCurrency: -1, isExchangeRateProvisional: nil
            )],
            budgets: [WidgetBudget(id: "b", name: "B", limitAmount: 1, spentAmount: 0, currencyCode: "PEN",
                                   periodType: "monthly", percentUsed: 0, iconName: "i", colorHex: "#000000")],
            scheduledPayments: [WidgetScheduledPayment(
                id: "p", name: "P", amount: 1, currencyCode: "PEN", nextDueDate: date, isOverdue: false,
                paymentCategory: "recurring", isIncome: false, iconName: "i", colorHex: "#000000"
            )],
            trendData: WidgetTrendData(
                dailyPoints: [WidgetTrendPoint(date: date, balance: 0)], weeklyPoints: [], monthlyPoints: []
            ),
            thisMonthSummary: summary,
            allTimeSummary: summary,
            periodSummaries: ["thisMonth": summary]
        )
    }

    // MARK: - Parser

    struct Field: Equatable {
        let base: String
        let isOptional: Bool
    }

    /// `[struct: [propiedad: tipo]]` de los DTO de un fuente. Solo propiedades GUARDADAS a nivel
    /// del struct: se saltan `static`, las computadas (`{` al final) y lo anidado en `init`.
    static func schema(_ relativePath: String) throws -> [String: [String: Field]] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
        let lines = source.components(separatedBy: .newlines)

        var result: [String: [String: Field]] = [:]
        var current: String?
        var depth = 0
        let header = try Regex(#"^struct\s+(\w+)\s*:\s*Codable\s*\{"#)
        let property = try Regex(#"^\s*(?:let|var)\s+(\w+)\s*:\s*([^=/{]+?)\s*(?:=.*)?(?://.*)?$"#)

        for line in lines {
            if current == nil {
                if let match = line.firstMatch(of: header),
                   let name = match.output[1].substring.map(String.init),
                   dtoNames.contains(name) {
                    current = name
                    result[name] = [:]
                    depth = 1
                }
                continue
            }
            guard let name = current else { continue }
            let code = line.components(separatedBy: "//").first ?? line
            if depth == 1, !code.contains("static"), !code.trimmingCharacters(in: .whitespaces).hasSuffix("{"),
               let match = code.firstMatch(of: property),
               let key = match.output[1].substring.map(String.init),
               let rawType = match.output[2].substring.map(String.init) {
                let type = rawType.replacingOccurrences(of: " ", with: "")
                let isOptional = type.hasSuffix("?")
                result[name]?[key] = Field(base: isOptional ? String(type.dropLast()) : type, isOptional: isOptional)
            }
            depth += code.filter { $0 == "{" }.count - code.filter { $0 == "}" }.count
            if depth <= 0 { current = nil }
        }
        return result
    }
}
