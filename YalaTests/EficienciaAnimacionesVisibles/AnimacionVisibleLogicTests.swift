//
//  AnimacionVisibleLogicTests.swift
//  YalaTests
//
//  Lote 2 del plan de eficiencia (26-nov-2026): la regla de cuándo corre una animación sin fin y lo que la gráfica de
//  tendencia dice a VoiceOver, ahora calculado fuera del `body`.
//

import Foundation
import SwiftUI
import Testing
@testable import Yala

@Suite("Eficiencia · cuándo anima una animación sin fin")
struct AnimacionVisibleLogicTests {

    @Test func soloAnimaConTodoAFavor() {
        #expect(AnimacionVisibleLogic.anima(quiere: true, montada: true, paginaVisible: true, fase: .active))
    }

    /// La página oculta detrás de otra pestaña es el caso medido en el iPhone 14: 35-38 % de un núcleo en reposo.
    @Test func noAnimaConLaPaginaOculta() {
        #expect(!AnimacionVisibleLogic.anima(quiere: true, montada: true, paginaVisible: false, fase: .active))
    }

    @Test(arguments: [ScenePhase.inactive, .background])
    func noAnimaConLaAppFueraDePrimerPlano(fase: ScenePhase) {
        #expect(!AnimacionVisibleLogic.anima(quiere: true, montada: true, paginaVisible: true, fase: fase))
    }

    @Test func noAnimaDesmontadaNiSinQuererlo() {
        #expect(!AnimacionVisibleLogic.anima(quiere: true, montada: false, paginaVisible: true, fase: .active))
        #expect(!AnimacionVisibleLogic.anima(quiere: false, montada: true, paginaVisible: true, fase: .active))
    }
}

@Suite("Eficiencia · lo que la tendencia dice a VoiceOver")
struct SpokenTrendTests {

    private static let day: TimeInterval = 86_400
    private static let start = Date(timeIntervalSince1970: 1_790_000_000)
    private static let format = ChartAmountFormat(decimals: 2, identifier: "es_PE@currency=PEN", hidden: false)

    private static func point(_ offsetDays: Double, _ value: Double) -> BarPoint {
        BarPoint(date: start.addingTimeInterval(offsetDays * day), value: value)
    }

    private static func key(raw: [BarPoint] = [], anchor: BarPoint? = nil) -> SpokenTrend.Key {
        SpokenTrend.Key(trendPoints: [point(0, 100), point(1, 50), point(2, 80)], rawPoints: raw,
                        liveAnchor: anchor, grouping: .day, format: format)
    }

    /// Lo mismo que se decía antes desde el `body`: los puntos reales y el resumen de `ChartSpokenSummary`.
    @Test func diceLoMismoQueAntes() {
        let key = Self.key()
        let said = SpokenTrend.make(key)
        let expected = key.trendPoints.map { (date: $0.date, value: $0.value) }
        #expect(said.summary == ChartSpokenSummary.trend(points: expected, grouping: .day, format: Self.format))
        #expect(said.points == expected.map { .at($0.date, $0.value) })
        #expect(!said.summary.isEmpty)
    }

    /// Con puntos sin suavizar, se dicen esos y no los suavizados.
    @Test func prefiereLosPuntosReales() {
        let raw = [Self.point(0, 1), Self.point(2, 9)]
        #expect(SpokenTrend.make(Self.key(raw: raw)).points == raw.map { .at($0.date, $0.value) })
    }

    /// El saldo vivo se suma al final solo si es posterior al último punto.
    @Test func elSaldoVivoSeDiceAlFinal() {
        let later = SpokenTrend.make(Self.key(anchor: Self.point(5, 120)))
        #expect(later.points.count == 4)
        #expect(later.points.last == .at(Self.point(5, 120).date, 120))
        let earlier = SpokenTrend.make(Self.key(anchor: Self.point(1, 999)))
        #expect(earlier.points.count == 3)
    }

    /// La clave cambia con el formato (ocultar montos): el resumen no se queda con cifras viejas.
    @Test func laClaveCambiaConElFormato() {
        let hidden = SpokenTrend.Key(trendPoints: Self.key().trendPoints, rawPoints: [], liveAnchor: nil,
                                     grouping: .day, format: ChartAmountFormat(decimals: 2, identifier: "es_PE@currency=PEN", hidden: true))
        #expect(hidden != SpokenTrend.Key(trendPoints: hidden.trendPoints, rawPoints: [], liveAnchor: nil,
                                          grouping: .day, format: Self.format))
    }

    @Test func elPulsoLateYSeApaga() {
        #expect(SpokenTrend.pulse(active: true) != nil)
        #expect(SpokenTrend.pulse(active: false) == nil)
    }
}
