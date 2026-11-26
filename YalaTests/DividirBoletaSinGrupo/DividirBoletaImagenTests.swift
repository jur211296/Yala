//
//  DividirBoletaImagenTests.swift
//  YalaTests
//
//  La imagen de «Dividir una boleta»: qué dicen «Solo resumen» y «Con detalle» según quién pagó, y el contraste AA de
//  los colores fijos de los tres diseños (la imagen se ve igual en cualquier teléfono, así que el contraste se mide una
//  vez aquí).
//

import Foundation
import Testing

@testable import Yala

@Suite("Dividir una boleta · imagen")
struct DividirBoletaImagenTests {

    // MARK: - Fixture

    private static let texts = DividirBoletaImageBuilder.Texts(
        owedToOther: "A %@ le deben",
        oneOwesOther: "%1$@ le debe a %2$@",
        paidByTotal: "Pagó %1$@ · total %2$@",
        meName: "Jürgen",
        payerPart: "La parte de %1$@: %2$@",
        everyone: "Entre todos",
        sharedBy: "entre %d",
        footerTitle: "Dividido con Yala",
        footerSubtitle: "Reparte tu cuenta gratis",
        joinNames: { $0.joined(separator: " y ") }
    )

    private static func money(_ cents: Int) -> String { String(format: "S/ %.2f", Double(cents) / 100) }

    private struct Boleta {
        let people: [DividirBoletaPerson]
        let lines: [ReceiptSplitLine]
        var me: DividirBoletaPerson { people[0] }
        func person(_ name: String) -> DividirBoletaPerson { people.first { $0.name == name } ?? people[0] }
    }

    private static func boleta() -> Boleta {
        let me = DividirBoletaPerson(name: "Yo", isMe: true)
        let carla = DividirBoletaPerson(name: "Carla")
        let martin = DividirBoletaPerson(name: "Martín")
        let rocio = DividirBoletaPerson(name: "Rocío")
        let lines = [
            ReceiptSplitLine(description: "Ceviche clásico", amount: 42, kind: .item, assignees: [me.id]),
            ReceiptSplitLine(description: "Lomo saltado", amount: 48, kind: .item, assignees: [martin.id]),
            ReceiptSplitLine(description: "Ají de gallina", amount: 36, kind: .item, assignees: [carla.id]),
            ReceiptSplitLine(description: "Arroz con mariscos", amount: 45, kind: .item, assignees: [rocio.id]),
            ReceiptSplitLine(description: "Chicha morada 1 L", amount: 24, kind: .item),
            ReceiptSplitLine(description: "Gaseosa 500 ml ×2", amount: 14, kind: .item, assignees: [carla.id, martin.id]),
            ReceiptSplitLine(description: "Leche de tigre para compartir", amount: 28, kind: .item, assignees: [rocio.id, me.id]),
            ReceiptSplitLine(description: "Propina 10 %", amount: 23.70, kind: .tip, extraShare: .proportional),
        ]
        return Boleta(people: [me, carla, martin, rocio], lines: lines)
    }

    private static func image(_ kind: DividirBoletaImageKind, payer: String? = nil, boleta: Boleta = boleta())
        -> DividirBoletaImageContent? {
        DividirBoletaImageBuilder.make(
            kind: kind, merchant: "Cevichería El Muelle", dateText: "26 nov 2026", lines: boleta.lines,
            people: boleta.people, mode: .byLines, payerID: payer.map { boleta.person($0).id } ?? boleta.me.id,
            texts: texts, money: money)
    }

    // MARK: - Solo resumen

    @Test("Solo resumen, pagué yo: la imagen dice «A Jürgen le deben» (va a otros: nunca «Me deben»), cuánto y quién")
    func summary_payerIsMe() throws {
        let content = try #require(Self.image(.summary))
        #expect(content.headline == "A Jürgen le deben")
        #expect(content.headlineAmount == "S/ 192.50")
        #expect(content.subtitle == "Pagó Jürgen · total S/ 260.70")
        #expect(content.rows.map(\.name) == ["Carla", "Martín", "Rocío"])
        #expect(content.rows.map(\.amount) == ["S/ 53.90", "S/ 67.10", "S/ 71.50"])
        #expect(content.rows.allSatisfy { $0.items.isEmpty })
        #expect(content.lines.isEmpty)
        #expect(content.payerLine == nil)
    }

    @Test("Solo resumen, pagó Carla: «A Carla le deben» y yo salgo con mi nombre entre los que le deben")
    func summary_payerIsCarla() throws {
        let content = try #require(Self.image(.summary, payer: "Carla"))
        #expect(content.headline == "A Carla le deben")
        #expect(content.headlineAmount == "S/ 206.80")
        #expect(content.subtitle == "Pagó Carla · total S/ 260.70")
        #expect(content.rows.map(\.name) == ["Jürgen", "Martín", "Rocío"])
        #expect(content.rows.map(\.amount) == ["S/ 68.20", "S/ 67.10", "S/ 71.50"])
    }

