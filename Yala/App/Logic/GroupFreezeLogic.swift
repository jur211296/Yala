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

    /// C-10: el estado de migración TAL COMO SE LE PRESENTA al usuario de ESTE build. Cruza el freeze
    /// (que no cambia) con lo que este binario puede realmente hacer. Es lo que eligen la tarjeta y el
    /// banner; las ESCRITURAS las sigue gobernando `isMigratedFrozen`, nunca esto.
    @MainActor
    var migrationState: GroupMigrationState {
        GroupFreezeLogic.migrationState(
            movedToBackendAt: movedToBackendAt,
            isBackendGroup: isBackendGroup,
            isOwner: isOwner,
            hasCKSystemFields: ckSystemFieldsData != nil,
            capability: .current
        )
    }
}

/// C-10: qué puede hacer ESTE binario respecto al canal de Grupos del backend. Existe porque
/// `CloudSyncFlags.groupsBackendEnabled` mezcla dos cosas que al usuario le importan de forma distinta:
/// si su app es incapaz (hay que actualizarla) o si el canal está apagado ahora mismo (hay que esperar).
///
/// La SESIÓN no entra aquí a propósito: no tenerla es el estado NORMAL de un miembro que aún no volvió a
/// entrar, y el CTA lo lleva al sign-in, que es un camino VIVO. Meter la sesión aquí convertiría el
/// estado normal en un estado de error.
nonisolated enum GroupBackendCapability: Equatable, Sendable {
    /// Este binario puede COMPLETAR la re-entrada (sign-in + `join_group`).
    case canRejoin
    /// Binario capaz, pero el canal está apagado ahora mismo (kill remoto). Transitorio.
    case channelPaused
    /// Este binario NUNCA podrá re-entrar: canal no compilado o backend sin configurar. ESTE es C-10.
    case incapableBuild

    /// Derivación PURA. Existe separada de `current` porque `current` no puede ejercitar las tres ramas
    /// en un test: `groupsBackendCompiledCapability` es `false` mientras el canal no se encienda (paso 2
    /// de D-R1), y ese término corta primero ⇒ `current` siempre da `.incapableBuild`.
    ///
    /// (La versión previa de este comentario culpaba a `CloudBackendConfig.isConfigured`. Era falso ya
    /// entonces —bajo `Yala Dev` valía `true`— y hoy lo es en los dos schemes: el término que fija la
    /// rama es el COMPILADO, no la configuración del backend.)
    ///
    /// NO recibe la sesión a propósito — ver el doc del tipo.
    static func resolve(
        compiledCapability: Bool,
        backendConfigured: Bool,
        remoteChannelEnabled: Bool
    ) -> GroupBackendCapability {
        guard compiledCapability, backendConfigured else { return .incapableBuild }
        return remoteChannelEnabled ? .canRejoin : .channelPaused
    }

    /// Capacidad REAL de este build. PREDICE modos de fallo estructurales (canal no compilado, backend
    /// sin configurar, kill remoto); NO comprueba gateway vivo, sesión válida ni token de re-invite sin
    /// caducar — para eso haría falta una llamada de red en cada render. Los fallos que no predice caen
    /// en el camino de error del sign-in, que sí tiene mensaje y salida.
    static var current: GroupBackendCapability {
        resolve(
            compiledCapability: CloudSyncFlags.groupsBackendCompiledCapability,
            backendConfigured: CloudBackendConfig.isConfigured,
            remoteChannelEnabled: CloudRemoteFlags.groupsBackendEnabled
        )
    }
}

/// C-10: estado de migración presentable. `.normal` ⟺ el grupo NO está congelado; los otros tres son el
/// MISMO freeze contado de tres maneras según lo que este build puede ofrecer como salida.
nonisolated enum GroupMigrationState: Equatable, Sendable {
    case normal
    /// Congelado y este build puede volver a entrar → solo lectura explicada + CTA "Volver a entrar".
    case frozenRejoinable
    /// Congelado y este build NO puede volver a entrar → solo lectura explicada + CTA "Actualizar".
    case frozenNeedsUpdate
    /// Congelado y el canal está en pausa (kill remoto) → solo lectura explicada, SIN CTA que no pueda
    /// terminar. Ofrecer un botón aquí sería mentir dos veces.
    case frozenPaused
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

    /// C-10: el freeze CONTADO al usuario. `isFrozen` decide si el grupo se congela; esto decide qué se
    /// le explica y a dónde lleva la acción.
    ///
    /// El agujero que cierra: el marcador `movedToBackendAt` VIAJA por CloudKit, pero la capacidad de
    /// volver a entrar depende de lo que este binario tenga COMPILADO (`groupsBackendCompiledDefault` es
    /// una constante por build, y el flag remoto solo puede MATAR, nunca encender). En un rollout
    /// escalonado eso dejaba a un miembro con un build viejo mirando un grupo congelado, mudo y sin
    /// ninguna salida. Ahora ese caso es `.frozenNeedsUpdate`: se explica y lleva al App Store.
    ///
    /// INVARIANTE (sin cobertura desde la Fase 1 — ver la nota de `isFrozen`): `migrationState != .normal`
    /// ⟺ `isFrozen == true`, para las TRES capacidades. La capacidad JAMÁS desbloquea ni bloquea escrituras.
    static func migrationState(
        movedToBackendAt: Date?,
        isBackendGroup: Bool,
        isOwner: Bool,
        hasCKSystemFields: Bool,
        capability: GroupBackendCapability
    ) -> GroupMigrationState {
        guard isFrozen(
            movedToBackendAt: movedToBackendAt,
            isBackendGroup: isBackendGroup,
            isOwner: isOwner,
            hasCKSystemFields: hasCKSystemFields
        ) else { return .normal }

        switch capability {
        case .canRejoin:      return .frozenRejoinable
        case .channelPaused:  return .frozenPaused
        case .incapableBuild: return .frozenNeedsUpdate
        }
    }
}
