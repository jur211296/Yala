//
//  GroupSplitLabelLogicTests.swift
//  YalaTests
//
//  La etiqueta junto a «Reparto» en el detalle de un gasto de grupo (encargo del 2026-11-26). El bug: un
//  «Pagaste · es todo de Pia» (tipo `equal`, un único participante) salía «Partes iguales» con Tú S/ 0 y Pia S/ 214.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos · etiqueta real del reparto")
struct GroupSplitLabelLogicTests {

    private let me = "me"
    private let pia = "pia"
    private let ana = "ana"

    private func kind(_ type: String?, _ shares: [(String, Double)], me current: String? = "me") -> GroupSplitLabelLogic.Kind {
        GroupSplitLabelLogic.kind(
            splitType: type,
            shares: shares.map { (memberID: $0.0, amount: $0.1) },
            currentMemberID: current
        )
    }

    // MARK: - Partes iguales

    @Test("Partes iguales entre dos")
    func equalBetweenTwo() {
        #expect(kind("equal", [(me, 107), (pia, 107)]) == .equal)
    }

    @Test("Partes iguales entre varios")
    func equalAmongSeveral() {
        #expect(kind("equal", [(me, 40), (pia, 40), (ana, 40)]) == .equal)
    }

    @Test("Céntimos que no dividen exacto siguen siendo partes iguales")
    func equalWithRoundingCents() {
        #expect(kind("equal", [(me, 33.33), (pia, 33.33), (ana, 33.34)]) == .equal)
    }

    @Test("Montos exactos que resultan iguales se leen como partes iguales")
    func exactThatHappensToBeEven() {
        #expect(kind("exact", [(me, 50), (pia, 50)]) == .equal)
    }

    // MARK: - Todo de una persona (el bug)

    @Test("Pagaste · es todo de Pia: «Todo de Pia», no «Partes iguales»")
    func iPaidAllForOther() {
        // Como lo guarda la opción rápida: tipo `equal`, solo Pia participa.
        #expect(kind("equal", [(pia, 214)]) == .allFor(memberID: pia))
        // Y con una parte en cero para quien pagó (como en la captura: Tú S/ 0.00, Pia S/ 214.00).
        #expect(kind("equal", [(me, 0), (pia, 214)]) == .allFor(memberID: pia))
    }

    @Test("Pagó Pia · es todo tuyo: «Todo tuyo»")
    func theyPaidAllMine() {
        #expect(kind("equal", [(me, 214)]) == .allForMe)
        #expect(kind("equal", [(me, 214), (pia, 0)]) == .allForMe)
    }

    @Test("Todo de una persona gana al tipo guardado, sea cual sea")
    func singleShareWinsOverStoredType() {
        #expect(kind("exact", [(me, 0), (pia, 120)]) == .allFor(memberID: pia))
        #expect(kind("percentage", [(pia, 0), (me, 120)]) == .allForMe)
        #expect(kind("shares", [(ana, 90)]) == .allFor(memberID: ana))
    }

    @Test("Sin identidad resuelta, todo de una persona nunca dice «tuyo»")
    func singleShareWithoutIdentity() {
        #expect(kind("equal", [(me, 214)], me: nil) == .allFor(memberID: me))
    }

    // MARK: - Partes distintas

    @Test("Montos exactos distintos")
    func exactDifferent() {
        #expect(kind("exact", [(me, 30), (pia, 90)]) == .exact)
    }

    @Test("Porcentajes distintos")
    func percentageDifferent() {
        #expect(kind("percentage", [(me, 25), (pia, 75)]) == .percentage)
    }

    @Test("Proporciones distintas")
    func sharesDifferent() {
        #expect(kind("shares", [(me, 40), (pia, 80)]) == .shares)
    }

    @Test("Un céntimo y medio de diferencia ya no es partes iguales")
    func justAboveTolerance() {
        #expect(kind("exact", [(me, 50), (pia, 50.02)]) == .exact)
    }

    // MARK: - Gastos viejos y tipos raros

    @Test("Sin tipo guardado: deciden los montos")
    func legacyWithoutType() {
        #expect(kind("", [(me, 60), (pia, 60)]) == .equal)
        #expect(kind(nil, [(me, 20), (pia, 100)]) == .custom)
        #expect(kind("", [(pia, 120)]) == .allFor(memberID: pia))
    }

    @Test("`equal` guardado con partes distintas no se disfraza de partes iguales")
    func storedEqualButUneven() {
        #expect(kind("equal", [(me, 10), (pia, 110)]) == .custom)
    }

