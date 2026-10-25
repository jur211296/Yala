//
//  WelcomeCoverContentLogic.swift
//  Yala
//
//  Qué enseña el cover del Welcome: los pasos del Welcome o la entrada a una cuenta de Yala (card 4gfj, 2026-10-25).
//
//  Hasta la 2.2 eran dos `fullScreenCover` del mismo anchor, y pasar de uno a otro cerraba una pantalla entera y abría la
//  otra desde abajo, con ~0,6 s de negro entre las dos. Jürgen eligió el fundido (A): el fondo morado se queda y el
//  contenido se funde, como entre los pasos del Welcome. Para eso las dos pantallas viven en UN cover y lo que cambia
//  es su contenido.
//
//  Los dos flags (`showWelcomeFlow`, `showWelcomeCloudSignIn`) siguen siendo los mismos —la matriz de readiness, los
//  productores y los tests los leen por separado—; lo único que se decide aquí es qué pinta el cover con ellos.
//

enum WelcomeCoverContentLogic {

    enum Content: Equatable {
        case flow
        case cloudSignIn
    }

    /// Duración del fundido entre las dos pantallas (decisión A de Jürgen, 2026-10-25). Con «Reducir movimiento» se
    /// mantiene: un fundido no desplaza nada.
    static let crossfadeSeconds: Double = 0.35

    /// Lo que piden los flags ahora, o `nil` si no piden nada (el cover se está cerrando o está cerrado).
    ///
    /// **Si los dos están encendidos, gana la entrada a la cuenta.** Ningún productor deja los dos a la vez —todos apagan
    /// uno al encender el otro en la misma vuelta—, pero la entrada es la pantalla que tiene trabajo en vuelo (el
    /// consentimiento, el inicio de sesión, el adopt), y taparla con el Welcome sería perderlo de vista.
    static func requested(showsFlow: Bool, showsCloudSignIn: Bool) -> Content? {
        if showsCloudSignIn { return .cloudSignIn }
        if showsFlow { return .flow }
        return nil
    }

    /// Lo que se pinta. Con los dos flags apagados el cover está bajando, y durante esa animación tiene que seguir
    /// enseñando lo último que enseñó: sin esto, la entrada a la cuenta que termina se cambiaría por el Hero a mitad
    /// de la bajada.
    static func displayed(showsFlow: Bool, showsCloudSignIn: Bool, last: Content) -> Content {
        requested(showsFlow: showsFlow, showsCloudSignIn: showsCloudSignIn) ?? last
    }

    /// ¿Está presentado el cover? Con cualquiera de los dos flags, y nunca con la invitación de grupo delante (el mismo
    /// `gated(by:)` que llevaban los dos covers por separado).
    static func isPresented(showsFlow: Bool, showsCloudSignIn: Bool, inhibited: Bool) -> Bool {
        (showsFlow || showsCloudSignIn) && !inhibited
    }

    /// ¿Acaba de irse la entrada a la cuenta hacia los pasos del Welcome sin cerrar el cover?
    ///
    /// Es el «Volver», «Crear otra cuenta» y la entrada a solo grupos. Antes eso cerraba el cover de la entrada y su
    /// `onDismiss` reponía `adoptStartsAtConsent` y `cloudSignInFromExistingChooser`; ahora el cover no se cierra y la
    /// limpieza tiene que correr aquí, o la siguiente entrada —el alta y el faro, que no escriben el primero— heredaría
    /// «abrir en el consentimiento» de la anterior.
    static func cloudSignInLeftForFlow(last: Content, now: Content?) -> Bool {
        last == .cloudSignIn && now == .flow
    }

    /// ¿Corre el respaldo del `onDismiss` de la entrada a la cuenta? Solo si lo último que enseñó el cover fue la
    /// entrada: cuando se cierra desde los pasos del Welcome (hacia Restaurar, la invitación o el onboarding) el cover
    /// del Welcome nunca tuvo `onDismiss`, y el respaldo lo devolvería al elector encima de la pantalla siguiente.
    static func runsCloudSignInDismissFallback(last: Content) -> Bool {
        last == .cloudSignIn
    }
}
