//
//  GroupsAttestVerdictLogicTests.swift
//  YalaTests
//
//  Cuándo un teléfono sin App Attest deja de oír «inténtalo en un rato»: la tabla pura y su tienda (ticket
//  `groups-phone-that-never-attests-is-told-to-retry-forever`, decisión de Jürgen del 2026-09-15: 24 h y 3 rechazos).
//

import Foundation
import Testing

@testable import Yala

@Suite("Teléfono sin App Attest · el veredicto de 24 h")
struct GroupsAttestVerdictLogicTests {

    typealias L = GroupsAttestVerdictLogic
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var day: TimeInterval { L.minimumDuration }
    private var hour: TimeInterval { L.countingInterval }

    private func streak(rejections: Int, first: Date, last: Date? = nil) -> L.Streak {
        L.Streak(firstRejectedAt: first, lastCountedAt: last ?? first, rejections: rejections)
    }

    @Test("Las constantes son las de la decisión: 24 h, 3 rechazos, y como mucho uno por hora")
    func theThresholdsAreTheDecidedOnes() {
        #expect(L.minimumDuration == 86_400)
        #expect(L.minimumRejections == 3)
        #expect(L.countingInterval == 3_600)
    }

    @Test("MUTACIÓN: terminal solo con las DOS condiciones, y el borde de las 24 h cuenta")
    func terminalNeedsBothConditions() {
        let tres = streak(rejections: 3, first: t0)
        #expect(L.isTerminal(tres, now: t0.addingTimeInterval(day)))
        #expect(!L.isTerminal(tres, now: t0.addingTimeInterval(day - 1)), "un segundo antes de las 24 h todavía es pasajero")
        let dos = streak(rejections: 2, first: t0)
        #expect(!L.isTerminal(dos, now: t0.addingTimeInterval(day * 30)), "un mes con dos rechazos no es una racha")
        #expect(!L.isTerminal(nil, now: t0.addingTimeInterval(day * 30)))
    }

    /// **Una ráfaga cuenta una vez** (review adversarial, 2026-09-15). Un solo gesto dispara varias peticiones —la
    /// membresía reintenta tres veces, el cierre reintenta cada 2 s durante 45 s—: contadas por petición, un fallo de
    /// segundos cumplía el mínimo y un gesto ayer más otro hoy daban el veredicto.
    @Test("MUTACIÓN: dentro de la misma hora los rechazos no suman; a la hora siguiente, sí")
    func rejectionsCountOncePerHour() {
        var racha = L.recordingRejection(after: nil, now: t0)
        for segundo in [1.0, 3, 45, hour - 1] {
            racha = L.recordingRejection(after: racha, now: t0.addingTimeInterval(segundo))
        }
        #expect(racha == streak(rejections: 1, first: t0), "una ráfaga dentro de la hora cuenta una vez")
        racha = L.recordingRejection(after: racha, now: t0.addingTimeInterval(hour))
        #expect(racha == streak(rejections: 2, first: t0, last: t0.addingTimeInterval(hour)))

        // El escenario de la review: tres peticiones de un gesto ayer y una hoy no son el veredicto.
        var ayer = L.recordingRejection(after: nil, now: t0)
        for segundo in [1.0, 4] { ayer = L.recordingRejection(after: ayer, now: t0.addingTimeInterval(segundo)) }
        let hoy = L.recordingRejection(after: ayer, now: t0.addingTimeInterval(day))
        #expect(!L.isTerminal(hoy, now: t0.addingTimeInterval(day)), "dos ocasiones no son tres")
    }

    @Test("MUTACIÓN: un reloj que retrocede no adelanta el veredicto: reinicia la racha")
    func aClockGoingBackRestartsTheStreak() {
        let vieja = streak(rejections: 9, first: t0, last: t0.addingTimeInterval(2 * hour))
        let antesDelUltimo = t0.addingTimeInterval(hour)
        #expect(L.recordingRejection(after: vieja, now: antesDelUltimo) == streak(rejections: 1, first: antesDelUltimo))
        let antesDelPrimero = t0.addingTimeInterval(-60)
        #expect(!L.isTerminal(vieja, now: antesDelPrimero))
        #expect(L.recordingRejection(after: vieja, now: antesDelPrimero) == streak(rejections: 1, first: antesDelPrimero))
    }

    @Test("El contador satura")
    func theCounterSaturates() {
        let tope = L.recordingRejection(after: streak(rejections: Int.max, first: t0), now: t0.addingTimeInterval(hour))
        #expect(tope.rejections == Int.max)
    }

    /// Una racha con sus rechazos ya contados que recibe otro un día después ya «era» terminal con ese mismo reloj, así
    /// que comparar con la racha anterior no contaría nunca a este teléfono. La marca propia sí.
    @Test("MUTACIÓN: el canario cuenta la racha UNA vez, aunque llegue a terminal por el reloj y no por el número")
    func theCanaryReportsOncePerStreak() {
        let manana = t0.addingTimeInterval(day + hour)
        var racha = L.recordingRejection(
            after: streak(rejections: 3, first: t0, last: t0.addingTimeInterval(2 * hour)), now: manana)
        #expect(L.shouldReportTerminal(racha, now: manana))
        racha.terminalReported = true
        let despues = manana.addingTimeInterval(hour)
        #expect(!L.shouldReportTerminal(L.recordingRejection(after: racha, now: despues), now: despues))
        #expect(!L.shouldReportTerminal(streak(rejections: 5, first: t0), now: t0))
    }
}

