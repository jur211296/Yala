//
//  GroupsIdentityBootGuardLogicTests.swift
//  YalaTests
//
//  Tabla exhaustiva del boot-guard de identidad de Grupos (GAP 1). Molde
//  SplitSyncStartGateTests: pure-logic, sin SwiftData ni CloudKit.
//
//  La invariante que protege la tabla: la limpieza (destructiva de cache local)
//  SOLO corre con DOS valores válidos no-vacíos DISTINTOS — cualquier ausencia de
//  evidencia (fetch fallido, cache vacío, valores vacíos) es `.none`.
//

import Testing

@testable import Yala

@Suite("GroupsIdentityBootGuardLogic · GAP 1 boot-guard")
struct GroupsIdentityBootGuardLogicTests {

    @Test func mismatchReal_dosValoresValidosDistintos_limpia() {
        #expect(GroupsIdentityBootGuardLogic.decide(cached: "_abc123", fresh: "_def456") == .runSwitchCleanup)
    }

    @Test func match_mismaIdentidad_noHaceNada() {
        #expect(GroupsIdentityBootGuardLogic.decide(cached: "_abc123", fresh: "_abc123") == .none)
    }

    @Test func cachedNil_primeraInstalacion_noHaceNada() {
        #expect(GroupsIdentityBootGuardLogic.decide(cached: nil, fresh: "_abc123") == .none)
    }

    @Test func cachedVacio_noHaceNada() {
        #expect(GroupsIdentityBootGuardLogic.decide(cached: "", fresh: "_abc123") == .none)
    }

    /// Fetch fallido (red / .notAuthenticated) → el caller pasa nil → JAMÁS limpiar.
    @Test func freshNil_fetchFallido_noLimpia() {
        #expect(GroupsIdentityBootGuardLogic.decide(cached: "_abc123", fresh: nil) == .none)
    }

    @Test func freshVacio_noLimpia() {
        #expect(GroupsIdentityBootGuardLogic.decide(cached: "_abc123", fresh: "") == .none)
    }

    @Test func ambosNil_noHaceNada() {
        #expect(GroupsIdentityBootGuardLogic.decide(cached: nil, fresh: nil) == .none)
    }

    @Test func ambosVacios_noHaceNada() {
        #expect(GroupsIdentityBootGuardLogic.decide(cached: "", fresh: "") == .none)
    }
}
