//
//  GroupMigrationStateTests.swift
//  YalaTests
//
//  C-10: matriz del estado de migración PRESENTABLE — (marcador presente/ausente) × (capacidad del build)
//  × (sesión presente/ausente) × (isOwner / ckSystemFields / isBackendGroup).
//
//  El bug que cubren: `movedToBackendAt` viaja por CloudKit y congela, pero la capacidad de volver a
//  entrar es COMPILADA por build. Un miembro con un build viejo quedaba mirando un grupo congelado, mudo
//  y sin salida.
//
//  Pure-logic: sin SwiftData ni ModelContext (molde `GroupCardDisplayLogicTests`).
//

import Foundation
import Testing

@testable import Yala

// MARK: - Capacidad del build

struct GroupBackendCapabilityTests {

    @Test func resolve_canRejoin_whenCompiledAndConfiguredAndChannelOn() {
        #expect(GroupBackendCapability.resolve(
            compiledCapability: true, backendConfigured: true, remoteChannelEnabled: true) == .canRejoin)
    }

    @Test func resolve_channelPaused_whenCapableButRemoteKilled() {
        // Un kill remoto NO significa "tu app está mal": el binario es capaz, el canal está apagado.
        // Decirle a esta persona "actualiza la app" sería falso y no arreglaría nada.
        #expect(GroupBackendCapability.resolve(
            compiledCapability: true, backendConfigured: true, remoteChannelEnabled: false) == .channelPaused)
    }

    @Test func resolve_incapableBuild_whenChannelNotCompiled() {
        // ESTE es C-10: el build no lleva el canal compilado y NINGÚN flag remoto puede encenderlo.
        #expect(GroupBackendCapability.resolve(
            compiledCapability: false, backendConfigured: true, remoteChannelEnabled: true) == .incapableBuild)
    }

    @Test func resolve_incapableBuild_whenBackendNotConfigured() {
        // Sin cliente de auth configurado, el sign-in lanza `notConfigured` antes de abrir la hoja de
        // Apple: ofrecer "volver a entrar" sería un callejón sin salida.
        #expect(GroupBackendCapability.resolve(
            compiledCapability: true, backendConfigured: false, remoteChannelEnabled: true) == .incapableBuild)
    }

    @Test func resolve_incapableBuild_whenNeitherCompiledNorConfigured() {
        // Estado de TODO build de producción hoy (canal DARK + backend placeholder).
        #expect(GroupBackendCapability.resolve(
            compiledCapability: false, backendConfigured: false, remoteChannelEnabled: false) == .incapableBuild)
    }
}

// MARK: - Matriz del estado presentable

struct GroupMigrationStateTests {

    private static let allCapabilities: [GroupBackendCapability] = [.canRejoin, .channelPaused, .incapableBuild]

    /// Sesión presente/ausente. NO es un input de la lógica a propósito (no tener sesión es el estado
    /// NORMAL de un miembro que aún no volvió a entrar), y estos tests lo PINEAN: si alguien la mete en
    /// el predicado, las aserciones "idéntico con y sin sesión" se ponen rojas.
    private static let sessionStates = [true, false]

    // MARK: Marcador ausente → nunca congelado, con cualquier capacidad

