//
//  GroupMigrationStateLogicTests.swift
//  YalaTests
//
//  Cobertura de `GroupFreezeLogic.migrationState` y `GroupBackendCapability.resolve`, las dos piezas que
//  `5010db6a` (Fase 1) dejó SIN tests al borrar `GroupMigrationStateTests` junto con el uploader.
//
//  Por qué se reabre. Aquel commit lo declaró como hueco deliberado con una condición explícita de
//  caducidad: «mueren en la Fase 4 junto con `movedToBackendAt`, que va ANTES de 2.1, así que no llegan a
//  publicarse sin tests. **Si la Fase 4 se retrasa y 2.1 se acerca, eso deja de ser cierto y hay que
//  reabrirlo.**» Medido el 2026-08-04: la Fase 4 NO ha aterrizado (`SplitGroup.movedToBackendAt` sigue
//  vivo) y las dos piezas ya salieron publicadas en los builds 4 a 10 de 2.0.5 ⇒ la condición se cumplió.
//
//  Pure-logic: sin SwiftData ni ModelContext (las convenience `SplitGroup.isMigratedFrozen` /
//  `.migrationState` son `@MainActor` y leen `.current`; aquí se ejercitan las estáticas PURAS, que es
//  justo lo que `resolve` existe para permitir — ver su docblock).
//

import Foundation
import Testing

@testable import Yala

@Suite("C-10 · estado de migración presentable y capacidad del binario")
struct GroupMigrationStateLogicTests {

    // MARK: - GroupBackendCapability.resolve

