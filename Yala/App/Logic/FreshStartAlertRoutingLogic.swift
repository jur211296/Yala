//
//  FreshStartAlertRoutingLogic.swift
//  Yala
//
//  A dónde sigue «Borrar todo y continuar» del alert del shell cuando quedan cambios de grupos sin subir.
//

import Foundation

/// Decisión pura de a dónde siguen las salidas del alert «empiezo de cero» (`ShellDataAlertsModifier`): el botón
/// destructivo cuando el outbox de grupos no está vacío, y desde el 2026-10-07 también «Cancelar» y el «OK» del aviso
/// de fallo (`dismissReopensTheWelcome`).
///
/// **La pregunta es «¿había un Welcome debajo?», no «¿está completo el onboarding?»** (ticket
/// `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes`, decisión A de Jürgen del 2026-10-06).
/// La puerta privada vive dentro del Welcome, y el alert solo puede seguir en ella reabriendo ese cover. Hasta ese día la
/// guarda era `hasCompletedOnboarding`, que se tomaba por «el Welcome no estaba montado»: no es lo mismo. Al empezar a
/// entrar con una cuenta en la nube, `onAdoptStarted` pone el flag en `true` —la kill-safety del adopt— y ninguna de sus
/// salidas (error, `.adoptExit`, `.lineageExit`, «Cancelar la activación») lo devuelve: vuelven al Welcome con el flag
/// en `true`. Ahí el alert se negaba en el sitio con «inténtalo en un rato», y con cambios que no pueden subir nunca
/// (de otra cuenta, o de una sin sesión) se negaba para siempre.
///
/// **El testigo se captura al DISPARAR el alert, no al pulsar el botón**: presentar el alert desmonta el cover del
/// Welcome (traza medida en `ShellDataAlertsModifier`), así que al pulsar `showWelcomeFlow` ya es `false` siempre.
///
/// **Hoy `.refuseInPlace` no se alcanza, y conviene saberlo** (medido el 2026-10-06, review adversarial): el único
/// disparador del alert es `ContentView.startFreshPrivateOnboarding`, y sus llamadores son closures del propio
/// `WelcomeFlowContainer`, así que el testigo siempre vale `true`. En la práctica, con grupos pendientes el alert siempre
/// sigue en la puerta, también desde un Welcome que una sesión solo-grupos reabre con el onboarding completo: la puerta
/// sube con su sesión y solo ofrece perderlos con un motivo que esperar no arregla, y el borrado directo con el outbox
/// vacío ya borraba igual en esa celda. La negativa queda para un disparador futuro fuera del Welcome, y
/// `FreshStartAfterAdoptExitWiringTests` cuenta los disparadores para que aparecer uno no pase en silencio.
enum FreshStartAlertRoutingLogic {

    /// A dónde sigue el borrado con cambios de grupos pendientes.
    enum PendingGroupsRoute: Equatable {
        /// La puerta privada del Welcome en su borrado del teléfono: sube lo que pueda, enseña el motivo y, si esperar
        /// no lo arregla, ofrece perderlos con su cifra.
        case privateGate
        /// No se borra nada y el aviso de fallo pide volver a intentarlo. Solo cuando no hay Welcome que reabrir: abrirlo
        /// le plantaría el flujo de bienvenida a alguien que ya usa la app. Hoy no lo produce ningún camino (ver arriba).
        case refuseInPlace
    }

    /// - Parameters:
    ///   - hasCompletedOnboarding: el flag al pulsar.
    ///   - presentedOverWelcome: si el Welcome estaba montado cuando se encendió el alert.
    ///
    /// **`!hasCompletedOnboarding` se queda como término**: es la guarda de antes, y con él ninguna celda que hoy iba a
    /// la puerta deja de ir. Lo nuevo es la segunda mitad.
    static func pendingGroupsRoute(hasCompletedOnboarding: Bool, presentedOverWelcome: Bool) -> PendingGroupsRoute {
        welcomeIsThereToReopen(hasCompletedOnboarding: hasCompletedOnboarding,
                               presentedOverWelcome: presentedOverWelcome) ? .privateGate : .refuseInPlace
    }

    /// **«Cancelar» y el «OK» del aviso de fallo: ¿vuelven al Welcome en `.chooser`?** (ticket
    /// `fresh-start-alert-cancel-after-an-adopt-exit-lands-in-the-app`, 2026-10-07). Las dos salidas que no borran.
    /// Hasta ese día reabrían solo `if !hasCompletedOnboarding`, y tras salir de un adopt el flag ya es `true`: la
    /// persona aterrizaba dentro de la app, sobre los datos que acababa de decidir no borrar. Decisión de esa noche
    /// (la que recomendaba el ticket): lo correcto es la bienvenida, de donde venía.
    static func dismissReopensTheWelcome(hasCompletedOnboarding: Bool, presentedOverWelcome: Bool) -> Bool {
        welcomeIsThereToReopen(hasCompletedOnboarding: hasCompletedOnboarding, presentedOverWelcome: presentedOverWelcome)
    }

    /// **La pregunta que comparten las tres salidas del alert**: ¿había un Welcome debajo al encenderlo? Presentar el
    /// alert lo desmonta, así que la única forma de seguir en él —la puerta privada, o volver a elegir— es reabrirlo.
    ///
    /// **`!hasCompletedOnboarding` se queda como término**: es la guarda de antes, y con él ninguna celda que ya
    /// reabría deja de hacerlo. Sin onboarding completo no hay app debajo, así que reabrir es lo único que no deja la
    /// pantalla negra. Con el onboarding completo y sin testigo —hoy ningún camino lo produce— no se reabre: plantaría
    /// la bienvenida a alguien que ya usa la app.
    private static func welcomeIsThereToReopen(hasCompletedOnboarding: Bool, presentedOverWelcome: Bool) -> Bool {
        !hasCompletedOnboarding || presentedOverWelcome
    }
}
