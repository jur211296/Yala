//
//  FullModeActivationBlockExitLogic.swift
//  Yala
//
//  Qué salida ofrece cada bloqueo de «Activar Yala completo» (UX 2.2 · L6-9, opción B).
//
//  Cuando el remedio que dice el texto es un gesto, el botón es la instrucción. «Tu cuenta ya tiene finanzas
//  personales» dice «cierra sesión y vuelve a entrar con ella»: ése lleva un botón a Ajustes, donde vive «Cerrar
//  sesión». Los otros tres no lo necesitan: «otro dispositivo está moviendo tus datos» se arregla esperando, «tu
//  sesión caducó» se arregla volviendo a entrar en Grupos (cerrar esta pantalla es el paso), y «no disponible» no
//  tiene remedio desde el teléfono.
//

enum FullModeActivationBlockExitLogic {
    static func offersSignOut(for block: FullModeActivationFlowLogic.PromotionBlock) -> Bool {
        switch block {
        case .accountAlreadyHasPersonalData: true
        case .anotherDeviceIsMoving, .sessionExpired, .accountUnavailable: false
        }
    }
}
