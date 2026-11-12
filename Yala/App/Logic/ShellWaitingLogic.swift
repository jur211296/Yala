//
//  ShellWaitingLogic.swift
//  Yala
//
//  Card apsn · qué pinta `ContentView` debajo de las presentaciones cuando todavía no hay shell (onboarding sin terminar).
//
//  Hasta este cambio, el fondo vacío del tema. La bienvenida y la cadena de Grupos son presentaciones a pantalla completa, y
//  entre una y la siguiente asoma lo de debajo: en la rama del organizador, el cover del Welcome se va y el educativo no
//  puede subir hasta que el arranque asienta (bloqueo `bootstrapPending` de la matriz de readiness, que existe porque un
//  cover montado con el arranque en curso se queda pegado). Medido el 21-oct en un iPhone recién instalado: ~10 s de
//  negro. La espera se acortó (el histórico de tasas ya no la alarga) pero no desaparece en todos los teléfonos; lo que
//  se ve mientras tanto es la pantalla de carga de la app, con su marca.
//

import Foundation

nonisolated enum ShellWaitingLogic {

    /// ¿Va la pantalla de carga con marca en el sitio del fondo vacío?
    ///
    /// - Parameters:
    ///   - groupsOrganizerFlowActive: la rama del organizador salió del Welcome y su cadena sigue. Entre una presentación y
    ///     la siguiente, sin shell debajo.
    ///   - chainPresentationUp: algún paso de esa cadena está en pantalla (educativo, inicio de sesión, consentimiento,
    ///     bloqueo, nombre del grupo). Las hojas dejan ver lo de debajo, y detrás de ellas se queda el fondo de siempre: la
    ///     pantalla de carga es para el hueco ENTRE pasos, no un fondo nuevo para la cadena (lo cazó la review).
    ///   - isBootstrapSettled: `SessionState.isBootstrapSettled`. Con el arranque en curso la matriz retiene cualquier
    ///     presentación, así que lo que se vea en ese rato es esto.
    static func showsBrandedWaiting(
        groupsOrganizerFlowActive: Bool, chainPresentationUp: Bool, isBootstrapSettled: Bool
    ) -> Bool {
        !isBootstrapSettled || (groupsOrganizerFlowActive && !chainPresentationUp)
    }
}