/// **Aísla la tienda de la racha mientras dura un test** (molde `PendingJoinStore.defaults`). Todo test que haga
/// responder a un cliente de Grupos con 401 `yala_attest_required` escribe en ella: sin aislar, la racha acabaría en el
/// `UserDefaults.standard` del host de test —que es la app— y un día después se leería terminal en ese simulador.
///
/// Uso: `let racha = try IsolatedAttestStreak(); defer { racha.restore() }`.
@MainActor
final class IsolatedAttestStreak {
    struct SuiteUnavailable: Error {}

    let defaults: UserDefaults
    private let name: String
    private let previous: UserDefaults

    init() throws {
        name = "yala.tests.groupsAttestStreak.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: name) else { throw SuiteUnavailable() }
        defaults = suite
        previous = GroupsAttestStreakStore.defaults
        GroupsAttestStreakStore.defaults = suite
    }

    /// Siembra una racha ya terminal: 3 rechazos contados, el primero hace un día y una hora y el último hace dos horas,
    /// así que el siguiente rechazo vuelve a contar.
    func seedTerminal(now: Date = .now) throws {
        let streak = GroupsAttestVerdictLogic.Streak(
            firstRejectedAt: now.addingTimeInterval(-(GroupsAttestVerdictLogic.minimumDuration + 3600)),
            lastCountedAt: now.addingTimeInterval(-2 * GroupsAttestVerdictLogic.countingInterval),
            rejections: GroupsAttestVerdictLogic.minimumRejections, terminalReported: true)
        defaults.set(try JSONEncoder().encode(streak), forKey: GroupsAttestStreakStore.key)
    }

    func restore() {
        GroupsAttestStreakStore.defaults = previous
        defaults.removePersistentDomain(forName: name)
    }
}

@MainActor
@Suite("Teléfono sin App Attest · la tienda de la racha", .serialized)
struct GroupsAttestStreakStoreTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("MUTACIÓN: la racha se guarda entre lecturas, y un 200 la borra")
    func persistsAndAcceptanceClears() throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let hora = GroupsAttestVerdictLogic.countingInterval
        for horas in [0.0, 1, 2] { GroupsAttestStreakStore.recordRejection(now: t0.addingTimeInterval(horas * hora)) }
        #expect(GroupsAttestStreakStore.current()?.rejections == 3)
        #expect(GroupsAttestStreakStore.current()?.firstRejectedAt == t0)
        #expect(!GroupsAttestStreakStore.isTerminal(now: t0.addingTimeInterval(3600)))
        #expect(GroupsAttestStreakStore.isTerminal(now: t0.addingTimeInterval(GroupsAttestVerdictLogic.minimumDuration)))

        GroupsAttestStreakStore.recordAcceptance()
        #expect(GroupsAttestStreakStore.current() == nil)
        #expect(racha.defaults.object(forKey: GroupsAttestStreakStore.key) == nil)
    }

    @Test("La marca del canario se escribe la primera vez que la racha se lee terminal")
    func theReportMarkIsPersisted() throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let hora = GroupsAttestVerdictLogic.countingInterval
        for horas in [0.0, 1, 2] { GroupsAttestStreakStore.recordRejection(now: t0.addingTimeInterval(horas * hora)) }
        #expect(GroupsAttestStreakStore.current()?.terminalReported == false)
        GroupsAttestStreakStore.recordRejection(now: t0.addingTimeInterval(GroupsAttestVerdictLogic.minimumDuration))
        #expect(GroupsAttestStreakStore.current()?.terminalReported == true)
    }

    @Test("Un valor ilegible cuenta como «sin racha», que nunca ofrece perder nada, y lo pisa el siguiente rechazo")
    func unreadableValueIsNoStreak() throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        racha.defaults.set(Data("no es json".utf8), forKey: GroupsAttestStreakStore.key)
        #expect(GroupsAttestStreakStore.current() == nil)
        #expect(!GroupsAttestStreakStore.isTerminal(now: t0))
        GroupsAttestStreakStore.recordRejection(now: t0)
        #expect(GroupsAttestStreakStore.current()
                == GroupsAttestVerdictLogic.Streak(firstRejectedAt: t0, lastCountedAt: t0, rejections: 1))
    }

    /// Control del instrumento: la suite aislada es de verdad otra, y al restaurar vuelve la de antes.
    @Test("El aislamiento escribe fuera de la tienda de antes y la devuelve al salir")
    func theIsolationIsReal() throws {
        let antes = GroupsAttestStreakStore.defaults
        let racha = try IsolatedAttestStreak()
        #expect(GroupsAttestStreakStore.defaults !== antes)
        racha.restore()
        #expect(GroupsAttestStreakStore.defaults === antes)
    }
}
