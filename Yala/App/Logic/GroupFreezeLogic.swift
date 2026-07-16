//
//  GroupFreezeLogic.swift
//  Yala
//
//  Pure-logic del estado CONGELADO de un grupo migrado al backend (G6-3, C4). Sin SwiftData/ModelContext →
//  testeable en aislamiento (evita la flake R8 documentada en CLAUDE.md → makeTestContext).
//

import Foundation
import SwiftData

extension SplitGroup {
    /// G6-3: `true` = grupo migrado y CONGELADO para este device (member no re-joineado). Convenience sobre
    /// `GroupFreezeLogic.isFrozen` leyendo el estado vivo del `@Model`. La RED es el guard service-level
    /// (`validateGroupIsWritable`); esto alimenta la derivación de tarjeta/banner/CTA.
    @MainActor
    var isMigratedFrozen: Bool {
        GroupFreezeLogic.isFrozen(
            movedToBackendAt: movedToBackendAt,
            isBackendGroup: isBackendGroup,
            isOwner: isOwner,
            hasCKSystemFields: ckSystemFieldsData != nil
        )
    }
}

enum GroupFreezeLogic {
    /// Estado CONGELADO de un grupo tras la migración a backend. `true` en el device de un MIEMBRO que aún NO
    /// re-joineó por el backend: la zona CloudKit quedó viva pero sus writes se PERDERÍAN (la verdad vive en el
    /// backend) → hay que congelar las escrituras y mostrar el CTA "vuelve a entrar".
    ///
    /// Predicado base: `movedToBackendAt != nil && !isBackendGroup`.
    ///
    /// - En el OWNER que ya adoptó (`isBackendGroup=true`) → NO congelado (sus writes van al backend por el
    ///   drain — el guard `!isBackendGroup` lo cubre).
    /// - MITIGACIÓN ajuste #9 (owner tras REINSTALL/restore): `isBackendGroup` es LOCAL-only y se pierde en un
    ///   reinstall, PERO `movedToBackendAt` viaja por CloudKit → el owner aparecería transitoriamente
    ///   "congelado" con un CTA de re-join sin sentido hasta que el pull de adopción re-flipee `isBackendGroup`.
    ///   Un grupo `isOwner && ckSystemFieldsData != nil && movedToBackendAt != nil` se trata como NO congelado
    ///   (owner con zona CloudKit conocida — el uploader/pull lo re-adoptará). Residual documentado: sus writes
    ///   en esa ventana van a CloudKit y se pierden hasta el re-flip (mismo residual que el brief C1 #9).
    static func isFrozen(
        movedToBackendAt: Date?,
        isBackendGroup: Bool,
        isOwner: Bool,
        hasCKSystemFields: Bool
    ) -> Bool {
        guard movedToBackendAt != nil, !isBackendGroup else { return false }
        if isOwner && hasCKSystemFields { return false }  // mitigación #9 (owner reinstall transitorio)
        return true
    }
}
