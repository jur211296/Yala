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

    /// C-10: grupos que NO se migraron porque algún miembro todavía no puede volver a entrar por el
    /// backend. La UI del owner lo usa para decir "esperamos a que todos actualicen" en vez de callar —
    /// sin esto, una migración bloqueada sería indistinguible de una que nunca arrancó.
    private(set) var groupsWaitingForMembers = 0

    private init() {}

    func begin(total: Int) {
        isMigrating = total > 0
        groupsRemaining = total
        groupsWaitingForMembers = 0
    }

    func noteGroupFinished() {
        groupsRemaining = max(0, groupsRemaining - 1)
    }

    /// C-10: este grupo quedó esperando a sus miembros.
    func noteBlockedByMembers() {
        groupsWaitingForMembers += 1
    }

    func finish() {
        isMigrating = false
        groupsRemaining = 0
        // `groupsWaitingForMembers` NO se resetea aquí a propósito: el banner del owner tiene que
        // seguir visible DESPUÉS de que la pasada termine — es justo entonces cuando el usuario mira la
        // lista y se pregunta por qué su grupo sigue igual. Lo resetea el `begin` de la próxima pasada.
    }
}
