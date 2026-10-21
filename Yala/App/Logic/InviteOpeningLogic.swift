//
//  InviteOpeningLogic.swift
//  Yala
//
//  **Abrir un enlace de invitación en una instalación nueva** (card z81w del QA guiado del TF19, 2026-10-20).
//
//  Medido en el iPad del QA: la bienvenida normal salía 10-15 s, interactiva, antes de «Conecta tu cuenta», y dejaba irse
//  por otro camino («Empezar»). Los 10-15 s son la espera del import de iCloud que el reconciler del arranque hace antes
//  de encaminar la invitación (`AppBootstrapper.awaitPersonalStoreReady` → `forceFetchAndWait(timeout: 15)`), y en un
//  montaje sin espejo no hay ningún import que esperar. Decisión de Jürgen: desde el primer instante una pantalla
//  «Abriendo tu invitación…» sin botones hasta «Conecta tu cuenta», y no esperar a la importación para encaminar.
//

import Foundation

enum InviteOpeningLogic {

    /// El techo de «Abriendo tu invitación…». Pasado, vuelve la bienvenida normal: una pantalla sin botones no puede ser
    /// un camino muerto si la cadena del invitado no llega (un enlace que el canal no puede abrir, un arranque que se
    /// atasca por otra cosa). La invitación sigue guardada y releva a la bienvenida en cuanto llegue.
    static let ceiling: TimeInterval = 20

    /// ¿Se enseña «Abriendo tu invitación…» al llegar un enlace? Solo con la bienvenida delante, o sea sin el onboarding
    /// hecho. Con la app ya en uso, la invitación sigue su camino de siempre sobre la pestaña en la que esté.
    static func showsOpeningScreen(hasCompletedOnboarding: Bool) -> Bool {
        !hasCompletedOnboarding
    }

    /// ¿El reconciler del arranque encamina sin esperar al import de iCloud? Solo si este proceso NO montó espejo (no hay
    /// import que pueda pisar un guardado del contexto compartido, que es lo único que esa espera protege), el modo es
    /// `.icloud` (en la nube espera al motor, otra cosa) y hubo un enlace en este arranque (alguien está mirando
    /// «Abriendo tu invitación…»). Cualquier otro arranque espera como siempre.
    static func routesWithoutImportWait(mountAttachesMirror: Bool,
                                        storageMode: StorageMode,
                                        tappedBackendInviteThisLaunch: Bool) -> Bool {
        tappedBackendInviteThisLaunch && !mountAttachesMirror && storageMode == .icloud
    }
}
