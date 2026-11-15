//
//  MigrationImportWaitLogic.swift
//  Yala
//
//  La pre-espera de «Activar la nube» a que iCloud termine de importar (`CloudMigrationController
//  .awaitImportQuiescenceForResume`, tope de 300 s): cuándo se puede cancelar y qué se cuenta al vencer. Ticket
//  `cloud-activation-waits-for-icloud-with-no-way-out` (QA guiado del 2026-10-19: con 6 movimientos la espera pasó de 5 min,
//  la pantalla no cambiaba y «Cancelar la activación» estaba apagado).
//
//  Pura.
//

import Foundation

nonisolated enum MigrationImportWaitLogic {

    /// ¿Se puede tocar «Cancelar la activación»? Con una pasada del runner en vuelo, no: la cancelación es de una activación
    /// aparcada. **Mientras la pre-espera del import, sí**: esa espera todavía no ha tocado el runner (no sube ni escribe
    /// nada) y puede durar minutos; con el botón apagado, la persona no tenía salida. El «sí» corta la espera y se apunta en
    /// el runner, que lo honra en cuanto iCloud deje escribir el journal.
    ///
    /// Con una cancelación ya en marcha, no: su propia espera es una pre-espera más, y un segundo toque la cortaba y la dejaba
    /// sin cancelar (review adversarial). El «sí» ya está apuntado en el runner.
    ///
    /// **Y con el EFECTO del adopt en vuelo, también** (card gd78, medido en el iPhone 14 el 13-nov). Cada reintento del
    /// efecto vuelve a leer la cuenta entera (~40 s con 5.900 filas) y el auto-resume encadena reintentos: el botón pasaba
    /// casi todo el tiempo apagado y la persona no tenía salida. El «sí» se apunta en el runner (`requestMigrationCancel`) y
    /// el efecto lo honra en su siguiente reintento (`drive()`), así que tocarlo con trabajo en vuelo no deja nada a medias.
    static func cancelEnabled(isWorking: Bool, waitingForImport: Bool, cancelling: Bool,
                              adoptEffectPending: Bool = false) -> Bool {
        guard !cancelling else { return false }
        return !isWorking || waitingForImport || adoptEffectPending
    }

    /// Qué tenía a iCloud sin asentarse cuando venció el tope, para el canario `cloudMigrationImportNotSettled`. La causa
    /// del ticket quedó INFERIDA (imports que terminan cada menos de 8 s, o uno que no termina): esto la mide en la flota.
    /// - `stillImporting`: el estado sigue en `.syncing(.importing)` al vencer (un import que no termina).
    /// - `importsFinished`: cuántos imports terminaron durante la espera (cada uno reabre la ventana de 8 s).
    static func stallDetail(stillImporting: Bool, importsFinished: Int) -> String {
        let cause = stillImporting ? "importing" : "recentImport"
        let bucket: String
        switch importsFinished {
        case ..<1: bucket = "0"
        case 1...10: bucket = "1-10"
        case 11...50: bucket = "11-50"
        default: bucket = "gt50"
        }
        return "\(cause)|\(bucket)"
    }

    /// El mismo canario cuando la espera que vence es la de cada entrada del runner (120 s; card ppxk): no cuenta imports,
    /// así que el segundo segmento es `runner` y la serie distingue las dos esperas sin cambiar de nombre.
    static func runnerStallDetail(stillImporting: Bool) -> String {
        "\(stillImporting ? "importing" : "recentImport")|runner"
    }
}
