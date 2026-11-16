//
//  PrimerosPasosPlanningLogic.swift
//  Yala
//
//  Las reglas, sin efectos, de los pasos 3, 4 y 5 de Primeros pasos 2.3 (docs/onboarding-2-3/SPEC.md, cards Y23-11,
//  Y23-12 y Y23-13; prototipo oficial v35, pestañas 5, 6 y 7):
//
//   · Paso 3 · Primer presupuesto: el orden de las preguntas, el nombre que Yala propone, las subcategorías que guarda
//     (`subcategoryIDs`) y los avisos (75 % y 100 % propuestos por defecto).
//   · Paso 4 · Primer pago planificado: los seis tipos (subcategorías del seed), el orden de las preguntas, la frecuencia
//     y el aviso que se guardan.
//   · Paso 5 · Grupos: si el paso se salta (ya vio el onboarding de Grupos) y cómo queda al salir.
//   · Los dos primeros: qué hacer con el Panel si la persona dice «Sí, mostrarlo en el Panel».
//
//  Las vistas (`FirstBudgetFlowView`, `FirstScheduledPaymentFlowView`, `GroupsTutorialFlowView`) solo preguntan aquí.
//

import Foundation

// MARK: - Paso 3 · Primer presupuesto (Y23-11)

nonisolated enum FirstBudgetFlowLogic {

    /// «¿Qué gastos cuenta?».
    enum Scope: Equatable {
        /// «Todos mis gastos»: un tope para todo (el presupuesto sin subcategorías).
        case all
        /// «Solo algunas categorías».
        case categories
    }

    enum Step: Hashable {
        case scope
        case categories
        case subcategories
        case period
        case dates
        case limit
        case name
        case alert
        case panel
        case done
    }

    /// «¿Te avisamos cuando vayas llegando al tope?».
    enum Alert: Equatable {
        /// «Sí, al 75 % y al 100 %» (propuesto por defecto).
        case at75And100
        /// «Sí, solo al llegar al tope».
        case at100
        /// «No, gracias».
        case none

        /// Los umbrales que se guardan (`Budget.alertThresholds`). El 50 % y el 90 % siguen en Editar presupuesto.
        var thresholds: Set<Int> {
            switch self {
            case .at75And100: return [75, 100]
            case .at100: return [100]
            case .none: return []
            }
        }

        var isEnabled: Bool { self != .none }
    }

    /// La opción destacada: 75 % y 100 % (ficha: «75 % y 100 % propuestos por defecto»).
    static let proposedAlert: Alert = .at75And100

    /// Las preguntas, en orden. «Solo algunas categorías» añade ¿Cuáles? y ¿Algo que no quieras contar?; «Una sola vez»
    /// añade las fechas.
    static func steps(scope: Scope?, period: BudgetPeriodType?) -> [Step] {
        var steps: [Step] = [.scope]
        if scope == .categories { steps += [.categories, .subcategories] }
        steps.append(.period)
        if period == .unique { steps.append(.dates) }
        steps += [.limit, .name, .alert, .panel, .done]
        return steps
    }

    /// La pregunta que sigue a `step`.
    static func next(after step: Step, scope: Scope?, period: BudgetPeriodType?) -> Step {
        let all = steps(scope: scope, period: period)
        guard let index = all.firstIndex(of: step), index + 1 < all.count else { return .done }
        return all[index + 1]
    }

    /// El nombre que Yala propone: «Mis gastos del mes» para todo; con categorías, la única elegida o las dos primeras
    /// unidas («Alimentación y Transporte»). Es obligatorio en la app, y por eso siempre hay uno.
    static func suggestedName(
        scope: Scope?,
        categoryNames: [String],
        allExpenses: String,
        joined: (String, String) -> String,
        fallback: String
    ) -> String {
        switch scope {
        case .all:
            return allExpenses
        case .categories:
            switch categoryNames.count {
            case 0: return fallback
            case 1: return categoryNames[0]
            default: return joined(categoryNames[0], categoryNames[1])
            }
        case nil:
            return fallback
        }
    }

    /// Las subcategorías que guarda el presupuesto: las de las categorías elegidas, menos las que la persona quitó. Llegan
    /// todas marcadas (ficha). Con «Todos mis gastos», ninguna: el presupuesto cuenta todos los gastos.
    static func subcategoryIDs(scope: Scope?, chosen: [[UUID]], removed: Set<UUID>) -> [UUID] {
        guard scope == .categories else { return [] }
        var seen: Set<UUID> = []
        var result: [UUID] = []
        for id in chosen.joined() where !removed.contains(id) && !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    /// Si se puede seguir desde ¿Algo que no quieras contar?: queda al menos una subcategoría. Quitarlas todas dejaría un
    /// presupuesto sin filtro, que cuenta TODO: no es lo que eligió.
    static func canContinueSubcategories(scope: Scope?, chosen: [[UUID]], removed: Set<UUID>) -> Bool {
        !subcategoryIDs(scope: scope, chosen: chosen, removed: removed).isEmpty
    }

    /// Si el tope escrito vale: un número mayor que cero.
    static func isValidLimit(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value > 0 && value.isFinite
    }

    /// Las fechas de «Una sola vez»: el fin no antes del inicio.
    static func isValidRange(start: Date, end: Date) -> Bool {
        end >= start
    }
}

// MARK: - Paso 4 · Primer pago planificado (Y23-12)

nonisolated enum FirstScheduledPaymentFlowLogic {

    /// Los seis tipos de la primera pantalla: cada uno es una subcategoría de gasto del seed, con nombre corto. Sin marcas
    /// (ficha: nada de Netflix).
    enum Kind: String, CaseIterable, Identifiable {
        case rent
        case utilities
        case phone
        case utilitySubscription
        case leisureSubscription
        case fitness

        var id: String { rawValue }

        /// El icono de su subcategoría en `CategorySeed`: cada uno es único entre las de gasto, y así se encuentra la
        /// subcategoría de la persona aunque el seed se escribiera en otro idioma.
        var seedIcon: String {
            switch self {
            case .rent: return "key.fill"
            case .utilities: return "bolt.fill"
            case .phone: return "phone.fill"
            case .utilitySubscription: return "app.badge.fill"
            case .leisureSubscription: return "play.circle.fill"
            case .fitness: return "figure.run"
            }
        }

        /// «Es una suscripción» encendido de entrada en las dos de suscripción.
        var isSubscription: Bool {
            self == .utilitySubscription || self == .leisureSubscription
        }

        /// «Cambia cada vez» (monto estimado) encendido de entrada en Servicios.
        var isVariableAmount: Bool {
            self == .utilities
        }
    }

    enum Step: Hashable {
        case kind
        case details
        case when
        case reminder
        case panel
        case done
    }

    static let steps: [Step] = [.kind, .details, .when, .reminder, .panel, .done]

    static func next(after step: Step) -> Step {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return .done }
        return steps[index + 1]
    }

    /// «¿Cuándo toca pagar?».
    enum Frequency: String, CaseIterable, Identifiable {
        case monthly
        case weekly
        case yearly
        case once

        var id: String { rawValue }

        /// Si se repite. «Una vez» no.
        var isRecurring: Bool { self != .once }

        /// Cada cuánto, cuando se repite (siempre cada 1: «Cada N» queda en el editor).
        var recurrenceType: RecurrenceType {
            switch self {
            case .monthly, .once: return .monthly
            case .weekly: return .weekly
            case .yearly: return .yearly
            }
        }
    }

    /// Los días del mes que se ofrecen como atajo; «Otro» deja escribir cualquiera.
    static let monthDayShortcuts = [1, 5, 10, 15, 20, 30]

    static func isValidMonthDay(_ day: Int) -> Bool {
        (1...31).contains(day)
    }

    /// «¿Te avisamos antes de que toque pagar?».
    enum Reminder: String, CaseIterable, Identifiable {
        /// «Sí, 3 días antes» (propuesto por defecto).
        case threeDaysBefore
        case oneDayBefore
        case sameDay
        case none

        var id: String { rawValue }

        /// Lo que se guarda (`ScheduledPayment.notifyOnDueDate` / `notifyDaysBefore`): un aviso, el elegido. Los plazos
        /// de 2, 5, 7, 14 y 30 días siguen en el editor (fuera de alcance de la ficha).
        var notifyOnDueDate: Bool { self == .sameDay }

        var notifyDaysBefore: Int {
            switch self {
            case .threeDaysBefore: return 3
            case .oneDayBefore: return 1
            case .sameDay, .none: return 0
            }
        }

        var wantsReminder: Bool { self != .none }
    }

    static let proposedReminder: Reminder = .threeDaysBefore

    /// Nombre y monto: el nombre no vacío y el monto mayor que cero.
    static func canContinueDetails(name: String, amount: Double?) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && FirstBudgetFlowLogic.isValidLimit(amount)
    }

    /// El día de la semana del calendario (1 = domingo … 7 = sábado) en el orden de la fila «Lu Ma Mi Ju Vi Sá Do».
    static let weekdaysMondayFirst = [2, 3, 4, 5, 6, 7, 1]
}

