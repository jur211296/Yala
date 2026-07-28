//
//  GroupCapabilityBeacon.swift
//  Yala
//
//  C-10: publica en la fila `SplitMember` PROPIA de cada grupo un token que declara qué puede hacer este
//  device respecto al canal de Grupos del backend. El owner lo lee (`GroupMigrationReadinessLogic`) para
//  no estampar el marcador que CONGELA a quien no puede volver a entrar.
//
//  Por qué existe: `movedToBackendAt` viaja por CloudKit, pero la capacidad de re-entrar es COMPILADA
//  por build. Sin un canal member→owner, el owner no tiene forma de saber si su gente puede seguirle.
//

import Foundation
import SwiftData

/// Vocabulario del beacon. Es un TOKEN, no un número de versión: se compara por pertenencia a un set,
/// nunca con `<`. El historial de `CURRENT_PROJECT_VERSION` de este repo no es monótono, así que
/// cualquier umbral numérico heredaría ese rompe-umbral.
nonisolated enum GroupCapability {
    /// v1 = "este device puede volver a entrar AHORA MISMO (sign-in + join_group)".
    static let rejoinV1 = "rejoin.v1"

    /// Binario capaz, pero con el canal apagado para ESTE device (kill remoto / bucket del rollout aún
    /// sin encender). Se publica igual — mantiene el rendezvous tibio y le dice al owner "voy, pero
    /// todavía no" — pero NO acredita: el owner que migrara ahora lo congelaría durante semanas.
    static let rejoinV1Paused = "rejoin.v1.paused"

    /// Tokens que el owner acepta como prueba de que un member puede re-entrar. `rejoinV1Paused` NO está
    /// aquí a propósito. Un token DESCONOCIDO (de un build futuro con otra capacidad) tampoco: fail-closed
    /// también hacia adelante.
    static let acceptedForRejoin: Set<String> = [rejoinV1]

    /// Token a publicar, o `nil` si este binario no puede re-entrar de ninguna forma (⇒ no publica nada, y
    /// su ausencia es lo que impide que el owner lo congele).
    ///
    /// Publica SIEMPRE que el binario sea capaz, incluso con el canal apagado: si el beacon esperara al
    /// flag, el día del encendido el owner se encontraría con CERO beacons y el gate bloquearía el 100 %
    /// de las migraciones. Lo que cambia con el flag es el TOKEN, no el hecho de publicar — así el owner
    /// distingue "puede volver a entrar" de "podrá cuando le toque su bucket", y como `needsRefresh`
    /// refresca al cambiar el token, el miembro se re-publica solo en cuanto su canal se enciende y la
    /// migración se desbloquea sin que nadie intervenga.
    static var current: String? {
        switch GroupBackendCapability.current {
        case .canRejoin:      return rejoinV1
        case .channelPaused:  return rejoinV1Paused
        case .incapableBuild: return nil
        }
    }
}

@MainActor
enum GroupCapabilityBeacon {
    /// Cada cuánto se refresca el beacon. Escribir en cada boot amplificaría writes y generaría
    /// conflictos innecesarios en records de member; 7 días deja ~6 oportunidades antes del TTL de 45 d
    /// de `GroupMigrationReadinessLogic`.
    ///
    /// `nonisolated`: la lee `needsRefresh`, que es pura. Sin esto el acceso desde ese contexto es un
    /// warning hoy y un ERROR en el modo Swift 6.
    nonisolated static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60

    /// Publica/refresca el beacon donde haga falta. Devuelve cuántas filas se tocaron (0 = no-op).
    ///
    /// NO escribe en grupos migrados/congelados ni en grupos del canal backend: en una zona congelada el
    /// write se perdería, y en un grupo backend el canal CloudKit ya no es la verdad.
    @discardableResult
    static func publishIfNeeded(context: ModelContext, now: Date = .now) -> Int {
        guard let capability = GroupCapability.current else { return 0 }

        let members: [SplitMember]
        let groups: [SplitGroup]
        do {
            members = try context.fetch(
                FetchDescriptor<SplitMember>(predicate: #Predicate { $0.isCurrentUser == true })
            )
            groups = try context.fetch(FetchDescriptor<SplitGroup>())
        } catch {
            #if DEBUG
            print("GroupCapabilityBeacon: fetch falló: \(error)")
            #endif
            return 0
        }

        let groupByZoneID = Dictionary(groups.map { ($0.cloudKitZoneID, $0) },
                                       uniquingKeysWith: { first, _ in first })

        var touched = 0
        for member in members {
            guard let group = groupByZoneID[member.groupZoneID] else { continue }
            // Zona congelada o ya migrada → el write no llegaría a nadie.
            guard group.movedToBackendAt == nil, !group.isBackendGroup, !group.isMigratedFrozen else { continue }
            guard needsRefresh(lastAt: member.clientCapabilityAt,
                               currentToken: member.clientCapability,
                               token: capability,
                               now: now) else { continue }

            member.clientCapability = capability
            member.clientCapabilityAt = now
            SplitSyncManager.shared.enqueueSave(modelID: member.id, group: group)
            touched += 1
        }

        guard touched > 0 else { return 0 }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("GroupCapabilityBeacon: save falló: \(error)")
            #endif
            return 0
        }

        GroupsSyncBreadcrumb.groupsCapabilityBeaconPublished(count: touched)
        MetricsService.canary(.groupCapabilityBeaconPublished)
        return touched
    }

    /// Refresca si nunca se publicó, si el token cambió (build nuevo con otra capacidad) o si venció el
    /// intervalo. Un `lastAt` en el FUTURO (reloj torcido) también refresca: dejarlo pasar congelaría el
    /// beacon hasta que el reloj se corrigiera solo.
    ///
    /// `nonisolated`: es una decisión PURA sobre valores, sin relación con el main actor. Aislarla obliga
    /// a los tests puros a ser `@MainActor` sin ganar nada.
    nonisolated static func needsRefresh(
        lastAt: Date?, currentToken: String?, token: String, now: Date
    ) -> Bool {
        guard currentToken == token else { return true }
        guard let lastAt else { return true }
        if lastAt > now { return true }
        return now.timeIntervalSince(lastAt) >= refreshInterval
    }
}
