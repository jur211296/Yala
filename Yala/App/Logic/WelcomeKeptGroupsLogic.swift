//
//  WelcomeKeptGroupsLogic.swift
//  Yala
//
//  **Qué ve el Welcome cuando los grupos del teléfono los acaba de conservar el aviso tardío para la misma persona.**
//  Ticket `groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start`, decisión A de Jürgen (2026-10-04).
//
//  Sin la marca (`LateNoticeKeptGroupsMark`), el Welcome trata TODO lo que hay en el teléfono como de otra persona —lo que
//  hacía hasta hoy, y lo que sigue haciendo el handover real—. Con ella, los grupos y su sesión son de quien está delante:
//  el Welcome solo cuenta como «datos del teléfono» lo personal, «Es mi primera vez → privado» no retira la sesión ni
//  limpia nombre y divisa, y su borrado de «Encontramos datos en iCloud» no purga el dominio de Grupos.
//
//  Quién lo consulta, todo en el Welcome: `ContentView.startFreshPrivateOnboarding`, el portal del relanzamiento
//  (`onNeedsMirrorRelaunch(.privateOnboarding)`), la pregunta del corpus del teléfono con mount neutro
//  (`WelcomeFlowContainer.deviceCorpusGate`), los tres borrados del Welcome —el de «Encontramos datos» de la puerta
//  privada, el del teléfono (`ContentView.performDeviceCorpusWipe`) y el del alert de «Es mi primera vez»— y el término de
//  DATOS de las puertas de organizador e invitación. **Un sitio nuevo que decida si esos grupos son de otra persona pasa
//  por aquí.**
//
//  **Lo que NO cubre, y es a propósito.** El término del ESPEJO de esas dos puertas: tras el aviso el store espeja, así que
//  las dos devuelven al neutro igual, y esa vuelta es un cierre de sesión que sube los grupos y los recupera al volver a
//  entrar (D5 del encargo). El término de datos solo decide con el mount neutro. Y el guard cross-cuenta de la nube, que
//  sigue contando los grupos: es otra pregunta (¿mezclo esta cuenta con lo de este teléfono?).
//

import Foundation

nonisolated enum WelcomeKeptGroupsLogic {

    /// ¿Hay en el teléfono datos que el Welcome tenga que tratar como de otra persona?
    ///
    /// - Parameters:
    ///   - hasPersonalData: cuentas o categorías propias (`ContentView.checkHasPersonalData`, que falla cerrado).
    ///   - hasGroupsData: grupos o filas puenteadas (la otra mitad de `ContentView.checkHasExistingData`).
    ///   - groupsKeptForThisPerson: la marca del aviso tardío, válida para la sesión de Grupos de ahora.
    static func deviceDataForWelcome(hasPersonalData: Bool,
                                     hasGroupsData: Bool,
                                     groupsKeptForThisPerson: Bool) -> Bool {
        hasPersonalData || (hasGroupsData && !groupsKeptForThisPerson)
    }

    /// ¿Retira «Es mi primera vez → privado» la sesión de la nube, el espejo de la asociación de Grupos y el nombre y la
    /// divisa que dejó el Apple ID? Es la frontera de «aquí empieza otra persona»; con la marca, no lo es.
    static func freshStartRetiresThePreviousPerson(groupsKeptForThisPerson: Bool) -> Bool {
        !groupsKeptForThisPerson
    }

    /// ¿Purga y sella el dominio de Grupos un borrado del TELÉFONO del Welcome (`performDeviceCorpusWipe` y el del alert)?
    /// Con la marca, no: queda lo personal que haya vuelto (el espejo re-importando, otro dispositivo), y los grupos son de
    /// quien está delante. Sin ella, el handover de siempre.
    static func deviceWipePurgesTheGroupsDomain(groupsKeptForThisPerson: Bool) -> Bool {
        !groupsKeptForThisPerson
    }

    /// El alcance del borrado de «Encontramos datos en iCloud → Empezar de cero» en la puerta privada del Welcome.
    /// `.handover` es la frontera de otra persona; con la marca es la misma persona limpiando lo suyo, igual que el aviso
    /// tardío que conservó los grupos (`ICloudWipeScope.lateNotice`).
    static func welcomeICloudWipeScope(groupsKeptForThisPerson: Bool) -> ICloudWipeScope {
        groupsKeptForThisPerson ? .importedRows : .handover
    }
}