// MARK: - Paso 5 · Grupos (Y23-13)

nonisolated enum GroupsTutorialLogic {

    /// Lo que pasa al tocar el paso 5 del mazo.
    enum Entry: Equatable {
        /// Ya vio el onboarding de Grupos: el paso se da por hecho y un aviso lo dice.
        case alreadySeen
        /// No lo vio: su onboarding, como página del tutorial.
        case showTutorial
    }

    static func entry(hasShownGroupsOnboarding: Bool) -> Entry {
        hasShownGroupsOnboarding ? .alreadySeen : .showTutorial
    }

    /// Cómo termina el tutorial de Grupos.
    enum Exit: Equatable {
        /// «Atrás» desde la primera parte: como si no lo hubiera abierto. El mazo sigue en el paso 5.
        case closed
        /// «Omitir este paso» antes del consentimiento: no lo vio entero.
        case skipped
        /// «Ahora no» en el consentimiento o en «¿Qué quieres hacer?»: lo vio, pero no empieza un grupo.
        case seenNotNow
        /// «Crear mi primer grupo».
        case createGroup
        /// «Tengo un enlace de invitación», con el enlace ya pegado.
        case joinWithLink
    }

    /// Si al salir se marca `hasShownGroupsOnboarding`, para que Grupos no lo repita (ficha: «al completarlo aquí»).
    static func marksOnboardingSeen(_ exit: Exit) -> Bool {
        exit != .skipped && exit != .closed
    }

    /// Si el mazo pasa al 6 al salir. El paso 5 queda omitido de entrada; lo da por hecho el grupo cuando llega
    /// (`SetupChecklistManager.autoDetect` cuenta los grupos al volver al Panel), así un formulario cancelado o un enlace
    /// que falla no lo dejan «hecho» sin grupo.
    static func advancesDeck(_ exit: Exit) -> Bool {
        exit != .closed
    }

    /// Si al volver al Panel sale la guía «Tus grupos, a un toque»: cuando se fue a la pestaña Grupos a crear el grupo.
    /// Unirse por enlace no cambia de pestaña (lo presenta el enrutador sobre el Panel), y la guía saldría a destiempo.
    static func showsPlaceGuide(_ exit: Exit) -> Bool {
        exit == .createGroup
    }
}

