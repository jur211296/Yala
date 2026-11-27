//
//  CargaPanelPorTramos.swift
//  Yala
//
//  Lote 8 de eficiencia (27-nov-2026). Las piezas de la carga del Panel que se recorren por tramos
//  (`PanelViewModel.cargarPorTramos`). Con 16.004 movimientos en el iPhone 14 la carga del arranque dejaba un bloque de
//  ~0,55 s en el hilo principal.
//

import Foundation
import SwiftData
import os

@MainActor
enum CargaPanelPorTramos {

    /// Las filas que miran el ajuste de los gastos de grupo (`GroupBridgeStatsAdjustment.build`) y el recuento de
    /// movimientos sin cuenta (`OrphanedRecordsService.orphanCount`): las que llevan puntero a un gasto de grupo y las que
    /// no tienen cuenta. Las dos funciones recorrían los 16 k movimientos para descartar todas las demás:
    /// - `build` agrupa solo por `splitExpenseID`;
    /// - `orphanCount` solo cuenta filas sin cuenta, y su evidencia (`GroupLegEvidence.read`) mira las sin cuenta y, para
    ///   ellas, sus hermanas con cuenta por `splitExpenseID`.
    /// Una fila con cuenta y sin `splitExpenseID` (también la pata de una liquidación con cuenta) no cambia ninguna de las
    /// dos cifras. Si una de esas funciones empieza a mirar otra fila, esto se queda corto: lo fija `CargaPanelParidadTests`.
    static func importaAGruposOHuerfanos(_ tx: TransactionItem) -> Bool {
        tx.splitExpenseID != nil || tx.account == nil
    }
}

/// Las líneas de la tarjeta «Grupos» del Panel, fila a fila: los movimientos de las cuentas sistema de Grupos que suman
/// los saldos de las cuentas, por el grupo al que apuntan (`GroupsAccountCardLogic.groupLines`). Era un recorrido aparte
/// de `calculateAccountBalances`; ahora se suma en la misma pasada que los saldos.
@MainActor
struct LineasDeLaTarjetaDeGrupos {
    private let cutoff: LiveBalanceCalculator.TodayCutoff
    private let systemIDs: Set<PersistentIdentifier>
    private(set) var movimientos: [GroupsAccountCardLogic.Movement] = []

    init(accounts: [Account], asOf now: Date = .now) {
        cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now)
        systemIDs = Set(accounts.filter { $0.isSystemAccount && !$0.isArchived }.map(\.persistentModelID))
    }

    mutating func sumar(_ tx: TransactionItem) {
        guard !systemIDs.isEmpty, cutoff.counts(tx.date), let account = tx.account,
              systemIDs.contains(account.persistentModelID) else { return }
        let pointsToGroup = tx.splitExpenseID != nil || tx.splitSettlementID != nil
        movimientos.append(.init(zoneID: pointsToGroup ? tx.splitGroupZoneID : nil,
                                 currencyCode: account.currencyCode, amount: tx.amount))
    }

    var lineas: [GroupsAccountCardLogic.GroupLine] { GroupsAccountCardLogic.groupLines(movimientos) }
}

/// Marcas de la carga del Panel: un intervalo `os_signpost` «Panel.carga» (`com.yala` / `PanelCarga`) y, en DEBUG,
/// `PERF panel-carga total … · tramo máx … · cesiones …`. El tramo más largo es la cifra del encargo (< ~100 ms).
@MainActor
final class MarcasCargaPanel {
    nonisolated static let signposter = OSSignposter(subsystem: "com.yala", category: "PanelCarga")

    private let reloj = ContinuousClock()
    private let inicio: ContinuousClock.Instant
    private let estado: OSSignpostIntervalState

    init() {
        inicio = reloj.now
        estado = Self.signposter.beginInterval("Panel.carga")
    }

    func terminar(completada: Bool, cesion: CesionDelHilo) {
        Self.signposter.endInterval("Panel.carga", estado)
        #if DEBUG
        let total = reloj.now - inicio
        print("PERF panel-carga \(completada ? "completa" : "cortada") total \(MarcasRecalculoPanel.ms(total))"
              + " · tramo máx \(MarcasRecalculoPanel.ms(cesion.tramoMasLargo)) · cesiones \(cesion.cesiones)")
        #endif
    }
}
