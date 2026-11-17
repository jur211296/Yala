//
//  L10n+IAGuiados.swift
//  Yala
//
//  Los textos de los guiados de Yala IA (crear un presupuesto o un pago planificado desde el chat). Lo que ya decía
//  Primeros pasos con las mismas palabras se reusa de `L10n.PrimerosPasos23`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero. Con argumentos, formatea.
private func iaGuidedString(_ key: String, _ args: CVarArg...) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    var value = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if value == sentinel, let parent = resolution.parentBundle {
        value = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
    }
    if value == sentinel {
        value = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    }
    if value == sentinel { value = key }
    return args.isEmpty ? value : String(format: value, arguments: args)
}

extension L10n {
    enum IAGuiados {
        /// «Armemos tu presupuesto. Solo te pregunto lo que falta.»
        static var budgetIntro: String { iaGuidedString("iaGuided.budget.intro") }
        /// «Anotemos tu pago planificado. Solo te pregunto lo que falta.»
        static var paymentIntro: String { iaGuidedString("iaGuided.payment.intro") }
        /// «Nuevo presupuesto»
        static var budgetHeader: String { iaGuidedString("iaGuided.budget.header") }
        /// «Nuevo pago planificado»
        static var paymentHeader: String { iaGuidedString("iaGuided.payment.header") }
        /// «¿A qué le pones tope?»
        static var budgetCategoriesQuestion: String { iaGuidedString("iaGuided.budget.categories.question") }
        /// «Toca una o varias categorías, o elige todos tus gastos.»
        static var budgetCategoriesSubtitle: String { iaGuidedString("iaGuided.budget.categories.subtitle") }
        /// «En los últimos meses gastaste unos … al mes en esto.»
        static func budgetAmountAverage(_ a0: String) -> String { iaGuidedString("iaGuided.budget.amount.average", a0) }
        /// «Lo que sueles gastar»
        static var budgetAmountUsualHint: String { iaGuidedString("iaGuided.budget.amount.usualHint") }
        /// «Un 10 % menos, para ahorrar»
        static var budgetAmountSavingHint: String { iaGuidedString("iaGuided.budget.amount.savingHint") }
        /// «¿En qué moneda?»
        static var currencyQuestion: String { iaGuidedString("iaGuided.currency.question") }
        /// «¿Es alguno de estos?»
        static var paymentSuggestionQuestion: String { iaGuidedString("iaGuided.payment.suggestion.question") }
        /// «Se repiten en tus registros.»
        static var paymentSuggestionSubtitle: String { iaGuidedString("iaGuided.payment.suggestion.subtitle") }
        /// «Es otro pago»
        static var paymentSuggestionOther: String { iaGuidedString("iaGuided.payment.suggestion.other") }
        /// «¿Cómo se llama el pago?»
        static var paymentNameQuestion: String { iaGuidedString("iaGuided.payment.name.question") }
        /// «El servicio o quién te cobra. Por ejemplo, Luz o Alquiler.»
        static var paymentNameSubtitle: String { iaGuidedString("iaGuided.payment.name.subtitle") }
        /// «¿Cuánto pagas cada vez?»
        static var paymentAmountQuestion: String { iaGuidedString("iaGuided.payment.amount.question") }
        /// «¿Cada cuánto pagas?»
        static var paymentFrequencyQuestion: String { iaGuidedString("iaGuided.payment.frequency.question") }
        /// «¿Qué día del mes?»
        static var paymentWhenMonthly: String { iaGuidedString("iaGuided.payment.when.monthly") }
        /// «¿Qué día de la semana?»
        static var paymentWhenWeekly: String { iaGuidedString("iaGuided.payment.when.weekly") }
        /// «¿En qué fecha?»
        static var paymentWhenDate: String { iaGuidedString("iaGuided.payment.when.date") }
        /// «¿Con qué cuenta lo pagas?»
        static var paymentAccountQuestion: String { iaGuidedString("iaGuided.payment.account.question") }
        /// «¿En qué categoría va?»
        static var paymentSubcategoryQuestion: String { iaGuidedString("iaGuided.payment.subcategory.question") }
        /// «Revisa antes de crear»
        static var confirmQuestion: String { iaGuidedString("iaGuided.confirm.question") }
        /// «No se guarda nada hasta que toques el botón.»
        static var confirmSubtitle: String { iaGuidedString("iaGuided.confirm.subtitle") }
        /// «Lo dijiste tú»
        static var confirmYouSaidIt: String { iaGuidedString("iaGuided.confirm.youSaidIt") }
        /// «Crear presupuesto»
        static var confirmCreateBudget: String { iaGuidedString("iaGuided.confirm.createBudget") }
        /// «Crear pago»
        static var confirmCreatePayment: String { iaGuidedString("iaGuided.confirm.createPayment") }
        /// «Qué cuenta»
        static var rowCategories: String { iaGuidedString("iaGuided.row.categories") }
        /// «Cada cuánto»
        static var rowPeriod: String { iaGuidedString("iaGuided.row.period") }
        /// «Tope»
        static var rowLimit: String { iaGuidedString("iaGuided.row.limit") }
        /// «Monto»
        static var rowAmount: String { iaGuidedString("iaGuided.row.amount") }
        /// «Moneda»
        static var rowCurrency: String { iaGuidedString("iaGuided.row.currency") }
        /// «Nombre»
        static var rowName: String { iaGuidedString("iaGuided.row.name") }
        /// «Cuándo»
        static var rowWhen: String { iaGuidedString("iaGuided.row.when") }
        /// «Cuenta»
        static var rowAccount: String { iaGuidedString("iaGuided.row.account") }
        /// «Categoría»
        static var rowCategory: String { iaGuidedString("iaGuided.row.category") }
        /// «Ahora no»
        static var notNow: String { iaGuidedString("iaGuided.notNow") }
        /// «Lo dejamos aquí. No se creó nada.»
        static var cancelled: String { iaGuidedString("iaGuided.cancelled") }
        /// «¡Listo! Tu presupuesto está creado.»
        static var doneBudget: String { iaGuidedString("iaGuided.done.budget") }
        /// «¡Listo! Tu pago planificado está creado.»
        static var donePayment: String { iaGuidedString("iaGuided.done.payment") }
        /// «Ver presupuesto»
        static var doneSeeBudget: String { iaGuidedString("iaGuided.done.seeBudget") }
        /// «Ver pago»
        static var doneSeePayment: String { iaGuidedString("iaGuided.done.seePayment") }
        /// «Ya tienes todos los presupuestos activos que permite tu plan. Desactiva uno o pásate a Yala Pro.»
        static var planLimitReached: String { iaGuidedString("iaGuided.planLimitReached") }
        /// «Cambiar …»
        static func changeA11y(_ a0: String) -> String { iaGuidedString("iaGuided.change.a11y", a0) }

