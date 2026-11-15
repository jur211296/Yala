//
//  GroupMenosPagosLogic.swift
//  Yala
//
//  Decisión 36 de la revisión 2.3 (A1, Jürgen, 9-nov): «Menos pagos entre ustedes» nace encendido en los grupos nuevos y,
//  cuando junta deudas, Saldos lo dice al pie y deja ver las de cada par. Los grupos que ya existen no cambian.
//
//  Pura: no lee SwiftData ni pinta nada.
//

import Foundation

/// Lo que trae un grupo nuevo en el formulario de crear.
enum GroupFormDefaults {
    /// «Menos pagos entre ustedes» encendido al crear. La decisión habla de grupos «de 3 o más», pero al crear todavía no
    /// hay nadie más y con dos personas juntar las deudas da lo mismo que no juntarlas: el efecto solo se ve con 3 o más.
    /// El modelo (`SplitGroup.simplifyDebts`) sigue naciendo en `false`: lo que baja del servidor trae su valor y los
    /// grupos existentes conservan el suyo.
    static let simplifyDebtsForNewGroup = true
}

/// La línea al pie de «Para quedar a mano» en Saldos.
enum GroupMenosPagosNoteLogic {

    /// Qué lista de deudas se ve debajo de la cifra.
    enum Shown: Equatable {
        /// Las del grupo, juntadas por «Menos pagos». Se pueden saldar.
        case simplified
        /// Las de cada par, sin juntar: solo para mirar (la opción del grupo es de todos y no se toca).
        case pairs
    }

    /// La línea sale solo si el grupo junta las deudas, tiene 3 o más miembros activos y juntar CAMBIA algo: con dos
    /// personas, o cuando las de cada par ya son las mínimas, no hay nada que contar ni otra lista que ver. Sin las de
    /// cada par calculadas (la opción se acaba de encender y el ViewModel aún no recalculó) tampoco: «Ver las deudas de
    /// cada par» enseñaría una lista vacía.
    static func showsNote(
        simplifyDebts: Bool,
        activeMemberCount: Int,
        simplified: [Debt],
        pairs: [Debt]
    ) -> Bool {
        guard simplifyDebts, activeMemberCount >= 3, !pairs.isEmpty else { return false }
        return normalized(simplified) != normalized(pairs)
    }

    /// Las deudas en un orden fijo y con el importe en céntimos: dos listas con las mismas deudas en otro orden son la
    /// misma, y los repartos dejan fracciones de céntimo que no son una diferencia.
    private static func normalized(_ debts: [Debt]) -> [String] {
        debts
            .filter { $0.amount >= 0.005 }
            .map { "\($0.fromMemberID)|\($0.toMemberID)|\($0.currencyCode)|\(Int(($0.amount * 100).rounded()))" }
            .sorted()
    }
}
