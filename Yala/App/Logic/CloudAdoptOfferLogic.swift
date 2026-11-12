//
//  CloudAdoptOfferLogic.swift
//  Yala
//
//  **El segundo dispositivo propone activar la nube solo** (card vbf9, QA guiado del TestFlight 19, 2026-10-20, E2). El
//  modo es por dispositivo a propósito —nadie mueve los datos de un aparato sin pedirlo en él—, pero hasta aquí el segundo
//  paso no se anunciaba: el iPad seguía en iCloud hasta que la persona encontraba «Activar la nube en este dispositivo» en
//  Perfil › «Dónde viven tus datos». Jürgen: «¿Por qué necesita activar la nube doble en dos dispositivos?».
//
//  Ahora el Panel lo propone con un aviso de la cola de siempre (`PanelNoticeCarousel`). Tocar «Activar» abre «Dónde viven
//  tus datos» y arranca la activación del adopt, la MISMA que su botón: la persona confirma y entra con su cuenta, que es
//  lo que la sesión por dispositivo exige.
//

import Foundation

enum CloudAdoptOfferLogic {

    /// ¿El Panel propone activar la nube aquí? Las condiciones con que la pantalla de almacenamiento enseña la tarjeta de
    /// adopt, y ninguna más:
    /// - `markerFromAnotherDevice`: el marcador de migración de otro dispositivo llegó por el iCloud de este
    ///   (`CloudMigrationController.markerDecision() == .secondaryDeviceCloudLogin`);
    /// - `migrationIdle`: aquí no hay nada en vuelo (`uiState == .idle`);
    /// - `persistedMode == .icloud`: este dispositivo sigue en su iCloud privado;
    /// - `offersCloudEntry`: la pantalla ofrece la entrada a la nube (`StorageRowGateLogic.offersCloudMigrationEntry`:
    ///   el kill remoto y App Attest);
    /// - `hasPrivateSession`: hay datos personales que viven en iCloud (una sesión solo de grupos no tiene qué activar);
    /// - `dismissedThisSession`: la persona cerró el aviso en este arranque. Vuelve en el siguiente, y la tarjeta de
    ///   «Dónde viven tus datos» sigue ahí.
    static func shows(markerFromAnotherDevice: Bool, migrationIdle: Bool, persistedMode: StorageMode,
                      offersCloudEntry: Bool, hasPrivateSession: Bool, dismissedThisSession: Bool) -> Bool {
        markerFromAnotherDevice && migrationIdle && persistedMode == .icloud && offersCloudEntry
            && hasPrivateSession && !dismissedThisSession
    }
}

/// «Activar» del aviso, en vuelo hacia «Dónde viven tus datos». Del PROCESO, como `ColdStartICloudNotice`: lo pone el Panel
/// y lo consume la pantalla de almacenamiento al aparecer (`StorageSettingsView.beginAdoptFromPanelOfferIfRequested`).
@MainActor
enum CloudAdoptOfferRequest {
    static var pending = false
}
