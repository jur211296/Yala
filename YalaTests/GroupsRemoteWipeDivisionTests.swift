//
//  GroupsRemoteWipeDivisionTests.swift
//  YalaTests
//
//  El reparto de un vaciado: el origen dice qué repone y el receptor repone el resto (ticket
//  `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere`). Aquí la decisión pura y el alcance de la
//  petición; el recorrido contra el bridge real vive en `GroupsBridgeRestoreConvergenceBehaviourTests` («El origen sin
//  los grupos») y el cableado en `RemoteWipeSignalWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("El reparto de un vaciado: la decisión pura y el alcance de la petición")
@MainActor
struct GroupsRemoteWipeDivisionTests {

    typealias Logic = GroupsRemoteWipeDivisionLogic
    typealias Store = GroupsBridgeRestoreConvergenceStore

    // MARK: - El reparto del origen

    @Test("el origen reparte lo que tiene; con el dominio cerrado, nada")
    func originDivision() {
        let at = Date(timeIntervalSince1970: 1_800_000_000)
        let open = Logic.originDivision(signaledAt: at, domainOpen: true,
                                        localExpenseIDs: ["a", "b"], confirmedVisibleSettlementIDs: ["s"])
        #expect(open == .init(signaledAt: at.timeIntervalSince1970, expenseIDs: ["a", "b"], settlementIDs: ["s"]))
        let closed = Logic.originDivision(signaledAt: at, domainOpen: false,
                                          localExpenseIDs: ["a"], confirmedVisibleSettlementIDs: ["s"])
        #expect(closed.expenseIDs.isEmpty && closed.settlementIDs.isEmpty,
                "con el dominio cerrado la convergencia del origen espera: su reparto no puede prometer nada")
        #expect(closed.signaledAt == at.timeIntervalSince1970)
    }

    // MARK: - El formato compartido del parque

    /// El reparto lo escribe un build y lo lee otro. Renombrar la clave del KV o un campo pasa todos los demás tests —el
    /// escritor y el lector cambian juntos— y deja a un receptor con otro build esperando 30 días para nada.
    @Test("el reparto se lee con la clave y los campos que escriben los builds del parque")
    func divisionWireFormat() throws {
        #expect(GroupsRemoteWipeDivisionStore.kvKey == "groupsWipeDivision")
        let kv = EmptyKeyValueStore()
        kv.stored = #"{"expenseIDs":["a"],"settlementIDs":["s"],"signaledAt":1800000000.5}"#
        #expect(GroupsRemoteWipeDivisionStore.readDivision(kv)
                == .init(signaledAt: 1_800_000_000.5, expenseIDs: ["a"], settlementIDs: ["s"]))
    }

    /// El plazo de la espera es el de las declaraciones, 30 días. Los tests del plazo lo leen por su símbolo, así que sin
    /// esta línea un plazo de un minuto soltaría la espera antes de que el iCloud-KV sincronizara.
    @Test("el plazo de la espera son 30 días")
    func lifetimeIsThirtyDays() {
        #expect(Logic.lifetime == 30 * 24 * 60 * 60)
    }

    // MARK: - La señal es la misma

    /// La hora viaja como `Double` y el receptor la pasa por `Date`. La vuelta es exacta hoy; el margen es defensivo.
    @Test("la hora de la señal casa tras pasar por `Date`, y el margen tiene sus dos vecinos")
    func sameSignal_boundaries() {
        for raw in [1_800_000_000.123456, 1_790_123_456.987654, 1_000_000_000.000001] {
            let roundTrip = Date(timeIntervalSince1970: raw).timeIntervalSince1970
            #expect(Logic.sameSignal(raw, roundTrip), "la vuelta por `Date` de \(raw) ya no casa")
        }
        let t = 1_800_000_000.0
        #expect(Logic.sameSignal(t, t + Logic.signalTolerance - 0.0002), "dentro del margen es la misma señal")
        #expect(!Logic.sameSignal(t, t + Logic.signalTolerance + 0.0002), "fuera del margen es otra señal")
        #expect(!Logic.sameSignal(t, t - Logic.signalTolerance - 0.0002), "fuera del margen, por abajo, es otra señal")
    }

    // MARK: - Lo que decide el arranque

    @Test("con el reparto de ESTA señal pide sin sus ids; sin él, o con el de otra, espera")
    func resolve_matchingDivision() {
        let t = 1_800_000_000.0
        let awaiting = Logic.Awaiting(signaledAt: t, since: t)
        let now = Date(timeIntervalSince1970: t + 60)
        let division = Logic.Division(signaledAt: t, expenseIDs: ["a"], settlementIDs: ["s"])
        #expect(Logic.resolve(awaiting: awaiting, division: division, now: now)
                == .request(excludingExpenses: ["a"], excludingSettlements: ["s"]))
        #expect(Logic.resolve(awaiting: awaiting, division: nil, now: now) == .wait, "sin reparto, el receptor pidió")
        let older = Logic.Division(signaledAt: t - 3600, expenseIDs: [], settlementIDs: [])
        #expect(Logic.resolve(awaiting: awaiting, division: older, now: now) == .wait, """
            el receptor tomó el reparto de un vaciado anterior: repondría según lo que el origen tenía entonces
            """)
    }

    /// El plazo corre desde que se empezó a ESPERAR, no desde la señal: un dispositivo que procesa una señal de hace dos
    /// meses sigue encontrando su reparto. Y con el reparto de la señal, el plazo no pesa.
    @Test("sin reparto, se suelta al cumplir el plazo desde que se espera, con sus dos vecinos")
    func resolve_lifetimeBoundaries() {
        let since = 1_800_000_000.0
        let awaiting = Logic.Awaiting(signaledAt: since - 60 * 24 * 3600, since: since)
        func at(_ offset: TimeInterval) -> Date { Date(timeIntervalSince1970: since + offset) }
        #expect(Logic.resolve(awaiting: awaiting, division: nil, now: at(Logic.lifetime - 1)) == .wait)
        #expect(Logic.resolve(awaiting: awaiting, division: nil, now: at(Logic.lifetime)) == .giveUp)
        #expect(Logic.resolve(awaiting: awaiting, division: nil, now: at(-Logic.lifetime)) == .giveUp,
                "un reloj que volvió atrás más que el plazo deja la espera abierta para siempre")
        #expect(Logic.resolve(awaiting: awaiting, division: nil, now: at(-60)) == .wait)
        let old = Logic.Division(signaledAt: awaiting.signaledAt, expenseIDs: [], settlementIDs: [])
        #expect(Logic.resolve(awaiting: awaiting, division: old, now: at(Logic.lifetime * 2))
                == .request(excludingExpenses: [], excludingSettlements: []),
                "con su reparto en el KV, el plazo no debería soltarlo")
    }

    /// El arranque, de punta a punta con un KV en memoria: sin reparto espera, y cumplido el plazo suelta la espera sin
    /// pedir nada. Si no la soltara, la resolvería un reparto de OTRO vaciado que casara por casualidad nunca, pero el
    /// arranque la leería para siempre.
    @Test("el arranque espera sin reparto y suelta la espera al cumplir el plazo, sin pedir")
    func resolveIfArrived_waitsThenGivesUp() throws {
        let defaults = makeIsolatedDefaults()
        let kv = EmptyKeyValueStore()
        let since = Date(timeIntervalSince1970: 1_800_000_000)
        GroupsRemoteWipeDivision.awaitOrigin(signaledAt: since.addingTimeInterval(-60), defaults: defaults, now: since)
        GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults, now: since.addingTimeInterval(Logic.lifetime - 1))
        #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) != nil, "el arranque soltó la espera antes del plazo")
        #expect(!Store.isPending(defaults))
        GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults, now: since.addingTimeInterval(Logic.lifetime))
        #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) == nil, "cumplido el plazo, el arranque sigue esperando")
        #expect(!Store.isPending(defaults), "al soltar la espera el arranque pidió la convergencia sin saber qué repone el origen")
    }

    /// Con una petición ENTERA ya puesta —la de restaurar dentro de «Activar Yala completo», que no pide liquidaciones— el
    /// reparto solo suelta la espera: pedir las liquidaciones re-puentearía con el corpus aún bajando.
    @Test("con una petición entera puesta, el reparto solo suelta la espera y no pide las liquidaciones")
    func resolveIfArrived_overAWholeRequest_onlyClears() throws {
        let defaults = makeIsolatedDefaults()
        let kv = EmptyKeyValueStore()
        let since = Date(timeIntervalSince1970: 1_800_000_000)
        GroupsRemoteWipeDivision.awaitOrigin(signaledAt: since, defaults: defaults, now: since)
        kv.stored = #"{"expenseIDs":["a"],"settlementIDs":[],"signaledAt":1800000000}"#
        Store.markPending(defaults)
        try GroupsRemoteWipeDivisionStore.setAwaiting(.init(signaledAt: since.timeIntervalSince1970,
                                                            since: since.timeIntervalSince1970), defaults)
        GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults, now: since)
        #expect(Store.isWholePending(defaults), "el reparto recortó una petición entera")
        #expect(!Store.isSettlementLegsPending(defaults), """
            el reparto pidió las liquidaciones encima de una petición entera que no las pedía: restaurando, el re-puente \
            borraría las reales que vuelven
            """)
        #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) == nil, "la espera sobrevivió a una petición entera")

        // Control: sin la entera, el mismo reparto sí pide, con las liquidaciones.
        Store.clear(defaults)
        try GroupsRemoteWipeDivisionStore.setAwaiting(.init(signaledAt: since.timeIntervalSince1970,
                                                            since: since.timeIntervalSince1970), defaults)
        GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults, now: since)
        #expect(Store.isPending(defaults) && Store.isSettlementLegsPending(defaults))
        #expect(Store.exclusion(defaults) == .init(expenseIDs: ["a"], settlementIDs: []))
    }

    // MARK: - El alcance de la petición

    @Test("una petición con exclusión se apunta, y la entera la sustituye")
    func exclusion_roundTrip_andWholeWins() throws {
        let defaults = makeIsolatedDefaults()
        try Store.markPending(excluding: .init(expenseIDs: ["a"], settlementIDs: ["s"]), defaults)
        #expect(Store.isPending(defaults) && !Store.isWholePending(defaults))
        #expect(Store.exclusion(defaults) == .init(expenseIDs: ["a"], settlementIDs: ["s"]))

        Store.markPending(defaults)
        #expect(Store.isWholePending(defaults), "una petición entera no sustituyó a la de exclusión: repondría de menos")

        try Store.markPending(excluding: .init(expenseIDs: ["a"], settlementIDs: []), defaults)
        #expect(Store.isWholePending(defaults), """
            una petición con exclusión recortó una ENTERA ya puesta: lo que la entera iba a reponer se queda fuera
            """)
    }

    /// El corte de la señal nueva ya se llevó lo que repuso el origen de la vieja: manda el reparto nuevo. Intersecar
    /// repondría también lo que repone el origen nuevo; sumar dejaría fuera lo que el corte nuevo se llevó.
    @Test("la petición con el reparto nuevo sustituye a la del viejo")
    func exclusion_theNewerDivisionReplaces() throws {
        let defaults = makeIsolatedDefaults()
        try Store.markPending(excluding: .init(expenseIDs: ["a", "b"], settlementIDs: ["s", "t"]), defaults)
        try Store.markPending(excluding: .init(expenseIDs: ["b", "c"], settlementIDs: ["t"]), defaults)
        #expect(Store.exclusion(defaults) == .init(expenseIDs: ["b", "c"], settlementIDs: ["t"]), """
            el reparto nuevo no sustituyó al viejo: el receptor repone lo que repone el origen nuevo, o deja fuera lo que \
            el corte nuevo se llevó
            """)
    }

    /// Un alcance que quedó de una petición cortada antes de su marca no manda sobre la siguiente.
    @Test("sin marca, el alcance que quedó no recorta la petición siguiente")
    func exclusion_dormantScopeDoesNotLeak() throws {
        let defaults = makeIsolatedDefaults()
        defaults.set(try JSONEncoder().encode(Store.Exclusion(expenseIDs: ["a"], settlementIDs: [])),
                     forKey: Store.excludedKey)
        try Store.markPending(excluding: .init(expenseIDs: ["a", "b"], settlementIDs: []), defaults)
        #expect(Store.exclusion(defaults) == .init(expenseIDs: ["a", "b"], settlementIDs: []))
    }

    @Test("un alcance que no se deja leer cuenta como petición entera")
    func exclusion_unreadableIsWhole() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: Store.key)
        defaults.set(Data("no es json".utf8), forKey: Store.excludedKey)
        #expect(Store.exclusion(defaults) == nil && Store.isWholePending(defaults), """
            un alcance ilegible dejó fuera lo que no sabe: una fila que no vuelve no la ve nadie
            """)
    }

    @Test("`clear` retira el alcance y no la espera; la petición entera y el relevo de persona, las dos")
    func clearing() throws {
        let defaults = makeIsolatedDefaults()
        let awaiting = Logic.Awaiting(signaledAt: 1, since: 2)
        try GroupsRemoteWipeDivisionStore.setAwaiting(awaiting, defaults)
        try Store.markPending(excluding: .init(expenseIDs: ["a"], settlementIDs: []), defaults)
        Store.clear(defaults)
        #expect(defaults.object(forKey: Store.excludedKey) == nil, "el alcance sobrevivió a su convergencia")
        #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) == awaiting, """
            terminar una convergencia retiró la espera de otra señal: su reparto ya no pediría nada
            """)

        Store.markPending(defaults)
        #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) == nil, """
            una petición entera dejó la espera puesta: el reparto pediría otra convergencia sobre lo ya repuesto
            """)

        try GroupsRemoteWipeDivisionStore.setAwaiting(awaiting, defaults)
        DataWipeService.removeGroupsDomainPreferenceKeys(from: defaults)
        #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) == nil, """
            el relevo de persona dejó la espera del reparto: pediría la convergencia sobre los grupos del humano nuevo
            """)
    }

    // MARK: - Lo prometido que no llega (ticket `wipe-division-exclusion-trusts-the-origin-to-converge`)

    /// El techo lo leen los demás tests por su símbolo: sin esta línea, un techo de un minuto dejaría de confiar en el
    /// origen antes de su arranque en frío y los dos repondrían lo mismo.
    @Test("el techo de la promesa son 72 horas")
    func trustCeilingIsThreeDays() {
        #expect(Logic.trustCeiling == 3 * 24 * 60 * 60)
    }

    @Test("lo que llegó sale de la promesa; con todo llegado, se suelta")
    func review_prunesWhatArrived() {
        let since = 1_800_000_000.0
        let trusted = Logic.Trusted(signaledAt: since - 60, since: since, expenseIDs: ["a", "b"], settlementIDs: ["s"])
        let now = Date(timeIntervalSince1970: since + 60)
        #expect(Logic.review(trusted, arrivedExpenses: ["a", "x"], arrivedSettlements: [], now: now)
                == .keep(.init(signaledAt: since - 60, since: since, expenseIDs: ["b"], settlementIDs: ["s"])))
        #expect(Logic.review(trusted, arrivedExpenses: ["a", "b"], arrivedSettlements: ["s"], now: now) == .settled,
                "el origen repuso todo y el receptor sigue esperando")
        #expect(Logic.review(trusted, arrivedExpenses: ["a", "b"], arrivedSettlements: ["s"],
                             now: Date(timeIntervalSince1970: since + Logic.trustCeiling * 2)) == .settled,
                "pasado el techo, el receptor repone lo que el origen ya repuso")
        #expect(Logic.review(trusted, arrivedExpenses: [], arrivedSettlements: ["s"],
                             now: Date(timeIntervalSince1970: since + Logic.trustCeiling))
                == .takeOver(expenses: ["a", "b"], settlements: []), "la retoma no deja fuera lo que ya llegó")
    }

    /// El techo corre desde que se resolvió el reparto, con sus dos vecinos, y un reloj que vuelve atrás más que el
    /// techo no deja la promesa abierta para siempre.
    @Test("pasado el techo el receptor repone, con sus dos vecinos y el reloj que vuelve atrás")
    func review_ceilingBoundaries() {
        let since = 1_800_000_000.0
        let trusted = Logic.Trusted(signaledAt: since - 60, since: since, expenseIDs: ["a"], settlementIDs: [])
        func at(_ offset: TimeInterval) -> Logic.TrustReview {
            Logic.review(trusted, arrivedExpenses: [], arrivedSettlements: [], now: Date(timeIntervalSince1970: since + offset))
        }
        #expect(at(Logic.trustCeiling - 1) == .keep(trusted), "el receptor dejó de confiar antes del techo")
        #expect(at(Logic.trustCeiling) == .takeOver(expenses: ["a"], settlements: []))
        #expect(at(-Logic.trustCeiling) == .takeOver(expenses: ["a"], settlements: []),
                "un reloj que volvió atrás más que el techo deja la promesa abierta para siempre")
        #expect(at(-60) == .keep(trusted))
    }

    /// **El reparto deja la promesa con la hora de la señal y la del arranque que lo resuelve**, no la de la espera (review
    /// adversarial, lente de sync): un reparto que llega a los cuatro días daba la promesa por vencida en el mismo arranque
    /// que la apuntaba. El de un vaciado nuevo la sustituye, y un reparto vacío no promete nada.
    @Test("el reparto apunta la promesa con la hora del arranque que lo resuelve; el nuevo la sustituye y el vacío la retira")
    func resolveIfArrived_recordsTheTrust() throws {
        let defaults = makeIsolatedDefaults()
        let kv = EmptyKeyValueStore()
        let since = Date(timeIntervalSince1970: 1_800_000_000)
        let later = since.addingTimeInterval(3600)
        GroupsRemoteWipeDivision.awaitOrigin(signaledAt: since, defaults: defaults, now: since)
        kv.stored = #"{"expenseIDs":["a"],"settlementIDs":["s"],"signaledAt":1800000000}"#
        GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults, now: later)
        #expect(GroupsRemoteWipeDivisionStore.trusted(defaults)
                == .init(signaledAt: since.timeIntervalSince1970, since: later.timeIntervalSince1970,
                         expenseIDs: ["a"], settlementIDs: ["s"]), """
            el receptor excluyó lo del origen sin apuntar la promesa, o la apuntó con la hora de la espera: si el origen \
            no repone no vuelve nunca, y con la espera un reparto tardío la da por vencida sin darle al origen un arranque
            """)

        Store.clear(defaults)
        GroupsRemoteWipeDivision.awaitOrigin(signaledAt: later, defaults: defaults, now: later)
        kv.stored = #"{"expenseIDs":["b"],"settlementIDs":[],"signaledAt":1800003600}"#
        GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults, now: later)
        #expect(GroupsRemoteWipeDivisionStore.trusted(defaults)
                == .init(signaledAt: later.timeIntervalSince1970, since: later.timeIntervalSince1970,
                         expenseIDs: ["b"], settlementIDs: []),
                "la promesa del reparto nuevo no sustituyó a la vieja: el corte nuevo ya se llevó lo que repuso el origen viejo")

        Store.clear(defaults)
        GroupsRemoteWipeDivision.awaitOrigin(signaledAt: since, defaults: defaults, now: later)
        kv.stored = #"{"expenseIDs":[],"settlementIDs":[],"signaledAt":1800000000}"#
        GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults, now: later)
        #expect(GroupsRemoteWipeDivisionStore.trusted(defaults) == nil, "un reparto vacío dejó una promesa vieja puesta")
    }

    @Test("el relevo de persona retira la promesa")
    func trust_personHandoverClearsIt() throws {
        let defaults = makeIsolatedDefaults()
        try GroupsRemoteWipeDivisionStore.setTrusted(.init(signaledAt: 1, since: 1, expenseIDs: ["a"], settlementIDs: []), defaults)
        DataWipeService.removeGroupsDomainPreferenceKeys(from: defaults)
        #expect(GroupsRemoteWipeDivisionStore.trusted(defaults) == nil, """
            el relevo de persona dejó la promesa: pasado el techo re-puentearía sobre los grupos del humano nuevo
            """)
    }

    @Test("la convergencia deja fuera los gastos y las liquidaciones del reparto")
    func convergenceScope() {
        let a = UUID(), b = UUID()
        #expect(GroupsBridgeRestoreConvergenceLogic.expensesToConverge(local: [a, b], excluded: [a.uuidString]) == [b])
        #expect(GroupsBridgeRestoreConvergenceLogic.expensesToConverge(local: [a, b], excluded: []) == [a, b])
        #expect(GroupsBridgeRestoreConvergenceLogic.settlementsToReBridge(
            confirmed: [a, b], legSettlementIDs: [], excluded: [a.uuidString]) == [b])
        #expect(GroupsBridgeRestoreConvergenceLogic.settlementsToReBridge(
            confirmed: [a, b], legSettlementIDs: [b.uuidString], excluded: []) == [a])
    }
}

/// Un iCloud-KV con, como mucho, un reparto: vacío, el reparto aún no llegó.
private final class EmptyKeyValueStore: OwnerKeyValueWriting {
    var stored: String?
    func setBool(_ value: Bool, forKey key: String) {}
    func setString(_ value: String, forKey key: String) {}
    func setDouble(_ value: Double, forKey key: String) {}
    func setInt(_ value: Int, forKey key: String) {}
    func removeObject(forKey key: String) {}
    func bool(forKey key: String) -> Bool { false }
    func string(forKey key: String) -> String? { key == GroupsRemoteWipeDivisionStore.kvKey ? stored : nil }
    func double(forKey key: String) -> Double { 0 }
    func longLong(forKey key: String) -> Int64 { 0 }
    func object(forKey key: String) -> Any? { nil }
    @discardableResult func synchronize() -> Bool { true }
}