        // MARK: Mejoras del 16-nov: saludo, opciones avanzadas, una sola vez y cada N

        /// «Hola, soy Yala IA. Puedo ayudarte con esto:»
        static var greeting: String { iaGuidedString("iaGuided.greeting") }
        /// «Crea conversando»
        static var greetingCreateTitle: String { iaGuidedString("iaGuided.greeting.createTitle") }
        /// «Te pregunto paso a paso y nada se crea sin que lo revises.»
        static var greetingCreateSubtitle: String { iaGuidedString("iaGuided.greeting.createSubtitle") }
        /// «Un presupuesto»
        static var greetingCreateBudget: String { iaGuidedString("iaGuided.greeting.createBudget") }
        /// «Un pago planificado»
        static var greetingCreatePayment: String { iaGuidedString("iaGuided.greeting.createPayment") }
        /// «Quiero crear un presupuesto»
        static var shortcutBudgetMessage: String { iaGuidedString("iaGuided.shortcut.budgetMessage") }
        /// «Quiero crear un pago planificado»
        static var shortcutPaymentMessage: String { iaGuidedString("iaGuided.shortcut.paymentMessage") }
        /// «¿Quieres revisar las opciones avanzadas?»
        static var advancedQuestion: String { iaGuidedString("iaGuided.advanced.question") }
        /// «Puedes seguir sin eso: se crea con los valores de siempre.»
        static var advancedSubtitle: String { iaGuidedString("iaGuided.advanced.subtitle") }
        /// «Sí, revisarlas una a una»
        static var advancedYes: String { iaGuidedString("iaGuided.advanced.yes") }
        /// «No, seguir así»
        static var advancedNo: String { iaGuidedString("iaGuided.advanced.no") }
        /// «Saltar»
        static var skip: String { iaGuidedString("iaGuided.skip") }
        /// «¿Le pones otro nombre?»
        static var budgetNameQuestion: String { iaGuidedString("iaGuided.budget.name.question") }
        /// «Si no, se llama «%@».»
        static func budgetNameSubtitle(_ a0: String) -> String { iaGuidedString("iaGuided.budget.name.subtitle", a0) }
        /// «¿Solo cuenta los gastos de algunas cuentas?»
        static var budgetAccountsQuestion: String { iaGuidedString("iaGuided.budget.accounts.question") }
        /// «Si no eliges ninguna, cuenta todas.»
        static var budgetAccountsSubtitle: String { iaGuidedString("iaGuided.budget.accounts.subtitle") }
        /// «¿Solo cuenta los gastos con alguna etiqueta?»
        static var budgetTagsQuestion: String { iaGuidedString("iaGuided.budget.tags.question") }
        /// «Si no eliges ninguna, no se fija en las etiquetas.»
        static var budgetTagsSubtitle: String { iaGuidedString("iaGuided.budget.tags.subtitle") }
        /// «¿Cuenta tu parte de los gastos de grupo?»
        static var budgetSharedQuestion: String { iaGuidedString("iaGuided.budget.shared.question") }
        /// «Sí, mi parte cuenta»
        static var budgetSharedYes: String { iaGuidedString("iaGuided.budget.shared.yes") }
        /// «No, sin gastos de grupo»
        static var budgetSharedNo: String { iaGuidedString("iaGuided.budget.shared.no") }
        /// «¿Es una suscripción?»
        static var paymentSubscriptionQuestion: String { iaGuidedString("iaGuided.payment.subscription.question") }
        /// «Sí, es una suscripción»
        static var paymentSubscriptionYes: String { iaGuidedString("iaGuided.payment.subscription.yes") }
        /// «No, es otro pago»
        static var paymentSubscriptionNo: String { iaGuidedString("iaGuided.payment.subscription.no") }
        /// «¿Hasta cuándo se repite?»
        static var paymentEndQuestion: String { iaGuidedString("iaGuided.payment.end.question") }
        /// «Sin fecha de fin»
        static var paymentEndNever: String { iaGuidedString("iaGuided.payment.end.never") }
        /// «Hasta esta fecha»
        static var paymentEndUntil: String { iaGuidedString("iaGuided.payment.end.until") }
        /// «¿Quieres agregar una nota?»
        static var paymentNoteQuestion: String { iaGuidedString("iaGuided.payment.note.question") }
        /// «Por ejemplo, el número de contrato»
        static var paymentNotePlaceholder: String { iaGuidedString("iaGuided.payment.note.placeholder") }
        /// «¿Le pones etiquetas?»
        static var paymentTagsQuestion: String { iaGuidedString("iaGuided.payment.tags.question") }
        /// «Cada cierto tiempo»
        static var paymentEveryTitle: String { iaGuidedString("iaGuided.payment.every.title") }
        /// «Cada tantos días, semanas o meses»
        static var paymentEverySubtitle: String { iaGuidedString("iaGuided.payment.every.subtitle") }
        /// «Días»
        static var paymentEveryDays: String { iaGuidedString("iaGuided.payment.every.days") }
        /// «Semanas»
        static var paymentEveryWeeks: String { iaGuidedString("iaGuided.payment.every.weeks") }
        /// «Meses»
        static var paymentEveryMonths: String { iaGuidedString("iaGuided.payment.every.months") }
        /// «cada %d meses» (el rótulo del selector de «Cada cierto tiempo»)
        static func paymentEveryMonthsCount(_ a0: Int) -> String { iaGuidedString("iaGuided.payment.every.monthsCount", a0) }
        /// «Cada cuántos»
        static var paymentEveryCount: String { iaGuidedString("iaGuided.payment.every.count") }
        /// «¿Desde qué día?»
        static var paymentWhenStart: String { iaGuidedString("iaGuided.payment.when.start") }
        /// «Subcategorías»
        static var rowSubcategories: String { iaGuidedString("iaGuided.row.subcategories") }
        /// «Fechas»
        static var rowDates: String { iaGuidedString("iaGuided.row.dates") }
        /// «Opciones avanzadas»
        static var rowAdvanced: String { iaGuidedString("iaGuided.row.advanced") }
        /// «Avisos»
        static var rowAlerts: String { iaGuidedString("iaGuided.row.alerts") }
        /// «Cuentas»
        static var rowAccounts: String { iaGuidedString("iaGuided.row.accounts") }
        /// «Etiquetas»
        static var rowTags: String { iaGuidedString("iaGuided.row.tags") }
        /// «Gastos de grupo»
        static var rowShared: String { iaGuidedString("iaGuided.row.shared") }
        /// «En el Panel»
        static var rowPanel: String { iaGuidedString("iaGuided.row.panel") }
        /// «Suscripción»
        static var rowSubscription: String { iaGuidedString("iaGuided.row.subscription") }
        /// «Aviso»
        static var rowReminder: String { iaGuidedString("iaGuided.row.reminder") }
        /// «Hasta»
        static var rowEnd: String { iaGuidedString("iaGuided.row.end") }
        /// «Nota»
        static var rowNote: String { iaGuidedString("iaGuided.row.note") }
        /// «Todas»
        static var valueAll: String { iaGuidedString("iaGuided.value.all") }
        /// «Ninguna»
        static var valueNone: String { iaGuidedString("iaGuided.value.none") }
        /// «%1$d de %2$d»
        static func valueSomeOf(_ a0: Int, _ a1: Int) -> String { iaGuidedString("iaGuided.value.someOf", a0, a1) }
        /// «Las de siempre»
        static var valueDefaults: String { iaGuidedString("iaGuided.value.defaults") }
        /// «Revisadas»
        static var valueReviewed: String { iaGuidedString("iaGuided.value.reviewed") }
        /// «Sí»
        static var valueYes: String { iaGuidedString("iaGuided.value.yes") }
        /// «No»
        static var valueNo: String { iaGuidedString("iaGuided.value.no") }
        /// «Sin avisos»
        static var valueNoAlerts: String { iaGuidedString("iaGuided.value.noAlerts") }
        /// «Al 75 % y al 100 %»
        static var valueAlert75: String { iaGuidedString("iaGuided.value.alert75") }
        /// «Al llegar al tope»
        static var valueAlert100: String { iaGuidedString("iaGuided.value.alert100") }
        /// «3 días antes»
        static var valueReminder3: String { iaGuidedString("iaGuided.value.reminder3") }
        /// «1 día antes»
        static var valueReminder1: String { iaGuidedString("iaGuided.value.reminder1") }
        /// «El mismo día»
        static var valueReminderSame: String { iaGuidedString("iaGuided.value.reminderSame") }
        /// «Sin aviso»
        static var valueNoReminder: String { iaGuidedString("iaGuided.value.noReminder") }
        /// «Sin nota»
        static var valueNoNote: String { iaGuidedString("iaGuided.value.noNote") }
    }
}
