//
//  SetupDeckLogic.swift
//  Yala
//
//  Y23-05 (bienvenida 2.3, docs/onboarding-2-3/SPEC.md): «Primeros pasos» se ve como un MAZO. Adelante, el paso
//  actual («Primeros pasos · N de 7» y su nombre); asomando detrás, los dos siguientes que faltan («Después: …»,
//  «Luego: …»). El mazo avanza al completar u omitir el de adelante y desaparece al resolver el séptimo.
//
//  Panel progresivo (acuerdo de Jürgen del 19-nov-2026, para «Ingresos y gastos» y «Solo gastos»): mientras el mazo está
//  a medias, el Panel enseña solo lo que la persona ya completó. Al entrar, solo el mazo; tras la primera cuenta, esa
//  cuenta en «Tus finanzas»; tras aprender a registrar, «Últimos registros»; tras el presupuesto y el pago planificado,
//  sus widgets si dijo que sí. Sin guías ni coach tips. `PrimerosPasosPanelGate` es esa regla, sin efectos.
//

import Foundation

nonisolated enum SetupDeckLogic {

    struct Deck: Equatable {
        /// El paso de adelante.
        let current: SetupStepID
        /// Su lugar en el orden de la ficha (1…7): «Primeros pasos · N de 7».
        let position: Int
        /// Cuántos pasos tiene el mazo.
        let total: Int
        /// Los que asoman detrás: como mucho dos, los siguientes en orden que aún faltan.
        let upcoming: [SetupStepID]
    }

    /// Cuántos pasos asoman detrás del de adelante.
    static let peekingCount = 2

    /// El mazo para un orden y lo ya resuelto (hecho u omitido). `nil` cuando no queda ninguno por resolver.
    static func deck(order: [SetupStepID], isResolved: (SetupStepID) -> Bool) -> Deck? {
        guard let index = order.firstIndex(where: { !isResolved($0) }) else { return nil }
        let upcoming = order[(index + 1)...].filter { !isResolved($0) }.prefix(peekingCount)
        return Deck(current: order[index], position: index + 1, total: order.count, upcoming: Array(upcoming))
    }
}

// MARK: - Panel progresivo

/// Lo que el Panel deja ver mientras el mazo está a medias. Fuera de `SetupDeckLogic` (que es `nonisolated`) porque lee
/// tipos del Panel aislados al main actor.
struct PrimerosPasosPanelGate: Equatable {
    /// El mazo está a la vista y sin terminar. Fuera de ahí la puerta no cambia nada.
    let isActive: Bool
    /// «Tus finanzas» con la cuenta.
    let showsAccounts: Bool
    /// El widget «Últimos registros».
    let showsLatestRecords: Bool
    /// La sección Planificación: la persona dijo «Sí, mostrarlo en el Panel» en el paso 3 o en el 4.
    let showsPlanning: Bool

    /// Sin mazo a medias: el Panel de siempre.
    static let inactive = PrimerosPasosPanelGate(isActive: false, showsAccounts: true, showsLatestRecords: true,
                                                 showsPlanning: true)

    /// - Parameters:
    ///   - deckInProgress: el mazo se ve y no está terminado (`SetupChecklistManager.isPrimerosPasosShown`).
    ///   - expensesOnly: «Solo gastos». Ahí Yala crea sola la cuenta y el paso 1 sale hecho sin que la persona haga
    ///     nada; la cuenta aparece con el primer paso que sí hace ella, aprender a registrar. Así, al entrar, solo
    ///     el mazo, igual que con «Ingresos y gastos».
    ///   - accountStepResolved: el paso 1 está hecho u omitido.
    ///   - recordStepResolved: el paso 2 está hecho u omitido.
    ///   - planningShown: dijo «Sí» al Panel en el paso 3 o en el 4 (`SetupChecklistManager.isPlanningShownInPanel`).
    static func make(deckInProgress: Bool, expensesOnly: Bool, accountStepResolved: Bool,
                     recordStepResolved: Bool, planningShown: Bool) -> PrimerosPasosPanelGate {
        guard deckInProgress else { return .inactive }
        return PrimerosPasosPanelGate(
            isActive: true,
            showsAccounts: expensesOnly ? recordStepResolved : accountStepResolved,
            showsLatestRecords: recordStepResolved,
            showsPlanning: planningShown)
    }

    /// Las secciones ocultas que pinta el Panel: las que ocultó la persona, más las que el mazo aún no abrió.
    /// Salud, Tendencias, Distribución y Herramientas no salen hasta terminar Primeros pasos.
    func hiddenSections(_ preferenceHidden: Set<PanelSectionKind>) -> Set<PanelSectionKind> {
        guard isActive else { return preferenceHidden }
        var allowed: Set<PanelSectionKind> = []
        if showsAccounts { allowed.insert(.accounts) }
        if showsLatestRecords { allowed.insert(.latestRecords) }
        if showsPlanning { allowed.insert(.planificacion) }
        return preferenceHidden.union(Set(PanelSectionKind.allCases).subtracting(allowed))
    }

    /// El saldo grande (con su píldora de período) sale con la cuenta, no antes (decisión 137 de Jürgen, 19-nov-2026:
    /// «al entrar solo se ven los Primeros pasos»). Antes de la cuenta solo diría S/ 0.00 encima del mazo.
    var showsBalanceHero: Bool { !isActive || showsAccounts }

    /// La barra de período y filtros acompaña a los widgets: con el mazo a medias, no sale.
    var showsFilterBar: Bool { !isActive }

    /// La tarjeta de ganancia o pérdida por tipo de cambio es contenido del Panel, como un widget.
    var showsExchangeResultCard: Bool { !isActive }

    /// Coach marks del Panel (tour Pro, «Tu saldo se mueve solo»): ninguno con el mazo a medias.
    var allowsCoachMarks: Bool { !isActive }

    /// Qué avisos siguen con el mazo a medias. Los que hablan de los datos de la persona (la nube) y la versión
    /// nueva siguen; la guía del Panel, la oferta Pro, el empujón de grupos y Siri esperan a que termine.
    func allows(_ notice: PanelNotice) -> Bool {
        guard isActive else { return true }
        switch notice {
        case .cloudAdoptOffer, .updateAvailable: return true
        case .panelGuide, .proOffer, .nudge, .siriTip: return false
        }
    }

    /// Los avisos encendidos, sin los que el mazo calla.
    func filtering(_ flags: PanelNoticeQueueLogic.Flags) -> PanelNoticeQueueLogic.Flags {
        var result = flags
        result.cloudAdoptOffer = flags.cloudAdoptOffer && allows(.cloudAdoptOffer)
        result.panelGuide = flags.panelGuide && allows(.panelGuide)
        result.updateAvailable = flags.updateAvailable && allows(.updateAvailable)
        result.proOffer = flags.proOffer && allows(.proOffer)
        result.nudge = flags.nudge && allows(.nudge)
        result.siriTip = flags.siriTip && allows(.siriTip)
        return result
    }
}
