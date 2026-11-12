//
//  GroupsJoinD14Logic.swift
//  Yala
//
//  Decisiones puras del lote decidido 2.2 · 14 (Grupos: invitar, unirse, aprobar solicitudes y avisos). Cada una vive en
//  su enum para que la vista solo pinte; las tablas completas están en `GroupsJoinD14LogicTests`.
//

import Foundation
import UserNotifications

// MARK: - L12-8 · Los avisos del grupo dentro de «está listo» y «Ya estás en»

enum GroupNotificationsOptInLogic {

    enum State: Equatable {
        /// Falta algo: el aviso de grupos está apagado en Yala o iOS aún no preguntó.
        case ask
        /// Los avisos de grupo llegan: aviso encendido en Yala y permiso del sistema.
        case enabled
        /// iOS ya dijo que no: solo se arregla en Ajustes.
        case denied
    }

    static func state(itemActive: Bool, authorization: UNAuthorizationStatus) -> State {
        switch authorization {
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return itemActive ? .enabled : .ask
        case .notDetermined:
            return .ask
        @unknown default:
            return .ask
        }
    }

    /// La tarjeta se enseña solo si al abrir la pantalla faltaba algo: a quien ya los tiene no se le pregunta nada.
    static func showsCard(initialState: State) -> Bool { initialState != .enabled }

    /// Card fptw (opción B de Jürgen, 2026-10-23): en la lista de Grupos la tarjeta sale UNA vez, a quien tiene grupos y
    /// nunca la vio en ninguna pantalla (`AppPreferences.hasSeenGroupsNotificationPrompt`, el mismo flag que llevaba la
    /// alerta suelta retirada en L12-8). En «está listo», «Ya estás en», «Solicitud enviada» y el formulario de gasto de
    /// L13-8 sale siempre que falte algo: son el momento de la pregunta.
    static func showsCard(initialState: State, onlyIfNeverSeen: Bool, hasSeenPrompt: Bool) -> Bool {
        guard showsCard(initialState: initialState) else { return false }
        return !(onlyIfNeverSeen && hasSeenPrompt)
    }

    /// ¿Monta la lista de Grupos su tarjeta de una vez? No mientras otra pantalla está a punto de hacer la pregunta: el
    /// formulario de la bienvenida (L12-12) o la hoja «está listo» que sigue al alta (`groupAwaitingInviteSheet` se apunta
    /// ANTES de que el grupo llegue a la lista). Sin esto, el alta de un primer grupo enseñaba la tarjeta dos veces.
    static func listMountsCard(isWelcomeGroupFormOpen: Bool, inviteSheetPending: Bool) -> Bool {
        !isWelcomeGroupFormOpen && !inviteSheetPending
    }
}

// MARK: - L12-20 · El aviso al ser aprobado sustituye al genérico del servidor

enum GroupApprovalNoticeLogic {

    /// La clave del texto genérico con que el servidor avisa a quien aprobaron (`gateway/src/groups/rpc.ts`,
    /// `notifyMembershipChange`): «Novedades sobre tu membresía en un grupo».
    static let serverMembershipLocKey = "notifications.groups.remoteMembershipUpdate"

    /// ¿Este aviso entregado es el genérico de membresía del servidor? El gateway promete que la app lo sustituye por el
    /// rico; sin retirarlo, la persona veía dos avisos de la misma aprobación (review adversarial del 2026-10-21).
    static func isServerMembershipNotice(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let locKey = alert["loc-key"] as? String else { return false }
        return locKey == serverMembershipLocKey
    }
}

// MARK: - L12-14 · El mensaje que viaja con el enlace

enum GroupInviteShareMessage {

    /// «Lucía te invita a «Depa» en Yala… vuelve a tocarlo.» + el enlace en la línea siguiente. Sin un nombre propio en el
    /// perfil (vacío o el «Usuario» por defecto) no se escribe un nombre que no es de nadie.
    static func text(inviterName: String?, defaultName: String, groupName: String, url: URL) -> String {
        let name = (inviterName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let line = (name.isEmpty || name == defaultName)
            ? L10n.UXD14.shareMessageNoInviter(group: groupName)
            : L10n.UXD14.shareMessage(inviter: name, group: groupName)
        return line + "\n" + url.absoluteString
    }
}

// MARK: - L12-16 · El enlace de Yala dentro de cualquier texto

enum InviteLinkTextExtraction {

    private static let leadingNoise = CharacterSet(charactersIn: "(<[{«“\"'‘")
    private static let trailingNoise = CharacterSet(charactersIn: ".,;:!?)>]}»”\"'’")

    /// El primer enlace de invitación de Yala que aparezca en `text`: el mensaje entero de WhatsApp vale. `nil` si no hay.
    static func firstInviteLink(in text: String) -> URL? {
        let tokens = text.components(separatedBy: .whitespacesAndNewlines)
        for raw in tokens where !raw.isEmpty {
            var token = Substring(raw)
            while let first = token.unicodeScalars.first, leadingNoise.contains(first) { token = token.dropFirst() }
            while let last = token.unicodeScalars.last, trailingNoise.contains(last) { token = token.dropLast() }
            guard !token.isEmpty, let url = URL(string: String(token)) else { continue }
            if InviteLinkService.isInviteLink(url) { return url }
        }
        return nil
    }
}

// MARK: - L12-17 · La tarjeta del grupo antes de la cuenta

enum GroupInviteGroupFirstLogic {