    @Test(arguments: allCapabilities, sessionStates)
    func migrationState_normal_whenMarkerNil(capability: GroupBackendCapability, hasSession: Bool) {
        _ = hasSession  // la sesión no participa: ese es justamente el aserto
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: nil, isBackendGroup: false, isOwner: false,
            hasCKSystemFields: true, capability: capability) == .normal)
    }

    @Test(arguments: allCapabilities)
    func migrationState_normal_whenBornBackend(capability: GroupBackendCapability) {
        // Grupo nacido en el backend: jamás vivió en CloudKit, jamás se congela.
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: nil, isBackendGroup: true, isOwner: false,
            hasCKSystemFields: false, capability: capability) == .normal)
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: .now, isBackendGroup: true, isOwner: false,
            hasCKSystemFields: false, capability: capability) == .normal)
    }

    // MARK: Marcador presente + miembro → el estado lo decide la capacidad

    @Test(arguments: sessionStates)
    func migrationState_rejoinable_whenMemberFrozenAndCanRejoin(hasSession: Bool) {
        _ = hasSession
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: false,
            hasCKSystemFields: true, capability: .canRejoin) == .frozenRejoinable)
    }

    @Test(arguments: sessionStates)
    func migrationState_needsUpdate_whenMemberFrozenAndBuildIncapable(hasSession: Bool) {
        // EL caso C-10. Antes esto era un congelado mudo; ahora se explica y lleva al App Store.
        // Con sesión o sin ella da IGUAL: el binario no puede firmar aunque quiera.
        _ = hasSession
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: false,
            hasCKSystemFields: true, capability: .incapableBuild) == .frozenNeedsUpdate)
    }

    @Test(arguments: sessionStates)
    func migrationState_paused_whenMemberFrozenAndChannelKilled(hasSession: Bool) {
        _ = hasSession
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: false,
            hasCKSystemFields: true, capability: .channelPaused) == .frozenPaused)
    }

    // MARK: Owner

    @Test(arguments: allCapabilities)
    func migrationState_ownerReinstallMitigation_normal(capability: GroupBackendCapability) {
        // Mitigación #9: owner con zona CloudKit conocida tras un reinstall → NO congelado, y la
        // capacidad no altera ese trato.
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: true,
            hasCKSystemFields: true, capability: capability) == .normal)
    }

    @Test func migrationState_ownerWithoutCKSystemFields_frozenByCapability() {
        // Borde teórico: owner sin zona conocida SÍ se congela — y tampoco puede quedarse mudo.
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: true,
            hasCKSystemFields: false, capability: .canRejoin) == .frozenRejoinable)
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: true,
            hasCKSystemFields: false, capability: .incapableBuild) == .frozenNeedsUpdate)
        #expect(GroupFreezeLogic.migrationState(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: true,
            hasCKSystemFields: false, capability: .channelPaused) == .frozenPaused)
    }

    // MARK: Invariantes

    @Test func isFrozen_unchanged_byCapability() {
        // INV-1, el test que protege el diseño entero: la capacidad NUNCA desbloquea ni bloquea
        // ESCRITURAS, solo cambia lo que se explica. Si alguien "arregla" C-10 haciendo que un build
        // incapaz deje de congelar, este test se pone rojo — y con razón: sus escrituras se perderían.
        let entradas: [(Date?, Bool, Bool, Bool)] = [
            (.now, false, false, true),   // miembro congelado
            (nil,  false, false, true),   // sin marcador
            (.now, true,  true,  true),   // owner adoptado
            (.now, false, true,  true),   // owner reinstall (mitigación #9)
            (.now, false, true,  false),  // owner sin zona conocida
            (.now, true,  false, false),  // born-backend
        ]
        for (marker, isBackend, isOwner, hasCKSF) in entradas {
            let frozen = GroupFreezeLogic.isFrozen(
                movedToBackendAt: marker, isBackendGroup: isBackend,
                isOwner: isOwner, hasCKSystemFields: hasCKSF)
            for capability in Self.allCapabilities {
                let state = GroupFreezeLogic.migrationState(
                    movedToBackendAt: marker, isBackendGroup: isBackend, isOwner: isOwner,
                    hasCKSystemFields: hasCKSF, capability: capability)
                #expect((state != .normal) == frozen)
            }
        }
    }

    @Test func everyFrozenState_hasAnExplanation_neverMute() {
        // El criterio del ticket, como aserto: NO existe combinación que produzca un congelado sin
        // estado que contar. Cada estado != .normal mapea a un modo de card con chip, y cada uno de esos
        // modos tiene su banner en el detalle.
        for capability in Self.allCapabilities {
            let state = GroupFreezeLogic.migrationState(
                movedToBackendAt: .now, isBackendGroup: false, isOwner: false,
                hasCKSystemFields: true, capability: capability)
            #expect(state != .normal)
            #expect(GroupCardDisplayLogic.displayMode(
                memberStatus: .active, migrationState: state) != .active)
        }
    }
}
