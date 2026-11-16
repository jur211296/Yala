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
    }
}
