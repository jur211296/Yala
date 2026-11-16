//
//  ICloudAsideEntryLogic.swift
//  Yala
//
//  Entrar con Google o Apple desde el Welcome teniendo en el teléfono los datos del iCloud privado
//  (decisión de Jürgen del 2026-11-10, opción B, clave t1503u-icloud; sustituye a la C del 9-nov).
//
//  Hasta ese día el guard cross-cuenta (`CrossAccountEntryGuardLogic`) devolvía `.blockedForeignData`
//  sobre esos datos y la pantalla decía «Este dispositivo tiene datos de otra cuenta», también al dueño:
//  la única salida era «Empezar de cero», que borra además iCloud. El guard no puede saber si los datos
//  son de quien entra —el claim que lo probaría vive en `UserDefaults` y muere al reinstalar—, y la
//  sesión nocturna del 9-nov midió que no hay prueba fiable en el caso general.
//
//  **La opción B no necesita esa prueba, y por eso vale para el dueño y para el teléfono ajeno a la vez.**
//  Se abre la nube con la cuenta que entra y los datos de iCloud se dejan EN iCloud, sin tocar: ni se
//  suben a la cuenta que entra, ni se mezclan con la suya, ni se borran de iCloud. Lo único que sale del
//  teléfono es su copia LOCAL, y sale por el verbo que ya existe para eso —la vuelta al neutro del cierre
//  privado (`CloudSessionSignOut`): esperar a que lo último llegue a iCloud, borrar por ARCHIVOS antes del
//  mount con el espejo sin montar, y relanzar—, el mismo que usa la puerta de Grupos del Welcome
//  (`GroupsOrganizerGateLogic.returnsToNeutral`). Tras el relanzamiento el store monta NEUTRO y vacío, y
//  la entrada a la cuenta adopta sobre él como en un teléfono recién instalado.
//
//  **Solo cuando el corpus tiene copia en iCloud.** Es la frase que hace segura la opción B: «los datos
//  siguen en iCloud» tiene que ser verdad. Sin copia (`CopyChannel.none`, que solo se afirma con prueba)
//  lo que se borraría no está en ningún otro sitio, y en un teléfono prestado no sería de quien entra: se
//  queda el bloqueo de siempre. Y con el teléfono en la nube (`cloudSecureSignOut`) tampoco: ese cierre
//  no borra por archivos y no hay iCloud privado que dejar aparte.
//
//  **Y solo si el teléfono no guarda grupos de la era CloudKit que nunca migraron** (review adversarial del
//  2026-11-10). Esos grupos viven en el store de Grupos (`cloudKitDatabase: .none`), no en iCloud, y la vuelta
//  al neutro se los lleva para no volver a contarlos tras reabrir (`CloudSignOutFlowLogic.wipeForgetsGroups`):
//  no tienen de dónde volver. Jürgen decidió llevárselos solo en «Crear mi primer grupo» (decisión A del
//  29-oct); esta entrada no lo hereda, así que con ellos sigue el bloqueo y no se borra nada.
//

import Foundation

nonisolated enum ICloudAsideEntryLogic {

    /// Qué hace la entrada a la cuenta cuando el guard cross-cuenta no deja adoptar sobre lo que hay.
    enum Exit: Equatable {
        /// El corpus del teléfono vive en el iCloud privado: se deja ahí, se vacía la copia local por el
        /// cierre privado y se entra a la cuenta en un teléfono neutro.
        case leaveICloudAside
        /// No hay copia en iCloud que lo guarde, o el teléfono no está en iCloud: la pantalla de bloqueo.
        case staysBlocked
    }

    /// - Parameters:
    ///   - exitCell: la celda de cierre de ESTE teléfono (`CloudSignOutFlowLogic.path`), medida con los
    ///     mismos términos que el coordinador. Solo las tres que borran por archivos dejan iCloud intacto.
    ///   - copyChannel: `WelcomeGroupsGateView.copyChannelNow` (el de `CloudSessionSignOut.privateCopyChannel()` con el
    ///     seam del host de UI test). **Sin valor por defecto**, como los términos del guard: un default `.iCloud`
    ///     dejaría borrar sin copia en un call-site nuevo.
    ///   - hasLegacyCloudKitGroups: `CloudSessionSignOut.hasLegacyCloudKitGroupRows`. Sin valor por defecto por lo mismo:
    ///     `false` dejaría borrar grupos que no están en ningún otro sitio.
    static func exit(exitCell: CloudSignOutFlowLogic.Path,
                     copyChannel: PrivateSignOutExportGateLogic.CopyChannel,
                     hasLegacyCloudKitGroups: Bool) -> Exit {
        guard !hasLegacyCloudKitGroups else { return .staysBlocked }
        switch exitCell {
        case .privateSignOut, .privateWithGroupsSignOut, .groupsOnlySignOut:
            return copyChannel == .iCloud ? .leaveICloudAside : .staysBlocked
        case .cloudSecureSignOut:
            return .staysBlocked
        }
    }

    /// A qué destino vuelve el Welcome tras el relanzamiento: la entrada a la cuenta con el MISMO método
    /// con el que la persona acababa de firmar. Uno por método porque el destino viaja como `rawValue` en
    /// `UserDefaults` y no lleva carga.
    static func destination(after provider: CloudSignInProvider) -> WelcomeMirrorRelaunchLogic.Destination {
        switch provider {
        case .apple: return .cloudSignInAppleKeepingICloudAside
        case .google: return .cloudSignInGoogleKeepingICloudAside
        }
    }

    /// El método que retoma un destino de los de arriba, o `nil` si el destino no es de esta entrada.
    static func provider(resuming destination: WelcomeMirrorRelaunchLogic.Destination) -> CloudSignInProvider? {
        switch destination {
        case .cloudSignInAppleKeepingICloudAside: return .apple
        case .cloudSignInGoogleKeepingICloudAside: return .google
        default: return nil
        }
    }
}
