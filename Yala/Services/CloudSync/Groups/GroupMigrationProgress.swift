//
//  GroupMigrationProgress.swift
//  Yala
//
//  Estado observable MÍNIMO del `GroupMigrationUploader` (G6-3, C3): la UI de Grupos muestra un banner simple
//  "moviendo tus grupos a la nube de Yala…" mientras corre. NO bloquea la app (el upload es un Task del boot).
//

import Foundation
import Observation

@MainActor
@Observable
final class GroupMigrationProgress {
    static let shared = GroupMigrationProgress()

    /// `true` mientras el uploader procesa grupos. La vista de Grupos muestra el banner.
    private(set) var isMigrating = false
    /// Grupos que faltan por migrar en la pasada actual (informativo).
    private(set) var groupsRemaining = 0

    private init() {}

    func begin(total: Int) {
        isMigrating = total > 0
        groupsRemaining = total
    }

    func noteGroupFinished() {
        groupsRemaining = max(0, groupsRemaining - 1)
    }

    func finish() {
        isMigrating = false
        groupsRemaining = 0
    }
}
