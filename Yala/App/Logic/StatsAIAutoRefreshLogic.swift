//
//  StatsAIAutoRefreshLogic.swift
//  Yala
//
//  Cuándo se genera SOLO un texto con IA de Estadísticas (encargo `estadisticas-ia-automatica`, 2026-11-03, pedido
//  de Jürgen del 2026-11-02): Pro con la IA aceptada, una vez al día o ante un cambio relevante de sus datos, con
//  antirrebote y techo duro diario.
//
//  Lógica pura: quien la llama le da lo guardado, lo que se ve ahora, lo que ya se generó hoy y el reloj.
//
//  Las reglas, en orden:
//  1. Sin Pro, sin consentimiento o con menos de `minimumTransactions` registros: nada.
//  2. Mismas cifras que lo guardado: se enseña lo guardado, tenga la edad que tenga. Diría lo mismo (decisión de
//     Jürgen del 2026-10-18 en L11-7).
//  3. Antirrebote: si esta ranura se generó o se intentó hace menos de `cooldown`, nada (la próxima apertura lo recoge).
//  4. Sin nada guardado para esta ranura (página + período + filtros + tono…): se genera. Con cifras distintas y un
//     cambio RELEVANTE (`isRelevantChange`), también.
//  5. Cifras distintas sin cambio relevante: se regenera solo si lo guardado tiene `staleAfter` o más y la página no
//     generó nada hoy («una al día»).
//  Y por encima de 2, 4 y 5, el techo: `dailyCap` generaciones AUTOMÁTICAS por página y día.
//

import Foundation

enum StatsAIAutoRefreshLogic {

    /// Las páginas de Estadísticas con texto de IA propio. Distribución reusa el de Resumen.
    enum Page: String, Codable, CaseIterable {
        case summary
        case trends
    }

    /// Por qué se genera. Solo informa (rastro en DEBUG y tests).
    enum Reason: String, Equatable {
        case firstTime
        case relevantChange
        case daily
    }

    enum Decision: Equatable {
        /// No toca: sin Pro, sin consentimiento o con pocos registros.
        case notAllowed
        /// Lo guardado (si lo hay) se queda; no se llama a nadie.
        case keepSaved
        case generate(Reason)
    }

    /// Las cifras que deciden si un cambio es relevante: cuántos registros y los totales que el texto cita.
    struct Snapshot: Codable, Equatable {
        var transactionCount: Int
        var totals: [Double]
    }

    /// Lo guardado de una ranura.
    struct Saved: Equatable {
        var fingerprint: String
        var savedAt: Date
        var snapshot: Snapshot
    }

    /// Lo que la página ya generó hoy.
    struct Today: Equatable {
        /// Generaciones automáticas de la página hoy (día de calendario local).
        var automaticCount: Int
        /// Cualquier generación de la página hoy, automática o pedida a mano.
        var anyCount: Int
        /// La última generación de ESTA ranura, de cualquier día.
        var lastForSlot: Date?
    }

    static let minimumTransactions = 5
    static let dailyCap = 4
    static let staleAfter: TimeInterval = 24 * 60 * 60
    static let cooldown: TimeInterval = 10 * 60
    static let relevantCountDelta = 3
    static let relevantTotalFraction = 0.10

    static func decide(
        isPro: Bool,
        hasConsent: Bool,
        transactionCount: Int,
        saved: Saved?,
        fingerprint: String,
        snapshot: Snapshot,
        today: Today,
        now: Date
    ) -> Decision {
        guard isPro, hasConsent, transactionCount >= minimumTransactions else { return .notAllowed }
        if saved?.fingerprint == fingerprint { return .keepSaved }
        // Antirrebote: esta ranura ya se generó (o se intentó) hace nada. Vale también para la primera: un intento que
        // falló no se repite en cada recálculo, sino en la próxima apertura pasado el plazo.
        if let last = today.lastForSlot, now.timeIntervalSince(last) < cooldown { return .keepSaved }
        let underCap = today.automaticCount < dailyCap

        guard let saved else { return underCap ? .generate(.firstTime) : .keepSaved }

        if isRelevantChange(from: saved.snapshot, to: snapshot) {
            return underCap ? .generate(.relevantChange) : .keepSaved
        }

        let isStale = now.timeIntervalSince(saved.savedAt) >= staleAfter
        guard isStale, today.anyCount == 0, underCap else { return .keepSaved }
        return .generate(.daily)
    }

    /// ±`relevantCountDelta` registros, o algún total que se mueve `relevantTotalFraction` o más. Con un número
    /// distinto de totales (otra forma de pantalla) cuenta como relevante.
    static func isRelevantChange(from old: Snapshot, to new: Snapshot) -> Bool {
        if abs(new.transactionCount - old.transactionCount) >= relevantCountDelta { return true }
        guard old.totals.count == new.totals.count else { return true }
        for (before, after) in zip(old.totals, new.totals) {
            let base = max(abs(before), 1)
            if abs(after - before) / base >= relevantTotalFraction { return true }
        }
        return false
    }
}