    @Test("Tipo desconocido con partes distintas: personalizado")
    func unknownType() {
        #expect(kind("legacy-x", [(me, 10), (pia, 20)]) == .custom)
    }

    @Test("Tipo en mayúsculas o con espacios se reconoce")
    func storedTypeIsNormalized() {
        #expect(kind(" Percentage ", [(me, 10), (pia, 30)]) == .percentage)
    }

    @Test("Sin partes cargadas: el tipo guardado, como antes")
    func noSharesFallsBackToStoredType() {
        #expect(kind("equal", []) == .equal)
        #expect(kind("exact", []) == .exact)
        #expect(kind("percentage", [(me, 0), (pia, 0)]) == .percentage)
        #expect(kind(nil, []) == .equal)
    }

    @Test("Varias partes del mismo miembro se suman")
    func sameMemberSums() {
        #expect(kind("exact", [(pia, 100), (pia, 14)]) == .allFor(memberID: pia))
        #expect(kind("exact", [(me, 50), (pia, 25), (pia, 25)]) == .equal)
    }

    @Test("Un monto no finito se ignora")
    func nonFiniteIgnored() {
        #expect(kind("equal", [(me, .nan), (pia, 214)]) == .allFor(memberID: pia))
    }

    // MARK: - Icono y barra

    @Test("Cada tipo tiene su icono, y todo de una persona usa el de persona")
    func icons() {
        #expect(GroupSplitLabelLogic.iconName(for: .equal) == "equal.circle.fill")
        #expect(GroupSplitLabelLogic.iconName(for: .allForMe) == "person.fill")
        #expect(GroupSplitLabelLogic.iconName(for: .allFor(memberID: pia)) == "person.fill")
        #expect(GroupSplitLabelLogic.iconName(for: .percentage) == "percent")
        #expect(GroupSplitLabelLogic.iconName(for: .exact) == "number")
        #expect(GroupSplitLabelLogic.iconName(for: .shares) == "chart.pie.fill")
        #expect(GroupSplitLabelLogic.iconName(for: .custom) == "slider.horizontal.3")
    }

    @Test("La barra de proporciones solo con partes distintas")
    func proportionBar() {
        #expect(!GroupSplitLabelLogic.showsProportionBar(for: .equal))
        #expect(!GroupSplitLabelLogic.showsProportionBar(for: .allForMe))
        #expect(!GroupSplitLabelLogic.showsProportionBar(for: .allFor(memberID: pia)))
        #expect(GroupSplitLabelLogic.showsProportionBar(for: .exact))
        #expect(GroupSplitLabelLogic.showsProportionBar(for: .custom))
    }
}

@Suite("Grupos · textos del pulido de división y detalle")
struct GruposPulidoDivisionDetalleTextTests {

    private static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                                  "pt-BR", "pt-PT", "pt", "zh-Hans"]
    private static let keys = ["gpdd.twoPerson.youPaidHeader", "gpdd.twoPerson.theyPaidHeader", "gpdd.split.allForMe",
                               "gpdd.split.allFor", "gpdd.split.custom"]

    @Test("Las cinco claves existen y están traducidas en los 16 idiomas", arguments: locales)
    func everyLocaleHasEveryKey(locale: String) throws {
        let bundle = try #require(Bundle.main.path(forResource: locale, ofType: "lproj").flatMap(Bundle.init(path:)),
                                  "Falta \(locale).lproj")
        for key in Self.keys {
            let value = bundle.localizedString(forKey: key, value: "__MISSING__", table: GruposPulidoDivisionDetalleText.table)
            #expect(value != "__MISSING__" && !value.isEmpty, "\(locale): falta \(key)")
        }
        for key in ["gpdd.twoPerson.theyPaidHeader", "gpdd.split.allFor"] {
            let value = bundle.localizedString(forKey: key, value: "", table: GruposPulidoDivisionDetalleText.table)
            #expect(value.components(separatedBy: "%@").count == 2, "\(locale): \(key) debe llevar un solo %@")
        }
    }

    @Test("La etiqueta de «todo de» lleva el nombre de la persona")
    func allForCarriesTheName() {
        let label = GruposPulidoDivisionDetalleText.splitLabel(for: .allFor(memberID: "x")) { _ in "Pia" }
        #expect(label.contains("Pia"))
        #expect(label != L10n.Split.typeEqual)
    }
}
