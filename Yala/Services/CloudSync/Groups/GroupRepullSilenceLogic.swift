//
//  GroupRepullSilenceLogic.swift
//  Yala
//
//  Card vj61 (2026-11-03) · lo que vuelve a bajar no es una edición.
//
//  Cuatro caminos ponen a 0 el cursor de un grupo y lo vuelven a bajar entero: la subida de versión del canal
//  (`applyCapabilityUpgradeIfPending`, card u8cl), el descarte de un saldo inicial rechazado
//  (`settleRejectedOpeningBalances`, card e6fd), el remedio del Merkle (`resetGroupCursors`) y la re-entrada de quien
//  estaba pendiente. El apply lee cada gasto que ya existía como «gasto modificado» y avisaba. Hasta esta card lo
//  silenciaba un conjunto EN MEMORIA de grupos en re-bajada: un kill tras la primera página de un grupo de más de 500
//  filas lo perdía, y al relanzar cada gasto que ya estaba avisaba; el Merkle no lo llenaba nunca.
//
//  La regla, ahora: el pull entrega solo la versión vigente de cada fila, con el `server_seq` de su último cambio. Si ese
//  `server_seq` es ≤ el más alto que este teléfono ya APLICÓ de ese grupo, la fila no cambió desde que se vio, y no
//  avisa. Ese máximo vive en disco junto al cursor (`GroupSyncCursor.groupSeenSeqJSON`) y no baja nunca. Una edición de
//  otro miembro durante la re-bajada trae un `server_seq` mayor y SÍ avisa, que el conjunto en memoria silenciaba.
//

nonisolated enum GroupRepullSilenceLogic {

    /// El máximo visto tras escribir `next` encima de `previous`. Un reset (`next` a 0) conserva el valor de antes.
    static func raisedSeen(
        _ seen: [String: Int64], previous: [String: Int64], next: [String: Int64]
    ) -> [String: Int64] {
        var result = seen
        for (gid, seq) in previous where seq > (result[gid] ?? 0) { result[gid] = seq }
        for (gid, seq) in next where seq > (result[gid] ?? 0) { result[gid] = seq }
        return result
    }

    /// Lo visto al empezar una página: lo guardado y, para las filas de un build anterior sin el campo, los cursores.
    static func seenAtPageStart(stored: [String: Int64], cursors: [String: Int64]) -> [String: Int64] {
        raisedSeen(stored, previous: [:], next: cursors)
    }

    /// ¿Esta versión de la fila ya estaba en el teléfono? Sin nada visto del grupo, no.
    static func isRedelivery(serverSeq: Int64, groupID: String, seen: [String: Int64]) -> Bool {
        guard let seenSeq = seen[groupID], seenSeq > 0 else { return false }
        return serverSeq <= seenSeq
    }
}
