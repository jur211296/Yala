//
//  TwoPersonSplitOptions.swift
//  Yala
//
//  Pre-pantalla de split rápido para grupos de DOS personas (estilo Splitwise): las 4
//  combinaciones más comunes de (pagador × reparto) presentadas en lenguaje natural.
//  Pure-logic: mapea cada opción a un estado válido del GroupExpenseViewModel y hace el
//  match inverso. Sin SwiftUI ni L10n — la localización vive en el callsite.
//

import Foundation

enum TwoPersonSplitOptions {

    /// Las 4 opciones rápidas para un grupo de 2. El pagador queda implícito en cada una.
    /// `rawValue` se usa como param de telemetría.
    enum Choice: String, CaseIterable, Identifiable {
        case iPaidEqual         // yo pagué, partes iguales → la otra persona me debe la mitad
        case iPaidOwedFull      // yo pagué, es todo de la otra persona → me debe el total
        case theyPaidEqual      // pagó la otra persona, partes iguales → yo le debo la mitad
        case theyPaidOwedFull   // pagó la otra persona, es todo mío → yo le debo el total

        var id: String { rawValue }

        /// Dirección del saldo resultante — depende solo de la opción, no del monto.
        var debtDirection: DebtDirection {
            switch self {
            case .iPaidEqual, .iPaidOwedFull: return .theyOweMe
            case .theyPaidEqual, .theyPaidOwedFull: return .iOwe
            }
        }
    }

    /// Dirección del saldo resultante respecto al usuario actual.
    enum DebtDirection { case theyOweMe, iOwe }

    /// Estado del split que una `Choice` escribe en el ViewModel.
    struct Resolution: Equatable {
        let paidBy: String
        let participants: Set<String>
        let splitType: SplitType
    }

    /// Estado que escribe cada opción. Las opciones "es todo de X" usan `.equal` con un
    /// ÚNICO participante (quien debe): `GroupSplitCalculator` le asigna el total y el
    /// pagador queda fuera de `participants` (soportado desde el commit 22fb9374).
    static func resolution(
        for choice: Choice,
        currentMemberID: String,
        otherMemberID: String
    ) -> Resolution {
        switch choice {
        case .iPaidEqual:
            return Resolution(paidBy: currentMemberID, participants: [currentMemberID, otherMemberID], splitType: .equal)
        case .iPaidOwedFull:
            return Resolution(paidBy: currentMemberID, participants: [otherMemberID], splitType: .equal)
        case .theyPaidEqual:
            return Resolution(paidBy: otherMemberID, participants: [currentMemberID, otherMemberID], splitType: .equal)
        case .theyPaidOwedFull:
            return Resolution(paidBy: otherMemberID, participants: [currentMemberID], splitType: .equal)
        }
    }

    /// Match inverso: qué `Choice` representa el estado actual, o `nil` si es "personalizado"
    /// (cualquier `splitType` ≠ `.equal`, o un conjunto de participantes que no calza con las 4).
    /// Exige `.equal` en los 4 casos para que el round-trip `detect(resolution(c)) == c` se cumpla.
    static func detect(
        paidByMemberID: String,
        splitType: SplitType,
        selectedMemberIDs: Set<String>,
        currentMemberID: String,
        otherMemberID: String
    ) -> Choice? {
        guard splitType == .equal else { return nil }
        // Solo cuentan los 2 miembros del grupo; ignora ids ajenos defensivamente.
        let participants = selectedMemberIDs.intersection([currentMemberID, otherMemberID])
        let both: Set<String> = [currentMemberID, otherMemberID]

        if paidByMemberID == currentMemberID {
            if participants == both { return .iPaidEqual }
            if participants == [otherMemberID] { return .iPaidOwedFull }
        } else if paidByMemberID == otherMemberID {
            if participants == both { return .theyPaidEqual }
            if participants == [currentMemberID] { return .theyPaidOwedFull }
        }
        return nil
    }

    /// Saldo resultante de cada opción para un total dado: dirección + monto.
    /// `equal` → la mitad; `owedFull` → el total.
    static func debt(for choice: Choice, total: Double) -> (direction: DebtDirection, amount: Double) {
        let amount: Double
        switch choice {
        case .iPaidEqual, .theyPaidEqual: amount = total / 2
        case .iPaidOwedFull, .theyPaidOwedFull: amount = total
        }
        return (choice.debtDirection, amount)
    }
}
