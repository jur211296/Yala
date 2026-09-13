//
//  GroupsAssociationLogic.swift
//  Yala
//
//  Paso 10 del rediseño de sesiones · **la asociación entre una sesión privada y UNA cuenta en la nube
//  para grupos**, como estado propio y no como inferencia.
//
//  ## Qué contesta, y por qué no bastaba lo de antes
//
//  Hasta hoy «tengo cuenta de grupos» se deducía de `CloudAuthService.shared.hasSession` — una sesión JWT
//  viva en el llavero. Eso responde «¿hay sesión AHORA?», que no es la misma pregunta que «¿esta persona
//  ligó una cuenta a su Yala privado?». Las tres diferencias que cuestan:
//
//   1. **El segundo móvil del mismo Apple ID.** Restaura su Yala privado y no tiene sesión: con la
//      inferencia leería «no tienes grupos» y le ofrecería CREAR una cuenta que ya existe.
//   2. **La puerta «Migrar a la nube».** `CloudIdentityRoutingLogic` necesita saber si la cuenta con la que
//      alguien firma es *su* asociada para promoverla, y `hasSession` no distingue una cuenta de otra.
//   3. **Re-asociar.** Decidir si los movimientos que el usuario conservó al desasociar frenan el puente
//      —para que el gasto no aparezca dos veces— exige comparar el `sub` de la cuenta que entra con el de
//      la que se fue, y una sesión viva no recuerda a la anterior. Quien lo compara es
//      `GroupsDetachedBridgeLedger`, con el `sub` que sirve este registro.
//
//  ## Lo que NO decide este fichero
//
//  Dónde se persiste (eso es `GroupsAccountAssociation`), ni qué pasa con las filas puenteadas al
//  desasociar (eso es `GroupsAssociationDetach`). Aquí solo hay tablas puras, para que se puedan fijar
//  aparte del cableado.
//

import Foundation

nonisolated enum GroupsAssociationLogic {

    // MARK: - Qué pinta la fila «¿Dónde viven tus datos?»

    /// Los estados de la sección «Grupos» de esa fila. Son los tres del ADR §4 más uno que el ADR no
    /// nombra pero la matriz sí (fila «D · N (segundo móvil)»): **asociada sin sesión viva**.
    enum SectionState: Equatable {
        /// Sesión privada sin cuenta de grupos. CTA: asociar (→ [I] → [G]).
        case noAccount
        /// Sesión privada + cuenta asociada + sesión viva. Muestra la cuenta y ofrece desasociar.
        case associated
        /// Asociación registrada y **sin sesión viva**: segundo móvil del mismo Apple ID, o este mismo
        /// tras «Restaurar desde iCloud». Ofrece entrar con ESA cuenta, y desasociar.
        ///
        /// La asociación viaja por el iCloud-KV del Apple ID; la SESIÓN no viaja (es un JWT del llavero
        /// de este dispositivo). Por eso este estado existe y no es un error de escritura.
        case associatedNeedsSignIn
        /// La sesión personal ya es en la nube: grupos es esa misma cuenta y no se cambia (ADR §4).
        /// Informa y no ofrece desasociar.
        case sameAccountAsPersonal
        /// La sección no aplica: sin sesión privada que asociar (celda F del ADR, solo-grupos), o
        /// dispositivo fresco sin nada montado. La fila sigue hablando del almacenamiento personal.
        case notApplicable
    }

    /// - Parameters:
    ///   - deviceState: el MISMO eje que usa `CloudIdentityRoutingLogic`, derivado con su
    ///     `deviceState(hasCompletedOnboarding:storageMode:hasPrivateSession:)`. No se re-deriva aquí a
    ///     propósito: dos derivaciones del mismo eje divergen, y la tabla de [I] es la autoridad.
    ///   - hasPersistedAssociation: hay un registro de asociación (local o llegado por iCloud-KV).
    ///   - hasLiveGroupsSession: `CloudAuthService.shared.hasSession`.
    static func sectionState(
        deviceState: CloudIdentityRoutingLogic.DeviceSessionState,
        hasPersistedAssociation: Bool,
        hasLiveGroupsSession: Bool
    ) -> SectionState {
        switch deviceState {
        case .cloudComplete:
            return .sameAccountAsPersonal
        case .privateSession:
            if hasLiveGroupsSession { return .associated }
            return hasPersistedAssociation ? .associatedNeedsSignIn : .noAccount
        case .fresh, .cloudGroupsOnly:
            return .notApplicable
        }
    }

    /// ¿Ofrece la sección el gesto de desasociar?
    ///
    /// **Tiene que ser cierto también sin sesión viva**: quien llega al segundo móvil y decide que esa
    /// cuenta ya no le sirve no debería tener que entrar en ella primero para poder soltarla.
    static func offersDetach(_ state: SectionState) -> Bool {
        state == .associated || state == .associatedNeedsSignIn
    }

    /// ¿Ofrece asociar una cuenta nueva?
    ///
    /// **Solo desde `.noAccount`.** Decisión de Jürgen (2026-09-09): «para cambiar de cuenta hay que
    /// desasociar primero; no existe un "Cambiar cuenta" que haga las dos cosas de un gesto».
    static func offersAssociate(_ state: SectionState) -> Bool {
        state == .noAccount
    }

    // MARK: - Cómo se nombra la cuenta en la fila

    /// Cómo se nombra la cuenta bajo «Grupos». **El `sub` no es una de las opciones**: es un
    /// identificador opaco que no le dice nada a nadie y ensucia una pantalla que existe para ser
    /// inequívoca.
    enum DisplayName: Equatable {
        /// El correo tal cual. Jürgen pidió identidad COMPLETA y no un hash (2026-09-09).
        case email(String)
        /// Sin correo: el proveedor a secas, sin inventar nada. Con Apple el correo solo se entrega en el
        /// PRIMER sign-in de ese Apple ID (`CloudAuthService.capturedEmail()` lee lo capturado entonces),
        /// así que un dispositivo que adopte una sesión ya creada puede no tenerlo.
        case provider(YalaAccountLogic.Method)
        /// Ni correo ni proveedor reconocible. La fila dice que hay una cuenta asociada sin nombrarla.
        case unnamed
    }

    /// La traducción a texto vive en la vista a propósito: esta tabla se fija sin cargar un bundle.
    static func displayName(email: String?, provider: String?) -> DisplayName {
        if let email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .email(email)
        }
        let method = YalaAccountLogic.method(fromProvider: provider)
        return method == .unknown ? .unnamed : .provider(method)
    }
}
