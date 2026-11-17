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
    /// - `markerFromAnotherDevice`: el marcador de migración de otro dispositivo llegó por el iCloud de este y es de la
    ///   cuenta que nombra el faro (`CloudMigrationController.adoptOfferMarkerPresent()`);
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

    /// ¿Algún marcador de migración nombra la cuenta que el faro dice vinculada a este Apple ID? (card «Tras dejar iCloud
    /// aparte, el modo privado dice "Tus datos ya están en tu cuenta" con esa cuenta vacía», encargo del 2026-11-16).
    ///
    /// El aviso afirma que los datos YA están en la cuenta. Hasta este día bastaba con que hubiera UN marcador en el iCloud de
    /// este teléfono, de cualquier cuenta (`markerReconciliation` cuenta filas, no mira de quién son). Y los marcadores no se
    /// van solos: el de una migración de hace meses, de otra cuenta o de una cuenta ya borrada, sigue en iCloud. Medido en
    /// el código: el faro (`CloudBeacon`) no dispara este aviso, aunque la card lo sospechaba.
    ///
    /// Un marcador solo existe tras una ida con sus datos verificados en la cuenta (el del cutover) o tras un adopt con
    /// cobertura total y al menos una fila (`relayAdoptMarkerIfCovered`): el de la cuenta del faro prueba que esa cuenta tiene
    /// datos. El faro lo escribe cada entrada a la nube de este Apple ID —también la que deja iCloud aparte— y lo borran la
    /// vuelta a iCloud y la eliminación de la cuenta, así que un marcador viejo de otra cuenta deja de contar en cuanto el
    /// faro nombra otra o se apaga. Sin faro o sin su hash, no se afirma nada: el aviso espera a que llegue el faro.
    static func markerNamesLinkedAccount(markerAccountHashes: [String], beaconLinked: Bool,
                                         beaconAccountHash: String?) -> Bool {
        guard beaconLinked, let beaconAccountHash, !beaconAccountHash.isEmpty else { return false }
        return markerAccountHashes.contains(beaconAccountHash)
    }
}

/// «Activar» del aviso, en vuelo hacia «Dónde viven tus datos». Del PROCESO, como `ColdStartICloudNotice`: lo pone el Panel
/// y lo consume la pantalla de almacenamiento al aparecer (`StorageSettingsView.beginAdoptFromPanelOfferIfRequested`).
@MainActor
enum CloudAdoptOfferRequest {
    static var pending = false
}
