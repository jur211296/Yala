//
//  VueltaAPrimerPlano.swift
//  Yala
//
//  Qué hace una pantalla montada cuando Yala vuelve a primer plano (lote 1 de eficiencia, 26-nov-2026).
//
//  Medido en el iPhone 14 con 16.004 movimientos (`docs/qa/rendimiento-iphone14-2026-11-26/`): cada vuelta recargaba y
//  recalculaba el Panel, Estadísticas, Registros, Grupos, el detalle de grupo e Informes, aunque nada hubiera cambiado y
//  aunque la pantalla estuviera oculta detrás de otra pestaña. Eran 16-25 s con el hilo principal al 100 % y el scroll
//  congelado, y iOS llegó a matar la app en segundo plano.
//
//  Ahora la vuelta suelta el freno (como antes, por `ForegroundResume`) y, solo con la página a la vista, comprueba la
//  firma de esa pantalla: recarga si algo cambió mientras no estaba delante (un guardado, `dataVersion`, el día, trabajo
//  que el freno cortó). Una pantalla oculta no calcula al volver: lo que cambió sigue en su firma, y lo calcula al
//  aparecer, que es lo que ya hace su `onAppear` (el Panel, Estadísticas, Grupos, Informes) o lo que le apunta la vuelta
//  (`FrescuraAlVolver.pendienteAlAparecer`, Registros).
//
//  La comprobación espera una vuelta del main actor: la vuelta a primer plano de la app (`handleBecameActive`) aplica en
//  esa misma pasada los cambios remotos pendientes y materializa borradores, y la firma tiene que verlos.
//
//  Pin: `YalaTests/EficienciaVolverSinRecalcular/` (lógica y cableado: ningún `onChange(of: scenePhase)` recarga a pelo).
//

import Foundation

enum VueltaAPrimerPlano {

    /// Qué hace la pantalla al volver.
    enum Decision: Equatable {
        /// La página se ve: comprueba su firma ahora.
        case comprobarAhora
        /// La página está oculta: no calcula; lo hará al aparecer.
        case esperarAAparecer
    }

    nonisolated static func decidir(paginaVisible: Bool) -> Decision {
        paginaVisible ? .comprobarAhora : .esperarAAparecer
    }

    /// La vuelta a `.active` de una pantalla con freno. `soltarFreno` corre en cuanto la app está activa (también con la
    /// página oculta: sin freno, sus observadores siguen vivos); `comprobar` corre una vuelta del main actor después y
    /// solo con la página a la vista; `alQuedarOculta`, en el acto, si estaba oculta.
    @MainActor
    static func alVolver(
        _ site: String,
        paginaVisible: Bool,
        soltarFreno: @escaping @MainActor () -> Void,
        comprobar: @escaping @MainActor () -> Void,
        alQuedarOculta: @escaping @MainActor () -> Void = {}
    ) {
        ForegroundResume.whenApplicationActive(site) {
            soltarFreno()
            switch decidir(paginaVisible: paginaVisible) {
            case .comprobarAhora:
                Task { @MainActor in comprobar() }
            case .esperarAAparecer:
                #if DEBUG
                print("VueltaAPrimerPlano: \(site) oculta — no calcula al volver; lo hará al aparecer")
                #endif
                alQuedarOculta()
            }
        }
    }
}
