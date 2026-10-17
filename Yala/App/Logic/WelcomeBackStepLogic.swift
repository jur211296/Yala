//
//  WelcomeBackStepLogic.swift
//  Yala
//
//  A dónde vuelve un «atrás» de las pantallas que se abren desde «¡Hola de nuevo!» (UX 2.2 · L6-3 y L6-11).
//
//  Restaurar desde iCloud y la entrada a una cuenta de la nube son covers propios, fuera del contenedor del Welcome,
//  así que al volver hay que decirle al contenedor en qué step reabrirse. Hasta la 2.2 volvían a «¿Qué quieres hacer en
//  Yala?», un nivel más arriba del que salió la persona: para reintentar tenía que volver a elegir «Ya tengo una
//  cuenta». Es el mismo defecto que el «atrás» de la invitación corrigió en agosto (`returnToGroupsChooser`).
//

enum WelcomeBackStepLogic {

    /// El step de origen de una pantalla abierta desde «Ya tengo una cuenta». Con bypass —una sola entrada visible,
    /// que es el caso de los XCUITest y de un teléfono sin backend— el sub-chooser no se enseñó y el origen es el
    /// chooser de primer nivel: volver a una pantalla que la persona nunca vio sería enseñarle una nueva.
    static func existingBranchOrigin(options: [WelcomeAccountChoiceLogic.ExistingOption]) -> WelcomeFlowStep {
        WelcomeAccountChoiceLogic.bypass(options) == nil ? .existingChooser : .chooser
    }

    /// A dónde vuelve «Volver» de Restaurar según la pantalla desde la que se abrió (review de UX 2.2 · L6-11): de
    /// «¡Hola de nuevo!», allí; de cualquier otra —el bypass sin sub-chooser, o la puerta privada que encontró datos
    /// en iCloud—, al chooser de primer nivel, que la persona sí vio. Antes, desde la puerta, caía en «¡Hola de
    /// nuevo!», una pantalla que no había visto nunca.
    static func restoreOrigin(openedFrom step: WelcomeFlowStep) -> WelcomeFlowStep {
        step == .existingChooser ? .existingChooser : .chooser
    }

    /// ¿Cancelar el consentimiento de la nube sale de la entrada entera? Solo cuando la entrada lo pidió (la abrió
    /// «¡Hola de nuevo!», donde el consentimiento es su primera pantalla) y la pantalla sigue en el intro — es decir,
    /// nada se ha firmado todavía. Con el flujo en marcha el consentimiento no se enseña, pero si una fase posterior
    /// lo reabriera, cancelarlo no debe arrancar a la persona de una pantalla de progreso.
    static func consentCancelReturnsBack(requested: Bool, isAtIntro: Bool) -> Bool {
        requested && isAtIntro
    }
}
