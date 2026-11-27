//
//  CompartidoPersonaAlta.swift
//  Yala
//
//  Compartido (lote 3, 26-nov-2026): dar de alta a una persona sin crear un grupo. Por dentro una persona es un grupo de
//  dos (`SplitGroup.isPerson`) que nace en el servidor con su sitio reservado (`create_person_group`, g38_01): el miembro
//  sin cuenta con el nombre que se le puso, hasta que abra el enlace y lo ocupe. Lo usan «Añadir persona» y
//  «¿Con quién?» → «Escribir un nombre», en Nuevo gasto, Voz, Foto e Yala IA (las mismas pantallas de Grupos).
//
//  La cuenta se pide AQUÍ, al crear la persona, y nunca al entrar a Compartido: el alta es server-first (como la de un
//  grupo, sin grupos fantasma) y Voz, Foto e Yala IA reparten por los miembros del grupo elegido, así que la persona tiene
//  que existir antes de apuntarle nada. Si la persona usuaria dice que no a la cuenta, no se guarda nada a medias: lo
//  escrito se queda donde estaba, como al tocar «Nuevo grupo» sin cuenta.
//

import Foundation
import SwiftData

/// Qué hacer al confirmar el nombre de una persona nueva. Pura: la vista pone la sesión, el consentimiento y el canal.
nonisolated enum CompartidoPersonaAltaLogic {

    /// El tope del nombre en el servidor (`create_person_group`: 80 caracteres, igual que el nombre de un miembro).
    static let maxNameLength = 80

    /// El nombre listo para el servidor: sin espacios a los lados y con el tope. `nil` si queda vacío.
    static func cleanName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    /// La misma puerta que «Nuevo grupo» (`GroupCreateRoutingLogic`): lo anunciado y lo pedido no pueden divergir.
    static func route(flagOn: Bool, hasSession: Bool, consentAccepted: Bool) -> GroupCreateRoutingLogic.Route {
        GroupCreateRoutingLogic.route(flagOn: flagOn, hasSession: hasSession, consentAccepted: consentAccepted)
    }

    /// El color de la persona: estable por nombre (la misma «Marta» sale siempre igual), de la paleta de iconos de grupo.
    static let palette = ["#14B8A6", "#8B5CF6", "#EC4899", "#F59E0B", "#3B82F6", "#10B981", "#EF4444", "#6366F1"]

    static func colorHex(for name: String) -> String {
        let sum = name.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return palette[sum % palette.count]
    }

    /// Una persona con el mismo nombre que ya existe, para no crear otra «Marta» si ya la tienes (sin distinguir
    /// mayúsculas ni tildes). Solo personas: un grupo que se llame igual no es esa persona.
    static func existingPerson(named name: String, among groups: [(id: UUID, name: String, isPerson: Bool)]) -> UUID? {
        let wanted = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return groups.first {
            $0.isPerson && $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines) == wanted
        }?.id
    }
}

/// El alta en sí: el RPC y lo que la app hace después, como al crear un grupo desde el asistente.
@MainActor
enum CompartidoPersonaAlta {

    /// Crea la persona en el servidor y la deja en el teléfono. Lanza el error del canal tal cual: quien llama lo enseña
    /// con `GroupActionErrorLogic.message(for:)`, el mismo texto que al crear un grupo.
    static func crear(nombre: String, moneda: String, contexto: ModelContext) async throws -> SplitGroup {
        let perfil = UserDefaults.standard.string(forKey: AppPreferences.Keys.userName) ?? ""
        let creada = try await GroupBackendMembershipService(
            client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
            .createPersonGroup(
                personName: nombre,
                currencyCode: moneda,
                displayName: perfil.isEmpty ? L10n.Profile.defaultName : perfil,
                colorHex: CompartidoPersonaAltaLogic.colorHex(for: nombre),
                context: contexto
            )
        SessionState.shared.incrementDataVersion()
        NudgeService.shared.recordGroupJoinIfNeeded()
        return creada.group
    }
}

/// La entrada a Compartido sin grupo obligatorio: qué estados vacíos enseñan ya la vista completa (chips, fila de captura
/// y un vacío por chip) y cuáles siguen con su tarjeta.
nonisolated enum CompartidoEntradaLogic {

    /// Con la vista completa salvo dos casos: «vuelve a entrar» (sus grupos ya existen en una cuenta, no hay nada que
    /// empezar) y una unión en curso (su grupo está en camino). Sin canal de Grupos tampoco: no se puede crear nada.
    static func showsFullView(kind: GroupsEmptyStateLogic.Kind, flagOn: Bool, joinOnTheWay: Bool) -> Bool {
        guard flagOn, !joinOnTheWay else { return false }
        switch kind {
        case .signInToView: return false
        case .standard, .needsEducational, .createAccount, .needsConsent: return true
        }
    }

    /// «Nuevo gasto», Voz, Foto o Yala IA sin nadie con quien apuntar: «¿Con quién?» primero, con «Escribir un nombre».
    /// Con uno, directo a él; con varios, el formulario (o la captura) con el selector, como en Grupos.
    enum Start: Equatable {
        case askWho
        case direct
        case pick
    }

    /// El id del botón del vacío del chip Grupos: el de la tarjeta de pasos de cada estado, porque lleva al mismo sitio.
    static func groupsCardIdentifier(kind: GroupsEmptyStateLogic.Kind) -> String {
        switch kind {
        case .standard: return "groups_empty_state"
        case .needsEducational: return "groups_empty_state_educational"
        case .createAccount: return "groups_empty_state_create_account"
        case .needsConsent: return "groups_empty_state_consent"
        case .signInToView: return "groups_empty_state_signin"
        }
    }

    static func start(eligibleCount: Int) -> Start {
        switch eligibleCount {
        case 0: return .askWho
        case 1: return .direct
        default: return .pick
        }
    }
}
