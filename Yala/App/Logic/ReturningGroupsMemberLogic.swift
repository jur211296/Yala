//
//  ReturningGroupsMemberLogic.swift
//  Yala
//
//  Quien vuelve a entrar por «Vengo por un grupo» con la MISMA cuenta no tiene que contestar otra vez lo que su cuenta
//  ya sabe (card «Al volver a entrar por "Vengo por un grupo" con la misma cuenta, Yala pide otra vez el consentimiento
//  de Grupos y tu nombre», QA guiado del 19-oct).
//
//  Dos mitades:
//  - **El consentimiento**: tras iniciar sesión se espera a leerlo de la cuenta (`GroupsConsentRegistrar.handleSignIn`)
//    ANTES de decidir la puerta. Hasta el 2026-10-22 esa lectura se lanzaba sin esperarla y la puerta decidía con la
//    caché local, que el cierre de sesión había borrado: salía otra vez «Grupos en la nube».
//  - **El nombre**: tras el consentimiento, el organizador sin alta veía el formulario del primer grupo con «Tu nombre
//    en el grupo», aunque su cuenta ya tuviera grupos. Si el primer tirón del canal trae una fila suya activa con
//    nombre, el alta se completa con ese nombre y aterriza en Grupos, sin crear otro grupo.
//

import Foundation

enum ReturningGroupsMemberLogic {

    /// Lo que hace falta de un `SplitMember` para decidir.
    struct Member: Equatable {
        let userID: String?
        let memberKey: String?
        let status: String
        let displayName: String
        let joinedAt: Date
    }

    /// El nombre con el que esta cuenta ya está en sus grupos: el de su fila activa más reciente con nombre. `nil` si
    /// la cuenta no tiene ninguna fila activa con nombre aquí (cuenta nueva, o el canal aún no bajó nada): entonces se
    /// pregunta como siempre.
    static func returningName(members: [Member], currentUserID: String?) -> String? {
        members
            .filter { $0.status == SplitMemberStatus.active.rawValue }
            .filter {
                GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
                    memberUserID: $0.userID, memberKey: $0.memberKey, currentUserID: currentUserID)
            }
            .sorted { $0.joinedAt > $1.joinedAt }
            .lazy
            .map { $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

/// La espera de la puerta de Grupos tras iniciar sesión, con techo: una red lenta no puede dejar a la persona mirando
/// una pantalla quieta. Pasado el techo se decide con lo que haya, que es el comportamiento de antes.
@MainActor
enum GroupsSignInSettle {

    nonisolated static let ceiling: Duration = .seconds(10)

    /// Solo esperan los destinos que siguen la cadena de Grupos (`routeIdentityDestination` → `continueFlow`). El
    /// bloqueo y la adopción de una cuenta completa presentan en el acto.
    static func waitsBeforeRouting(_ destino: CloudIdentityRoutingLogic.Destination?) -> Bool {
        switch destino {
        case .continueGroupsSetup, .associateGroupsAccount, .none:
            return true
        default:
            return false
        }
    }

    /// Espera a la lectura del consentimiento de la cuenta y, en la rama del organizador, a una pasada del canal de
    /// Grupos (la que trae sus grupos y su nombre).
    static func wait(consentRefresh: Task<Void, Never>?, pullsGroups: Bool, ceiling: Duration = ceiling) async {
        await bounded(ceiling) {
            await consentRefresh?.value
            if pullsGroups {
                await GroupsSyncClient.shared.syncNowFromUI(timeout: ceiling)
            }
        }
    }

    /// Corre `work` y vuelve cuando termina o cuando vence `ceiling`, lo primero. Con una continuación y no con un
    /// `TaskGroup`: el grupo esperaría al hijo colgado al cerrarse (regla de `gateway-attest.md`).
    private static func bounded(_ ceiling: Duration, _ work: @escaping @MainActor () async -> Void) async {
        let once = ResumeOnce()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            once.continuation = continuation
            Task { @MainActor in
                await work()
                once.resume()
            }
            Task { @MainActor in
                do {
                    try await Task.sleep(for: ceiling)
                } catch {
                    return
                }
                once.resume()
            }
        }
    }

    @MainActor
    private final class ResumeOnce {
        var continuation: CheckedContinuation<Void, Never>?
        func resume() {
            continuation?.resume()
            continuation = nil
        }
    }
}
