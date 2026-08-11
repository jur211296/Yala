//
//  SecondarySlotOccupancyLogic.swift
//  Yala
//
//  M1 · **quién ocupa el slot de la sesión secundaria, comprobado en la ENTRADA.**
//
//  El descriptor de `SecondarySessionStore` es de UN solo slot y guarda el `sub` de la cuenta que lo
//  ocupa. Ese `userID` existía desde el Inc 6 y su docblock prometía que «valida que quien re-entra al
//  slot es la misma cuenta» — pero **no tenía un solo consumidor de producción**: el mount pregunta
//  `isActive()` y nunca *quién*, y la entrada llamaba a `activate(userID:)` directamente. Con el slot
//  ocupado por la invitada A y sus archivos `-Secondary` VIVOS en disco, una entrada de B lo habría
//  reescrito a su nombre y B habría montado el store —y el corpus— de A. Esta lógica es el consumidor
//  que faltaba: la promesa del docblock pasa a ser código.
//
//  **Qué NO cubre, dicho aquí para que nadie lo busque donde no está.** La ventana del hallazgo M1-1
//  —descriptor escrito, kill antes del relanzamiento, otro humano abre la app y aterriza en la sesión
//  de A— **no se cierra desde aquí**: ahí no hay ninguna entrada que interrogar. Cerrarla exigiría
//  preguntar en el MOUNT, y eso está prohibido por diseño (el mount y el wipe honran el descriptor
//  INCONDICIONALMENTE, para que una sesión ya activa jamás quede brickeada si el flag se apagara).
//
//  Pura y sin estado: el call-site (`WelcomeCloudSignInView.confirmSecondaryEntry`) le pasa el
//  ocupante leído del store y el `sub` de quien acaba de firmar.
//

import Foundation

nonisolated enum SecondarySlotOccupancyLogic {

    enum Decision: Equatable {
        /// Slot libre → armar la entrada (el caso normal: el dueño acaba de cerrar su sesión).
        case free
        /// El ocupante ES quien entra. Se deja pasar a propósito: es la re-entrada idempotente de un
        /// kill entre el descriptor y el relanzamiento, y bloquearla dejaría a la invitada sin forma
        /// de volver a su propia sesión.
        case sameAccount
        /// Otro `sub` ocupa el slot y sus archivos `-Secondary` siguen en disco. Entrar aquí sería
        /// montarle a esta cuenta el corpus de la anterior — la mezcla cross-cuenta que el guard del
        /// Welcome existe para impedir, con la diferencia de que aquí los datos ajenos no son los del
        /// dueño sino los de otra invitada.
        case occupiedByOther
    }

    /// - Parameters:
    ///   - occupantUserID: `SecondarySessionStore.activeUserID()` — `nil` (o vacío) = slot libre.
    ///   - enteringUserID: el `sub` de la sesión nube recién firmada.
    static func decide(occupantUserID: String?, enteringUserID: String) -> Decision {
        guard let occupantUserID, !occupantUserID.isEmpty else { return .free }
        return occupantUserID == enteringUserID ? .sameAccount : .occupiedByOther
    }
}
