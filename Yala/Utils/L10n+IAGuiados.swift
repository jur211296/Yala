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

        // MARK: - Cuenta, categoría y favorito

        /// «¿Qué cuenta quieres crear?»
        static var accountKindQuestion: String { iaGuidedString("iaGuided.account.kind.question") }
        /// «Elige la que más se parece.»
        static var accountKindSubtitle: String { iaGuidedString("iaGuided.account.kind.subtitle") }
        /// «¿Cuánto tienes hoy en cada moneda?»
        static var accountBalanceEach: String { iaGuidedString("iaGuided.account.balance.each") }
        /// «¿Cuánto debes hoy en cada moneda?»
        static var accountBalanceEachCard: String { iaGuidedString("iaGuided.account.balance.eachCard") }

        /// «Creemos tu cuenta. Solo te pregunto lo que falta.»
        static var accountIntro: String { iaGuidedString("iaGuided.account.intro") }
        /// «Armemos tu categoría. Solo te pregunto lo que falta.»
        static var categoryIntro: String { iaGuidedString("iaGuided.category.intro") }
        /// «Guardemos tu favorito. Solo te pregunto lo que falta.»
        static var favoriteIntro: String { iaGuidedString("iaGuided.favorite.intro") }
        /// «Nueva cuenta»
        static var accountHeader: String { iaGuidedString("iaGuided.account.header") }
        /// «Nueva categoría»
        static var categoryHeader: String { iaGuidedString("iaGuided.category.header") }
        /// «Nuevas subcategorías»
        static var subcategoriesHeader: String { iaGuidedString("iaGuided.subcategories.header") }
        /// «Nuevo favorito»
        static var favoriteHeader: String { iaGuidedString("iaGuided.favorite.header") }
        /// «Ya tienes el máximo de cuentas del plan gratis. Archiva una o pásate a Yala Pro para crear otra.»
        static var accountLimitReached: String { iaGuidedString("iaGuided.account.limitReached") }
        /// «Ya tienes una cuenta con ese nombre. Elige otro.»
        static var accountNameTaken: String { iaGuidedString("iaGuided.account.nameTaken") }
        /// «Ya tienes una categoría con ese nombre. Elige otro.»
        static var categoryNameTaken: String { iaGuidedString("iaGuided.category.nameTaken") }
        /// ««%@» ya está en esta categoría.»
        static func subcategoryTaken(_ a0: String) -> String { iaGuidedString("iaGuided.subcategory.taken", a0) }
        /// «¿Quieres anotar los últimos 4 números?»
        static var accountNumberQuestion: String { iaGuidedString("iaGuided.account.number.question") }
        /// «Te ayuda a reconocerla. Si no hace falta, tócale «Saltar».»
        static var accountNumberSubtitle: String { iaGuidedString("iaGuided.account.number.subtitle") }
        /// «¿Lo que pasa en esta cuenta cuenta en tus reportes?»
        static var accountStatsQuestion: String { iaGuidedString("iaGuided.account.stats.question") }
        /// «Sí, que cuente»
        static var accountStatsYes: String { iaGuidedString("iaGuided.account.stats.yes") }
        /// «No, déjala fuera de los reportes»
        static var accountStatsNo: String { iaGuidedString("iaGuided.account.stats.no") }
        /// «Crear cuenta»
        static var confirmCreateAccount: String { iaGuidedString("iaGuided.confirm.createAccount") }
        /// «Crear categoría»
        static var confirmCreateCategory: String { iaGuidedString("iaGuided.confirm.createCategory") }
        /// «Crear subcategorías»
        static var confirmCreateSubcategories: String { iaGuidedString("iaGuided.confirm.createSubcategories") }
        /// «Guardar favorito»
        static var confirmSaveFavorite: String { iaGuidedString("iaGuided.confirm.saveFavorite") }
        /// «Tipo»
        static var rowAccountType: String { iaGuidedString("iaGuided.row.accountType") }
        /// «Monedas»
        static var rowCurrencies: String { iaGuidedString("iaGuided.row.currencies") }
        /// «Saldo de hoy»
        static var rowBalance: String { iaGuidedString("iaGuided.row.balance") }
        /// «Cierra»
        static var rowStatementDay: String { iaGuidedString("iaGuided.row.statementDay") }
        /// «Se paga hasta»
        static var rowPaymentDay: String { iaGuidedString("iaGuided.row.paymentDay") }
        /// «Últimos números»
        static var rowNumber: String { iaGuidedString("iaGuided.row.number") }
        /// «En tus reportes»
        static var rowReports: String { iaGuidedString("iaGuided.row.reports") }
        /// «Qué creas»
        static var rowCreate: String { iaGuidedString("iaGuided.row.create") }
        /// «Ícono y color»
        static var rowIcon: String { iaGuidedString("iaGuided.row.icon") }
        /// «Necesidad»
        static var rowNeeds: String { iaGuidedString("iaGuided.row.needs") }
        /// «Qué es»
        static var rowType: String { iaGuidedString("iaGuided.row.type") }
        /// «A la cuenta»
        static var rowDestination: String { iaGuidedString("iaGuided.row.destination") }
        /// «No lo sé»
        static var valueDontKnow: String { iaGuidedString("iaGuided.value.dontKnow") }
        /// «El %d»
        static func valueDay(_ a0: Int) -> String { iaGuidedString("iaGuided.value.day", a0) }
        /// «Sin número»
        static var valueNoNumber: String { iaGuidedString("iaGuided.value.noNumber") }
        /// «Una categoría nueva»
        static var valueNewCategory: String { iaGuidedString("iaGuided.value.newCategory") }
        /// «Subcategorías en «%@»»
        static func valueSubcategoriesIn(_ a0: String) -> String { iaGuidedString("iaGuided.value.subcategoriesIn", a0) }
        /// «Sin clasificar»
        static var valueUnclassified: String { iaGuidedString("iaGuided.value.unclassified") }
        /// «Cambia cada vez»
        static var valueVariable: String { iaGuidedString("iaGuided.value.variable") }
        /// «¿Qué quieres crear?»
        static var categoryModeQuestion: String { iaGuidedString("iaGuided.category.mode.question") }
        /// «Una categoría nueva»
        static var categoryModeNew: String { iaGuidedString("iaGuided.category.mode.new") }
        /// «Con sus propias subcategorías»
        static var categoryModeNewHint: String { iaGuidedString("iaGuided.category.mode.newHint") }
        /// «Subcategorías en una que ya tienes»
        static var categoryModeSub: String { iaGuidedString("iaGuided.category.mode.sub") }
        /// «Por ejemplo, «Veterinario» dentro de «Mascotas»»
        static var categoryModeSubHint: String { iaGuidedString("iaGuided.category.mode.subHint") }
        /// «¿En qué categoría van?»
        static var categoryParentQuestion: String { iaGuidedString("iaGuided.category.parent.question") }
        /// «¿Cómo se llama la categoría?»
        static var categoryNameQuestion: String { iaGuidedString("iaGuided.category.name.question") }
        /// «Un nombre corto, como «Mascotas» o «Viajes».»
        static var categoryNameSubtitle: String { iaGuidedString("iaGuided.category.name.subtitle") }
        /// «Mascotas»
        static var categoryNamePlaceholder: String { iaGuidedString("iaGuided.category.name.placeholder") }
        /// «¿Con qué ícono y color la reconoces?»
        static var categoryLookQuestion: String { iaGuidedString("iaGuided.category.look.question") }
        /// «Te propongo uno por el nombre. Toca otro si prefieres.»
        static var categoryLookSubtitle: String { iaGuidedString("iaGuided.category.look.subtitle") }
        /// «Otro ícono o color»
        static var categoryLookOther: String { iaGuidedString("iaGuided.category.look.other") }
        /// «¿Qué entra en «%@»?»
        static func categorySubcategoriesQuestion(_ a0: String) -> String { iaGuidedString("iaGuided.category.subcategories.question", a0) }
        /// «Escribe al menos una y tócale «+». Así tus gastos quedan ordenados.»
        static var categorySubcategoriesSubtitle: String { iaGuidedString("iaGuided.category.subcategories.subtitle") }
        /// «Veterinario»
        static var subcategoryPlaceholder: String { iaGuidedString("iaGuided.subcategory.placeholder") }
        /// «Añadir subcategoría»
        static var subcategoryAdd: String { iaGuidedString("iaGuided.subcategory.add") }
        /// «Quitar %@»
        static func subcategoryRemove(_ a0: String) -> String { iaGuidedString("iaGuided.subcategory.remove", a0) }
        /// «¿Qué tan necesario es cada uno?»
        static var categoryNeedsQuestion: String { iaGuidedString("iaGuided.category.needs.question") }
        /// «Así Yala te dice cuánto va a lo esencial. Lo que no toques queda sin clasificar.»
        static var categoryNeedsSubtitle: String { iaGuidedString("iaGuided.category.needs.subtitle") }
        /// «¿Qué registras seguido?»
        static var favoriteTypeQuestion: String { iaGuidedString("iaGuided.favorite.type.question") }
        /// «Un gasto»
        static var favoriteTypeExpense: String { iaGuidedString("iaGuided.favorite.type.expense") }
        /// «Como el café de la mañana»
        static var favoriteTypeExpenseHint: String { iaGuidedString("iaGuided.favorite.type.expenseHint") }
        /// «Un ingreso»
        static var favoriteTypeIncome: String { iaGuidedString("iaGuided.favorite.type.income") }
        /// «Como tu sueldo»
        static var favoriteTypeIncomeHint: String { iaGuidedString("iaGuided.favorite.type.incomeHint") }
        /// «Una transferencia»
        static var favoriteTypeTransfer: String { iaGuidedString("iaGuided.favorite.type.transfer") }
        /// «Entre tus cuentas, como pasar a tus ahorros»
        static var favoriteTypeTransferHint: String { iaGuidedString("iaGuided.favorite.type.transferHint") }
        /// «¿De qué es?»
        static var favoriteSubcategoryQuestion: String { iaGuidedString("iaGuided.favorite.subcategory.question") }
        /// «Tus más usadas primero. ¿No está? Busca otra.»
        static var favoriteSubcategorySubtitle: String { iaGuidedString("iaGuided.favorite.subcategory.subtitle") }
        /// «¿Con qué lo pagas casi siempre?»
        static var favoriteAccountQuestion: String { iaGuidedString("iaGuided.favorite.account.question") }
        /// «¿A qué cuenta entra?»
        static var favoriteAccountIncomeQuestion: String { iaGuidedString("iaGuided.favorite.account.incomeQuestion") }
        /// «¿Desde qué cuenta?»
        static var favoriteAccountFromQuestion: String { iaGuidedString("iaGuided.favorite.account.fromQuestion") }
        /// «¿A qué cuenta va?»
        static var favoriteDestinationQuestion: String { iaGuidedString("iaGuided.favorite.destination.question") }
        /// «¿Es siempre el mismo monto?»
        static var favoriteAmountQuestion: String { iaGuidedString("iaGuided.favorite.amount.question") }
        /// «Lo escribes al usarlo»
        static var favoriteAmountVariableHint: String { iaGuidedString("iaGuided.favorite.amount.variableHint") }
        /// «¿Cómo lo llamamos?»
        static var favoriteNameQuestion: String { iaGuidedString("iaGuided.favorite.name.question") }
        /// «Es lo que verás al tocarlo en Favoritos.»
        static var favoriteNameSubtitle: String { iaGuidedString("iaGuided.favorite.name.subtitle") }
        /// «¿Qué tan necesario es este gasto?»
        static var favoriteNeedQuestion: String { iaGuidedString("iaGuided.favorite.need.question") }
        /// «¿Le pones alguna etiqueta?»
        static var favoriteTagsQuestion: String { iaGuidedString("iaGuided.favorite.tags.question") }
        /// «¿Quieres que lleve una nota?»
        static var favoriteNoteQuestion: String { iaGuidedString("iaGuided.favorite.note.question") }
        /// «Tu cuenta está lista»
        static var doneAccount: String { iaGuidedString("iaGuided.done.account") }
        /// «Tu categoría está lista»
        static var doneCategory: String { iaGuidedString("iaGuided.done.category") }
        /// «Tus subcategorías están listas»
        static var doneSubcategories: String { iaGuidedString("iaGuided.done.subcategories") }
        /// «Tu favorito está guardado»
        static var doneFavorite: String { iaGuidedString("iaGuided.done.favorite") }
        /// ««%@» ya está en tu Panel.»
        static func doneAccountMessage(_ a0: String) -> String { iaGuidedString("iaGuided.done.accountMessage", a0) }
        /// «Ya puedes usar «%@» al registrar.»
        static func doneCategoryMessage(_ a0: String) -> String { iaGuidedString("iaGuided.done.categoryMessage", a0) }
        /// «Tócalo en Favoritos para registrarlo en un toque.»
        static var doneFavoriteMessage: String { iaGuidedString("iaGuided.done.favoriteMessage") }
        /// «Ver la cuenta»
        static var doneSeeAccount: String { iaGuidedString("iaGuided.done.seeAccount") }
        /// «Ver tus categorías»
        static var doneSeeCategories: String { iaGuidedString("iaGuided.done.seeCategories") }
        /// «Ver tus favoritos»
        static var doneSeeFavorites: String { iaGuidedString("iaGuided.done.seeFavorites") }
        /// «Listo»
        static var closeSheet: String { iaGuidedString("iaGuided.close") }
    }
}