// MARK: - «¿Lo ponemos en tu Panel?» (pasos 3 y 4)

enum PrimerosPasosPanelWidgetLogic {

    /// Lo que cambia en el Panel al decir que sí.
    struct Change: Equatable {
        /// Las secciones ocultas, ya sin «Planificación».
        let sectionsHidden: [String]
        /// Los widgets ocultos de «Planificación».
        let planningHidden: [String]
    }

    /// Enseña un widget de «Planificación» (Presupuestos o Pagos planificados). Al terminar el paso 2 el Panel solo
    /// enseña la cuenta y «Últimos registros», así que la sección suele estar oculta: al abrirla se enseña SOLO este widget
    /// (el otro queda oculto hasta su paso). Si la sección ya se veía, solo se quita este widget de los ocultos.
    static func show(
        _ widget: WidgetType,
        sectionsHidden: [String],
        planningHidden: [String]
    ) -> Change {
        let section = PanelSectionKind.planificacion.rawValue
        let sectionWasHidden = sectionsHidden.contains(section)
        let newSections = sectionsHidden.filter { $0 != section }
        let planning = WidgetType.defaultWidgets(in: .planificacion).map(\.rawValue)
        let newPlanning: [String]
        if sectionWasHidden {
            newPlanning = planning.filter { $0 != widget.rawValue }
        } else {
            newPlanning = planningHidden.filter { $0 != widget.rawValue }
        }
        return Change(sectionsHidden: newSections, planningHidden: newPlanning)
    }
}