    @Test("Con una sola persona que debe, la frase nombra a las dos: «Daniela le debe a Jürgen» / «Jürgen le debe a Daniela»")
    func summary_oneDebtor() throws {
        let me = DividirBoletaPerson(name: "Yo", isMe: true)
        let daniela = DividirBoletaPerson(name: "Daniela")
        let boleta = Boleta(people: [me, daniela], lines: [
            ReceiptSplitLine(description: "Cappuccino", amount: 14, kind: .item, assignees: [me.id]),
            ReceiptSplitLine(description: "Matcha latte", amount: 16, kind: .item, assignees: [daniela.id]),
            ReceiptSplitLine(description: "Torta de chocolate", amount: 18, kind: .item),
        ])
        let mine = try #require(Self.image(.summary, boleta: boleta))
        #expect(mine.headline == "Daniela le debe a Jürgen")
        #expect(mine.headlineAmount == "S/ 25.00")
        let hers = try #require(Self.image(.summary, payer: "Daniela", boleta: boleta))
        #expect(hers.headline == "Jürgen le debe a Daniela")
        #expect(hers.headlineAmount == "S/ 23.00")
    }

    // MARK: - Con detalle

    @Test("Con detalle: qué le tocó a cada uno, las líneas con quién las pagó y la parte de quien pagó")
    func detailed() throws {
        let content = try #require(Self.image(.detailed))
        #expect(content.payerLine == "La parte de Jürgen: S/ 68.20")
        let carla = try #require(content.rows.first { $0.name == "Carla" })
        // Dentro de cada importe va un espacio duro, para que no se parta al cambiar de línea.
        #expect(carla.items.map { $0.replacingOccurrences(of: "\u{00A0}", with: " ") } == [
            "Ají de gallina S/ 36.00",
            "Chicha morada 1 L (entre 4) S/ 6.00",
            "Gaseosa 500 ml ×2 (entre 2) S/ 7.00",
            "Propina 10 % S/ 4.90",
        ])
        // 7 líneas de consumo y la propina incluida.
        #expect(content.lines.count == 8)
        #expect(content.lines.first { $0.description == "Chicha morada 1 L" }?.who == "Entre todos")
        #expect(content.lines.first { $0.description == "Gaseosa 500 ml ×2" }?.who == "Carla y Martín")
        #expect(content.lines.first { $0.description == "Leche de tigre para compartir" }?.who == "Jürgen y Rocío")
    }

    @Test("Con detalle y pagó Carla: su parte va aparte, no entre los que le deben")
    func detailed_payerIsCarla() throws {
        let content = try #require(Self.image(.detailed, payer: "Carla"))
        #expect(content.payerLine == "La parte de Carla: S/ 53.90")
        #expect(!content.rows.contains { $0.name == "Carla" })
    }

    @Test("Una propina sin incluir no sale en la imagen")
    func excludedExtraIsNotShown() throws {
        let base = Self.boleta()
        var lines = base.lines
        lines[7].extraShare = .excluded
        let content = try #require(Self.image(.detailed, boleta: Boleta(people: base.people, lines: lines)))
        #expect(content.lines.count == 7)
        #expect(content.headlineAmount == "S/ 175.00")
    }

    @Test("Ningún texto de la imagen habla en primera persona ni dice «Yo»")
    func noFirstPerson() throws {
        for kind in DividirBoletaImageKind.allCases {
            for payer in [nil, "Carla"] {
                let content = try #require(Self.image(kind, payer: payer))
                let texts = [content.headline, content.subtitle, content.payerLine ?? ""] + content.rows.map(\.name)
                for text in texts {
                    #expect(!text.contains("Yo"), "\(kind) \(payer ?? "yo"): \(text)")
                    #expect(!text.lowercased().hasPrefix("me "), "\(kind): \(text)")
                    #expect(!text.lowercased().hasPrefix("mi "), "\(kind): \(text)")
                }
            }
        }
    }

    @Test("Las iniciales: dos palabras, dos letras; una, una")
    func initials() {
        #expect(DividirBoletaImageBuilder.initials("Ana María") == "AM")
        #expect(DividirBoletaImageBuilder.initials("carla") == "C")
        #expect(DividirBoletaImageBuilder.initials("") == "?")
    }

    // MARK: - Contraste AA

    @Test("Cada texto de los tres diseños pasa AA (4,5:1) sobre su fondo")
    func contrastAA() {
        typealias P = DividirBoletaPalette
        let pairs: [(String, String, String)] = [
            ("Clara · texto", P.lightInk, P.lightBackground),
            ("Clara · apoyo", P.lightInkSecondary, P.lightBackground),
            ("Clara · franja", P.onIndigo, P.indigoDeep),
            ("Clara · franja", P.onIndigo, P.indigo),
            ("Clara · franja apoyo", P.onIndigoSecondary, P.indigo),
            ("Yala · texto", P.onIndigo, P.indigo),
            ("Yala · apoyo", P.brandInkSecondary, P.indigo),
            ("Yala · tarjeta", P.onIndigo, P.brandCard),
            ("Yala · tarjeta apoyo", P.brandInkSecondary, P.brandCard),
            ("Boleta · texto", P.paperInk, P.paper),
            ("Boleta · apoyo", P.paperInkSecondary, P.paper),
            ("Boleta · logo y pie", P.paperAccent, P.paper),
            ("Boleta · titular", P.paperPinkText, P.paper),
        ] + P.avatars.map { ("Iniciales", "FFFFFF", $0) }
        for (name, text, background) in pairs {
            let ratio = Self.contrast(text, background)
            #expect(ratio >= 4.5, "\(name): #\(text) sobre #\(background) da \(ratio)")
        }
    }

    private static func luminance(_ hex: String) -> Double {
        let value = Int(hex, radix: 16) ?? 0
        let channels = [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF].map { Double($0) / 255 }
        let linear = channels.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    private static func contrast(_ a: String, _ b: String) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
