//
//  RelaunchChecklistCopyLogic.swift
//  Yala
//
//  Qué dice la tarjeta de «reabre Yala» de Ajustes en cada caso (UX 2.2 · L20-18). Pura y aparte para poder fijar con
//  tests que cada check es verdad en su caso: un «ya están en la nube» en la vuelta a iCloud sería mentir en la
//  pantalla que pide el último paso.
//

import Foundation

enum RelaunchChecklistCopyLogic {
    nonisolated struct Copy: Equatable {
        let title: String
        let done: [String]
        let afterNote: String?
    }

    /// - `toCloud`: la ida (el mirror-off se arma tras verificar la subida) o el adopt (la cuenta ya tenía los datos).
    /// - `toCloud` tras una vuelta cancelada: los datos siguen en la nube, y la vuelta se paró.
    /// - `toICloud`: la vuelta bajó todo a este iPhone; al reabrir empieza a subir a iCloud.
    static func storage(direction: CloudMigrationUIState.RelaunchDirection, reverseAborted: Bool) -> Copy {
        switch direction {
        case .toCloud where reverseAborted:
            return Copy(title: L10n.Storage.ReverseAbort.relaunchTitle,
                        done: [L10n.UXL20N.relaunchDoneReverseStopped],
                        afterNote: nil)
        case .toCloud:
            return Copy(title: L10n.UXL20N.relaunchAlmostTitle,
                        done: [L10n.UXL20N.relaunchDoneInCloud],
                        afterNote: nil)
        case .toICloud:
            return Copy(title: L10n.UXL20N.relaunchAlmostTitle,
                        done: [L10n.UXL20N.relaunchDoneOnPhone],
                        afterNote: L10n.UXL20N.relaunchAfterToICloud)
        }
    }
}
