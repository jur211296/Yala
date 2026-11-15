//
//  L10n+PrimerosPasos23Planning.swift
//  Yala
//
//  Textos de Primeros pasos 2.3, pasos 3, 4 y 5 (Y23-11 presupuesto, Y23-12 pagos planificados y Y23-13 grupos;
//  docs/onboarding-2-3/SPEC.md). Los exactos de la ficha y del prototipo oficial v35. En su propio fichero para no pisar
//  los de otros lotes de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su fichero.
private func pp23p(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

private func pp23p(_ key: String, _ args: CVarArg...) -> String {
    String(format: pp23p(key), arguments: args)
}

extension L10n.PrimerosPasos23 {
    enum Plan {
        static var seePanel: String { pp23p("pasos23.plan.seePanel") }
        static var done: String { pp23p("pasos23.plan.done") }
        static var panelQuestion: String { pp23p("pasos23.plan.panel.question") }
        static var panelYes: String { pp23p("pasos23.plan.panel.yes") }
        static var panelNo: String { pp23p("pasos23.plan.panel.no") }
        static var noThanks: String { pp23p("pasos23.plan.noThanks") }
        static var youHaveLeft: String { pp23p("pasos23.plan.youHaveLeft") }
        static var youWentOver: String { pp23p("pasos23.plan.youWentOver") }
        static func spentOfLimit(_ a0: String, _ a1: String) -> String { pp23p("pasos23.plan.spentOfLimit", a0, a1) }
    }
    enum Budget {
        static var chatSubtitle: String { pp23p("pasos23.budget.chatSubtitle") }
        static var introCta: String { pp23p("pasos23.budget.intro.cta") }
        static var introPart1Title: String { pp23p("pasos23.budget.intro.part1.title") }
        static func introPart1Message(_ a0: String) -> String { pp23p("pasos23.budget.intro.part1.message", a0) }
        static var introPart1Card: String { pp23p("pasos23.budget.intro.part1.card") }
        static var introPart2Title: String { pp23p("pasos23.budget.intro.part2.title") }
        static var introPart2Message: String { pp23p("pasos23.budget.intro.part2.message") }
        static var introPart3Title: String { pp23p("pasos23.budget.intro.part3.title") }
        static var introPart3Message: String { pp23p("pasos23.budget.intro.part3.message") }
        static func introPart3Push(_ a0: String, _ a1: String) -> String { pp23p("pasos23.budget.intro.part3.push", a0, a1) }
        static var introPart3Card: String { pp23p("pasos23.budget.intro.part3.card") }
        static var scopeQuestion: String { pp23p("pasos23.budget.scope.question") }
        static var scopeSubtitle: String { pp23p("pasos23.budget.scope.subtitle") }
        static var scopeAll: String { pp23p("pasos23.budget.scope.all") }
        static var scopeAllHint: String { pp23p("pasos23.budget.scope.allHint") }
        static var scopeCategories: String { pp23p("pasos23.budget.scope.categories") }
        static var scopeCategoriesHint: String { pp23p("pasos23.budget.scope.categoriesHint") }
        static var categoriesQuestion: String { pp23p("pasos23.budget.categories.question") }
        static var categoriesSubtitle: String { pp23p("pasos23.budget.categories.subtitle") }
        static func categoriesSpent(_ a0: String) -> String { pp23p("pasos23.budget.categories.spent", a0) }
        static var subcategoriesQuestion: String { pp23p("pasos23.budget.subcategories.question") }
        static var subcategoriesSubtitle: String { pp23p("pasos23.budget.subcategories.subtitle") }
        static var periodQuestion: String { pp23p("pasos23.budget.period.question") }
        static var periodSubtitle: String { pp23p("pasos23.budget.period.subtitle") }
        static var periodOnce: String { pp23p("pasos23.budget.period.once") }
        static var periodMonthlyHint: String { pp23p("pasos23.budget.period.monthlyHint") }
        static var periodWeeklyHint: String { pp23p("pasos23.budget.period.weeklyHint") }
        static var periodYearlyHint: String { pp23p("pasos23.budget.period.yearlyHint") }
        static var periodOnceHint: String { pp23p("pasos23.budget.period.onceHint") }
        static var datesQuestion: String { pp23p("pasos23.budget.dates.question") }
        static var datesSubtitle: String { pp23p("pasos23.budget.dates.subtitle") }
        static var datesFrom: String { pp23p("pasos23.budget.dates.from") }
        static var datesTo: String { pp23p("pasos23.budget.dates.to") }
        static var limitQuestionMonthly: String { pp23p("pasos23.budget.limit.question.monthly") }
        static var limitQuestionWeekly: String { pp23p("pasos23.budget.limit.question.weekly") }
        static var limitQuestionYearly: String { pp23p("pasos23.budget.limit.question.yearly") }
        static var limitQuestionOnce: String { pp23p("pasos23.budget.limit.question.once") }
        static func limitSpentSoFar(_ a0: String) -> String { pp23p("pasos23.budget.limit.spentSoFar", a0) }
        static var limitRoundNumber: String { pp23p("pasos23.budget.limit.roundNumber") }
        static func nameQuestion(_ a0: String) -> String { pp23p("pasos23.budget.name.question", a0) }
        static var nameSubtitle: String { pp23p("pasos23.budget.name.subtitle") }
        static var nameYes: String { pp23p("pasos23.budget.name.yes") }
        static var nameOther: String { pp23p("pasos23.budget.name.other") }
        static var nameEditQuestion: String { pp23p("pasos23.budget.name.editQuestion") }
        static var namePlaceholder: String { pp23p("pasos23.budget.name.placeholder") }
        static var nameAllExpenses: String { pp23p("pasos23.budget.name.allExpenses") }
        static func nameJoined(_ a0: String, _ a1: String) -> String { pp23p("pasos23.budget.name.joined", a0, a1) }
        static var nameFallback: String { pp23p("pasos23.budget.name.fallback") }
        static var cardPlaceholder: String { pp23p("pasos23.budget.card.placeholder") }
        static var cardCountsAll: String { pp23p("pasos23.budget.card.countsAll") }
        static var cardPickCategories: String { pp23p("pasos23.budget.card.pickCategories") }
        static var cardAlert75: String { pp23p("pasos23.budget.card.alert75") }
        static var cardAlert100: String { pp23p("pasos23.budget.card.alert100") }
        static var alertQuestion: String { pp23p("pasos23.budget.alert.question") }
        static var alertSubtitle: String { pp23p("pasos23.budget.alert.subtitle") }
        static var alertAt75: String { pp23p("pasos23.budget.alert.at75") }
        static var alertAt75Hint: String { pp23p("pasos23.budget.alert.at75Hint") }
        static var alertAt100: String { pp23p("pasos23.budget.alert.at100") }
        static var panelSubtitle: String { pp23p("pasos23.budget.panel.subtitle") }
        static var panelYesHint: String { pp23p("pasos23.budget.panel.yesHint") }
        static func doneMessage(_ a0: String) -> String { pp23p("pasos23.budget.done.message", a0) }
        static func doneMessagePanel(_ a0: String) -> String { pp23p("pasos23.budget.done.messagePanel", a0) }
    }
    enum Payment {
        static var chatSubtitle: String { pp23p("pasos23.payment.chatSubtitle") }
        static var introCta: String { pp23p("pasos23.payment.intro.cta") }
        static var introPart1Title: String { pp23p("pasos23.payment.intro.part1.title") }
        static var introPart1Message: String { pp23p("pasos23.payment.intro.part1.message") }
        static var introPart1Caption: String { pp23p("pasos23.payment.intro.part1.caption") }
        static var introPart2Title: String { pp23p("pasos23.payment.intro.part2.title") }
        static var introPart2Message: String { pp23p("pasos23.payment.intro.part2.message") }
        static var introPart3Title: String { pp23p("pasos23.payment.intro.part3.title") }
        static var introPart3Message: String { pp23p("pasos23.payment.intro.part3.message") }
        static var exampleMusic: String { pp23p("pasos23.payment.example.music") }
        static var exampleLight: String { pp23p("pasos23.payment.example.light") }
        static var exampleRent: String { pp23p("pasos23.payment.example.rent") }
        static var inboxLater: String { pp23p("pasos23.payment.inbox.later") }
        static var kindQuestion: String { pp23p("pasos23.payment.kind.question") }
        static var kindSubtitle: String { pp23p("pasos23.payment.kind.subtitle") }
        static var kindRent: String { pp23p("pasos23.payment.kind.rent") }
        static var kindUtilities: String { pp23p("pasos23.payment.kind.utilities") }
        static var kindPhone: String { pp23p("pasos23.payment.kind.phone") }
        static var kindUtilitySubscription: String { pp23p("pasos23.payment.kind.utilitySubscription") }
        static var kindLeisureSubscription: String { pp23p("pasos23.payment.kind.leisureSubscription") }
        static var kindFitness: String { pp23p("pasos23.payment.kind.fitness") }
        static var nameRent: String { pp23p("pasos23.payment.name.rent") }
        static var nameUtilities: String { pp23p("pasos23.payment.name.utilities") }
        static var namePhone: String { pp23p("pasos23.payment.name.phone") }
        static var nameSubscription: String { pp23p("pasos23.payment.name.subscription") }
        static var nameFitness: String { pp23p("pasos23.payment.name.fitness") }
        static var exampleRent1: String { pp23p("pasos23.payment.example.rent.1") }
        static var exampleRent2: String { pp23p("pasos23.payment.example.rent.2") }
        static var exampleRent3: String { pp23p("pasos23.payment.example.rent.3") }
        static var exampleUtilities1: String { pp23p("pasos23.payment.example.utilities.1") }
        static var exampleUtilities2: String { pp23p("pasos23.payment.example.utilities.2") }
        static var exampleUtilities3: String { pp23p("pasos23.payment.example.utilities.3") }
        static var examplePhone1: String { pp23p("pasos23.payment.example.phone.1") }
        static var examplePhone2: String { pp23p("pasos23.payment.example.phone.2") }
        static var examplePhone3: String { pp23p("pasos23.payment.example.phone.3") }
        static var exampleUtilitySubscription1: String { pp23p("pasos23.payment.example.utilitySubscription.1") }
        static var exampleUtilitySubscription2: String { pp23p("pasos23.payment.example.utilitySubscription.2") }
        static var exampleUtilitySubscription3: String { pp23p("pasos23.payment.example.utilitySubscription.3") }
        static var exampleLeisureSubscription1: String { pp23p("pasos23.payment.example.leisureSubscription.1") }
        static var exampleLeisureSubscription2: String { pp23p("pasos23.payment.example.leisureSubscription.2") }
        static var exampleLeisureSubscription3: String { pp23p("pasos23.payment.example.leisureSubscription.3") }
        static var exampleFitness1: String { pp23p("pasos23.payment.example.fitness.1") }
        static var exampleFitness2: String { pp23p("pasos23.payment.example.fitness.2") }
        static var exampleFitness3: String { pp23p("pasos23.payment.example.fitness.3") }
        static var otherSubcategory: String { pp23p("pasos23.payment.otherSubcategory") }
        static var change: String { pp23p("pasos23.payment.change") }
        static var isSubscription: String { pp23p("pasos23.payment.isSubscription") }
        static var isSubscriptionHint: String { pp23p("pasos23.payment.isSubscriptionHint") }
        static var detailsQuestion: String { pp23p("pasos23.payment.details.question") }
        static func detailsSubtitle(_ a0: String, _ a1: String) -> String { pp23p("pasos23.payment.details.subtitle", a0, a1) }
        static var detailsName: String { pp23p("pasos23.payment.details.name") }
        static var detailsNamePlaceholder: String { pp23p("pasos23.payment.details.namePlaceholder") }
        static var detailsClearName: String { pp23p("pasos23.payment.details.clearName") }
        static var detailsAmount: String { pp23p("pasos23.payment.details.amount") }
        static var detailsVariable: String { pp23p("pasos23.payment.details.variable") }
        static var detailsVariableHint: String { pp23p("pasos23.payment.details.variableHint") }
        static var whenQuestion: String { pp23p("pasos23.payment.when.question") }
        static var whenMonthly: String { pp23p("pasos23.payment.when.monthly") }
        static var whenWeekly: String { pp23p("pasos23.payment.when.weekly") }
        static var whenYearly: String { pp23p("pasos23.payment.when.yearly") }
        static var whenOnce: String { pp23p("pasos23.payment.when.once") }
        static var whenDayOfMonth: String { pp23p("pasos23.payment.when.dayOfMonth") }
        static var whenOtherDay: String { pp23p("pasos23.payment.when.otherDay") }
        static var whenWeekday: String { pp23p("pasos23.payment.when.weekday") }
        static var whenDate: String { pp23p("pasos23.payment.when.date") }
        static var reminderQuestion: String { pp23p("pasos23.payment.reminder.question") }
        static var reminderSubtitle: String { pp23p("pasos23.payment.reminder.subtitle") }
        static var reminderThreeDays: String { pp23p("pasos23.payment.reminder.threeDays") }
        static var reminderOneDay: String { pp23p("pasos23.payment.reminder.oneDay") }
        static var reminderSameDay: String { pp23p("pasos23.payment.reminder.sameDay") }
        static var panelSubtitle: String { pp23p("pasos23.payment.panel.subtitle") }
        static var panelYesHint: String { pp23p("pasos23.payment.panel.yesHint") }
        static func doneMessage(_ a0: String) -> String { pp23p("pasos23.payment.done.message", a0) }
        static var doneAnother: String { pp23p("pasos23.payment.done.another") }
        static var cardPlaceholder: String { pp23p("pasos23.payment.card.placeholder") }
    }
    enum Groups {
        static func eyebrow(_ a0: Int, _ a1: Int) -> String { pp23p("pasos23.groups.eyebrow", a0, a1) }
        static var chatSubtitle: String { pp23p("pasos23.groups.chatSubtitle") }
        static var whatQuestion: String { pp23p("pasos23.groups.what.question") }
        static var whatSubtitle: String { pp23p("pasos23.groups.what.subtitle") }
        static var whatCreate: String { pp23p("pasos23.groups.what.create") }
        static var whatCreateHint: String { pp23p("pasos23.groups.what.createHint") }
        static var whatLink: String { pp23p("pasos23.groups.what.link") }
        static var whatLinkHint: String { pp23p("pasos23.groups.what.linkHint") }
        static var alreadySeen: String { pp23p("pasos23.groups.alreadySeen") }
    }
}