    @Test func resolve_canRejoin_onlyWhenCompiledAndConfiguredAndChannelUp() {
        #expect(GroupBackendCapability.resolve(
            compiledCapability: true, backendConfigured: true, remoteChannelEnabled: true) == .canRejoin)
    }

    @Test func resolve_channelPaused_whenBuildIsCapableButRemoteKillIsOn() {
        #expect(GroupBackendCapability.resolve(
            compiledCapability: true, backendConfigured: true, remoteChannelEnabled: false) == .channelPaused)
    }

    /// El `guard` corta ANTES del canal: un binario incapaz da `.incapableBuild` con el canal encendido o
    /// apagado. Es lo que separa «actualiza la app» (permanente) de «espera» (transitorio) — invertirlo le
    /// diría al usuario que actualice teniendo la app perfecta.
    @Test(arguments: [true, false])
    func resolve_incapableBuild_whenNotCompiled_regardlessOfChannel(remoteUp: Bool) {
        #expect(GroupBackendCapability.resolve(
            compiledCapability: false, backendConfigured: true, remoteChannelEnabled: remoteUp) == .incapableBuild)
    }

    @Test(arguments: [true, false])
    func resolve_incapableBuild_whenBackendNotConfigured_regardlessOfChannel(remoteUp: Bool) {
        #expect(GroupBackendCapability.resolve(
            compiledCapability: true, backendConfigured: false, remoteChannelEnabled: remoteUp) == .incapableBuild)
    }

    /// Barrido exhaustivo de las 8 combinaciones: la tabla completa, para que añadir un término nuevo al
    /// `guard` sin actualizar esto salga rojo.
    @Test func resolve_exhaustiveTruthTable() {
        for compiled in [true, false] {
            for configured in [true, false] {
                for remote in [true, false] {
                    let got = GroupBackendCapability.resolve(
                        compiledCapability: compiled,
                        backendConfigured: configured,
                        remoteChannelEnabled: remote)
                    let want: GroupBackendCapability =
                        (compiled && configured) ? (remote ? .canRejoin : .channelPaused) : .incapableBuild
                    #expect(got == want, "compiled=\(compiled) configured=\(configured) remote=\(remote)")
                }
            }
        }
    }

    // MARK: - GroupFreezeLogic.migrationState · el INVARIANTE

    /// **La aserción que carga el peso de este fichero.** `migrationState != .normal` ⟺ `isFrozen == true`,
    /// para las TRES capacidades: la capacidad decide QUÉ SE EXPLICA, jamás si el grupo está congelado.
    ///
    /// Es el invariante que `ed38c1ea` prometió por escrito («`isFrozen` queda byte-idéntico y sus 6 tests
    /// siguen verdes — lo único que cambia es lo que se explica y a dónde lleva la acción») y el que se
    /// quedó sin pin en la Fase 1. Barrido exhaustivo: 2⁴ estados × 3 capacidades = 48 casos.
    ///
    /// Su mutación: hacer que una capacidad devuelva `.normal` con el grupo congelado —o que abra una
    /// escritura— cae aquí y en ningún otro sitio.
    @Test func migrationState_isNeverNormalWhenFrozen_andAlwaysNormalWhenNot() {
        let capabilities: [GroupBackendCapability] = [.canRejoin, .channelPaused, .incapableBuild]
        let marker = Date(timeIntervalSince1970: 1_770_000_000)

        for movedAt in [marker, nil] {
            for isBackendGroup in [true, false] {
                for isOwner in [true, false] {
                    for hasCK in [true, false] {
                        let frozen = GroupFreezeLogic.isFrozen(
                            movedToBackendAt: movedAt,
                            isBackendGroup: isBackendGroup,
                            isOwner: isOwner,
                            hasCKSystemFields: hasCK)

                        for capability in capabilities {
                            let state = GroupFreezeLogic.migrationState(
                                movedToBackendAt: movedAt,
                                isBackendGroup: isBackendGroup,
                                isOwner: isOwner,
                                hasCKSystemFields: hasCK,
                                capability: capability)

                            let label = "movedAt=\(movedAt != nil) backend=\(isBackendGroup) "
                                + "owner=\(isOwner) ck=\(hasCK) cap=\(capability)"
                            #expect((state != .normal) == frozen, Comment(rawValue: label))
                        }
                    }
                }
            }
        }
    }

    // MARK: - GroupFreezeLogic.migrationState · el mapeo capacidad → salida

    /// Un grupo CONGELADO cuenta el mismo freeze de tres maneras según la salida que este build puede
    /// ofrecer de verdad. Fixture: member no re-joineado (`movedToBackendAt` puesto, `isBackendGroup`
    /// falso, no owner) — el caso que el rollout escalonado dejaba mudo.
    @Test(arguments: [
        (GroupBackendCapability.canRejoin, GroupMigrationState.frozenRejoinable),
        (GroupBackendCapability.channelPaused, GroupMigrationState.frozenPaused),
        (GroupBackendCapability.incapableBuild, GroupMigrationState.frozenNeedsUpdate),
    ])
    func migrationState_frozenMember_mapsEachCapabilityToItsOwnExit(
        capability: GroupBackendCapability, expected: GroupMigrationState
    ) {
        let state = GroupFreezeLogic.migrationState(
            movedToBackendAt: Date(timeIntervalSince1970: 1_770_000_000),
            isBackendGroup: false,
            isOwner: false,
            hasCKSystemFields: false,
            capability: capability)
        #expect(state == expected)
    }

    /// Las tres salidas son DISTINTAS entre sí. Sin esto, colapsar dos ramas del `switch` (p. ej. devolver
    /// `.frozenNeedsUpdate` también en pausa, que es el bug que C-10 arregló: mandar al App Store a quien
    /// solo tiene que esperar) dejaría el test de arriba en verde para dos de los tres argumentos.
    @Test func migrationState_theThreeFrozenExitsAreDistinct() {
        let marker = Date(timeIntervalSince1970: 1_770_000_000)
        let states = [GroupBackendCapability.canRejoin, .channelPaused, .incapableBuild].map {
            GroupFreezeLogic.migrationState(
                movedToBackendAt: marker,
                isBackendGroup: false,
                isOwner: false,
                hasCKSystemFields: false,
                capability: $0)
        }
        #expect(Set(states.map(String.init(describing:))).count == 3)
        #expect(!states.contains(.normal))
    }

    /// La mitigación #9 (owner tras reinstall) manda sobre la capacidad: NO está congelado, así que
    /// `.normal` con las tres. Es el caso en el que un `switch` puesto ANTES del `guard isFrozen` le
    /// pintaría al owner un CTA de re-join sin sentido sobre su propio grupo.
    @Test(arguments: [GroupBackendCapability.canRejoin, .channelPaused, .incapableBuild])
    func migrationState_ownerReinstallMitigation_staysNormalForEveryCapability(
        capability: GroupBackendCapability
    ) {
        let state = GroupFreezeLogic.migrationState(
            movedToBackendAt: Date(timeIntervalSince1970: 1_770_000_000),
            isBackendGroup: false,
            isOwner: true,
            hasCKSystemFields: true,
            capability: capability)
        #expect(state == .normal)
    }

    /// Un grupo born-backend (`isBackendGroup`) nunca se congela, tampoco por capacidad.
    @Test(arguments: [GroupBackendCapability.canRejoin, .channelPaused, .incapableBuild])
    func migrationState_bornBackend_staysNormalForEveryCapability(capability: GroupBackendCapability) {
        let state = GroupFreezeLogic.migrationState(
            movedToBackendAt: Date(timeIntervalSince1970: 1_770_000_000),
            isBackendGroup: true,
            isOwner: false,
            hasCKSystemFields: false,
            capability: capability)
        #expect(state == .normal)
    }
}
