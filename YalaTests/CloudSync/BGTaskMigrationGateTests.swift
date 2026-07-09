//
//  BGTaskMigrationGateTests.swift
//  YalaTests
//
//  Pure-logic tests del gate §i.9 (`BGTaskMigrationGate.decide`). Matriz EXHAUSTIVA fase × rol ×
//  quiescencia. Los 12 asserts POSITIVOS (estados estables → `.run` incondicional) van PRIMERO y por
//  caso explícito — son el guard del bug INVERTIDO (gatear en estable = reports muertos para el 100%).
//
//  Sin SwiftData, sin iCloud: `MigrationPhase` es el enum puro que consume el gate.
//

import Foundation
import Testing

@testable import Yala

@Suite("BGTask Migration Gate (§i.9)")
struct BGTaskMigrationGateTests {

    // MARK: - 12 POSITIVOS PRIMERO — estables × ambos roles × ambas quiescencias → `.run` incondicional
    // (notStarted, done, failedRollback) × (reader, writer) × (quiescent, not) = 12 casos `.run`.

    // notStarted (el estado del 100% de usuarios iCloud que nunca tocaron la nube)
    @Test func positive_notStarted_reader_quiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .notStarted, isImportQuiescent: true, role: .reader) == .run)
    }
    @Test func positive_notStarted_reader_notQuiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .notStarted, isImportQuiescent: false, role: .reader) == .run)
    }
    @Test func positive_notStarted_writer_quiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .notStarted, isImportQuiescent: true, role: .writer) == .run)
    }
    @Test func positive_notStarted_writer_notQuiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .notStarted, isImportQuiescent: false, role: .writer) == .run)
    }

    // done (usuario ya migrado, operando estable en la nube)
    @Test func positive_done_reader_quiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .done, isImportQuiescent: true, role: .reader) == .run)
    }
    @Test func positive_done_reader_notQuiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .done, isImportQuiescent: false, role: .reader) == .run)
    }
    @Test func positive_done_writer_quiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .done, isImportQuiescent: true, role: .writer) == .run)
    }
    @Test func positive_done_writer_notQuiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .done, isImportQuiescent: false, role: .writer) == .run)
    }

    // failedRollback (la transición TERMINÓ; el device quedó idéntico a como empezó → ES estable)
    @Test func positive_failedRollback_reader_quiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .failedRollback, isImportQuiescent: true, role: .reader) == .run)
    }
    @Test func positive_failedRollback_reader_notQuiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .failedRollback, isImportQuiescent: false, role: .reader) == .run)
    }
    @Test func positive_failedRollback_writer_quiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .failedRollback, isImportQuiescent: true, role: .writer) == .run)
    }
    @Test func positive_failedRollback_writer_notQuiescent_runs() {
        #expect(BGTaskMigrationGate.decide(phase: .failedRollback, isImportQuiescent: false, role: .writer) == .run)
    }

    // MARK: - Inventario manual de fases (guard de exhaustividad de la matriz transitoria)

    /// TODAS las fases transitorias (migración en curso), incl. los 5 sub-estados de cutover.
    static let transientPhases: [MigrationPhase] = [
        .dryRun,
        .consent,
        .authenticating,
        .waitingForLeader,
        .claimingMigration,
        .assigningIdentity,
        .uploadingSnapshot,
        .verifying,
        .cutover(.pending),
        .cutover(.serverConfirmed),
        .cutover(.localModeSet),
        .cutover(.markerWritten),
        .cutover(.mirrorOff)
    ]

    static let stablePhases: [MigrationPhase] = [.notStarted, .done, .failedRollback]

    // MARK: - Transitorio · LECTOR → `.suspendAndReschedule` SIEMPRE (ignora quiescencia)

    @Test(arguments: transientPhases, [true, false])
    func transient_reader_alwaysSuspends(phase: MigrationPhase, quiescent: Bool) {
        #expect(
            BGTaskMigrationGate.decide(phase: phase, isImportQuiescent: quiescent, role: .reader)
                == .suspendAndReschedule
        )
    }

    // MARK: - Transitorio · ESCRITOR con quiescencia → `.run`

    @Test(arguments: transientPhases)
    func transient_writer_quiescent_runs(phase: MigrationPhase) {
        #expect(
            BGTaskMigrationGate.decide(phase: phase, isImportQuiescent: true, role: .writer) == .run
        )
    }

    // MARK: - Transitorio · ESCRITOR sin quiescencia → `.deferAndReschedule`

    @Test(arguments: transientPhases)
    func transient_writer_notQuiescent_defers(phase: MigrationPhase) {
        #expect(
            BGTaskMigrationGate.decide(phase: phase, isImportQuiescent: false, role: .writer)
                == .deferAndReschedule
        )
    }

    // MARK: - Sub-estados de cutover explícitos (los 5, ambos roles) — cutover es transitorio ENTERO

    @Test(arguments: CutoverSubstate.allCases)
    func cutover_reader_suspends(sub: CutoverSubstate) {
        #expect(
            BGTaskMigrationGate.decide(phase: .cutover(sub), isImportQuiescent: false, role: .reader)
                == .suspendAndReschedule
        )
    }

    @Test(arguments: CutoverSubstate.allCases)
    func cutover_writer_gatedByQuiescence(sub: CutoverSubstate) {
        #expect(
            BGTaskMigrationGate.decide(phase: .cutover(sub), isImportQuiescent: true, role: .writer) == .run
        )
        #expect(
            BGTaskMigrationGate.decide(phase: .cutover(sub), isImportQuiescent: false, role: .writer)
                == .deferAndReschedule
        )
    }

    // MARK: - Invariante del bug invertido: NINGUNA fase estable gatea en NINGÚN camino

    @Test func stablePhases_neverGate_anyRoleAnyQuiescence() {
        for phase in Self.stablePhases {
            for quiescent in [true, false] {
                #expect(
                    BGTaskMigrationGate.decide(phase: phase, isImportQuiescent: quiescent, role: .reader) == .run
                )
                #expect(
                    BGTaskMigrationGate.decide(phase: phase, isImportQuiescent: quiescent, role: .writer) == .run
                )
            }
        }
    }

    // MARK: - Invariante recíproco: NINGUNA fase transitoria corre en el LECTOR

    @Test func transientPhases_readerNeverRuns() {
        for phase in Self.transientPhases {
            for quiescent in [true, false] {
                #expect(
                    BGTaskMigrationGate.decide(phase: phase, isImportQuiescent: quiescent, role: .reader)
                        != .run
                )
            }
        }
    }
}