    /// ¿La invitación enseña primero la tarjeta del grupo, antes de pedir cuenta o consentimiento?
    ///
    /// Solo mientras falte una de las dos y la persona no haya dicho ya «Unirme» en la tarjeta: después de ese toque la
    /// cadena sigue a cuenta y consentimiento sin volver a enseñarla. `canPresentOnboarding` es el mismo discriminador de
    /// `GroupBackendInviteEntryLogic.nextStep`: el paso que viene del propio CTA no re-presenta la hoja.
    static func showsGroupBeforeAccount(
        hasSession: Bool,
        isConsented: Bool,
        hasConfirmedInvite: Bool,
        hasAcceptedGroupCard: Bool,
        canPresentOnboarding: Bool
    ) -> Bool {
        guard canPresentOnboarding, !hasConfirmedInvite, !hasAcceptedGroupCard else { return false }
        return !hasSession || !isConsented
    }

    enum JoinTapRoute: Equatable {
        /// Con cuenta y consentimiento: el toque une ya (el camino de siempre).
        case joinNow
        /// Falta cuenta o consentimiento: se apunta el «sí» y se sigue a esos pasos; la unión arranca sola al volver.
        case continueToAccount
    }

    /// Qué hace «Unirme». Sin invitación detrás (vista previa, seam de XCUITest) no hay nada que apuntar: une como siempre.
    static func joinTapRoute(hasPendingZone: Bool, hasSession: Bool, isConsented: Bool) -> JoinTapRoute {
        (hasPendingZone && (!hasSession || !isConsented)) ? .continueToAccount : .joinNow
    }

    /// ¿La hoja que se va a presentar ya no tiene nada que enseñar porque la tarjeta se aceptó y la cadena va por la cuenta
    /// o el consentimiento? Entonces se sigue la cadena en vez de presentarla otra vez. Pasa cuando una vuelta a primer
    /// plano con la tarjeta delante deja en cola otra petición de la misma hoja, que drena justo después del «Unirme»
    /// (review adversarial del 2026-10-21).
    static func skipsSheetToContinueChain(hasAcceptedGroupCard: Bool, hasSession: Bool, isConsented: Bool) -> Bool {
        hasAcceptedGroupCard && (!hasSession || !isConsented)
    }

    /// Cuánto vale el «Unirme» de la tarjeta para unir sin volver a preguntar. Cubre iniciar sesión y aceptar el
    /// consentimiento (también con un relanzamiento por medio); pasado ese rato ya no es «al volver», y la persona tiene
    /// que volver a ver el grupo y poder decir «Más tarde» (review adversarial del 2026-10-21: con la marca viva 7 días,
    /// aceptar el consentimiento días después por otro camino metía a la persona en el grupo sin un solo toque).
    static let autoJoinWindow: TimeInterval = 30 * 60

    /// Al volver de cuenta y consentimiento, la unión arranca sola: la persona ya dijo «Unirme» en la tarjeta, hace poco.
    static func joinsOnAppear(
        groupCardAcceptedAt: Date?, hasSession: Bool, isConsented: Bool, now: Date = .now
    ) -> Bool {
        guard let acceptedAt = groupCardAcceptedAt, hasSession, isConsented else { return false }
        let elapsed = now.timeIntervalSince(acceptedAt)
        return elapsed >= 0 && elapsed < autoJoinWindow
    }
}

// MARK: - L12-19 · La pestaña mientras hay una unión en curso

enum GroupsJoinOnTheWayLogic {

    /// «Tu grupo está en camino» en vez del estado vacío que ofrece crear uno. Solo con la unión todavía viva: conectando,
    /// esperando aprobación o con un error que se puede reintentar. Caducada o rota sin remedio, vuelve el de siempre.
    static func showsOnTheWay(phase: JoinIntentPhase) -> Bool {
        switch phase {
        case .accepting, .waitingForZone, .creatingMember, .pendingApproval:
            return true
        case .failed(let reason):
            switch reason {
            case .acceptFailed(recoverable: true), .memberSaveFailed: return true
            case .acceptFailed(recoverable: false), .expired: return false
            }
        case .idle, .active:
            return false
        }
    }
}

// MARK: - L19-1 · Solicitudes para unirse

enum GroupJoinRequestsLogic {

    /// El aviso dentro del grupo: «Carla quiere unirse» o, con varias, «Varias personas quieren unirse». `nil` si no hay
    /// solicitudes o quien mira no puede aceptarlas.
    static func bannerTitle(pendingNames: [String], canReview: Bool) -> String? {
        guard canReview, let first = pendingNames.first else { return nil }
        return pendingNames.count == 1 ? L10n.UXD14.requestsBannerOne(first) : L10n.UXD14.requestsBannerMany
    }
}
