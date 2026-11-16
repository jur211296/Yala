//
//  L10n+PrimerosPasos23.swift
//  Yala
//
//  Textos de Primeros pasos 2.3, pasos 1 y 2 (Y23-07 a Y23-10, docs/onboarding-2-3/SPEC.md). Los exactos de la ficha y
//  del prototipo oficial v35. En su propio fichero para no pisar `L10n.swift` con otros lotes de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su fichero.
private func pp23(_ key: String) -> String {
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

private func pp23(_ key: String, _ args: CVarArg...) -> String {
    String(format: pp23(key), arguments: args)
}

extension L10n {
    enum PrimerosPasos23 {
        /// «Parte 2 de 3» (VoiceOver, segmentos de las páginas cortas y avance de las preguntas).
        static func partOf(_ index: Int, _ total: Int) -> String { pp23("pasos23.partOf", index, total) }

        // MARK: - Paso 1 · Crear la primera cuenta (Y23-07)

        enum Account {
            static var introEyebrow: String { pp23("pasos23.account.intro.eyebrow") }
            static var createFirst: String { pp23("pasos23.account.intro.createFirst") }
            static var introPart1Title: String { pp23("pasos23.account.intro.part1.title") }
            static var introPart1Message: String { pp23("pasos23.account.intro.part1.message") }
            static var introPart2Title: String { pp23("pasos23.account.intro.part2.title") }
            static func introPart2Message(_ main: String, _ second: String) -> String {
                pp23("pasos23.account.intro.part2.message", main, second)
            }
            static var introPart3Title: String { pp23("pasos23.account.intro.part3.title") }
            static var introPart3Message: String { pp23("pasos23.account.intro.part3.message") }
            static var placeWallet: String { pp23("pasos23.account.place.wallet") }
            static var placePaid: String { pp23("pasos23.account.place.paid") }
            static var placeSaved: String { pp23("pasos23.account.place.saved") }
            static var placeOwe: String { pp23("pasos23.account.place.owe") }
            static var placeBank: String { pp23("pasos23.account.place.bank") }
            static var placeCard: String { pp23("pasos23.account.place.card") }
            static var rowCashCaption: String { pp23("pasos23.account.row.cash") }
            static var rowSavingsCaption: String { pp23("pasos23.account.row.savings") }
            static var rowCardCaption: String { pp23("pasos23.account.row.card") }
            static var yalaSays: String { pp23("pasos23.account.match.yala") }
            static var bankSays: String { pp23("pasos23.account.match.bank") }
            static var benefitSpend: String { pp23("pasos23.account.benefit.spend") }
            static var benefitReports: String { pp23("pasos23.account.benefit.reports") }
            static var benefitAdjust: String { pp23("pasos23.account.benefit.adjust") }

            static var chatSubtitle: String { pp23("pasos23.account.chat.subtitle") }
            static var kindQuestion: String { pp23("pasos23.account.kind.question") }
            static var kindSubtitle: String { pp23("pasos23.account.kind.subtitle") }
            static var kindSavings: String { pp23("pasos23.account.kind.savings") }
            static var kindAllTogether: String { pp23("pasos23.account.kind.allTogether") }
            static var kindAllTogetherHint: String { pp23("pasos23.account.kind.allTogetherHint") }

            static var currencyQuestion: String { pp23("pasos23.account.currency.question") }
            static var currencyQuestionCard: String { pp23("pasos23.account.currency.questionCard") }
            static var currencySubtitle: String { pp23("pasos23.account.currency.subtitle") }
            static var currencySubtitleCard: String { pp23("pasos23.account.currency.subtitleCard") }
            static var addCurrency: String { pp23("pasos23.account.currency.add") }
            static var continueButton: String { pp23("pasos23.account.continue") }
            static func currencySlot(_ index: Int, _ name: String) -> String {
                pp23("pasos23.account.currency.slot", index, name)
            }
            static func removeCurrency(_ name: String) -> String { pp23("pasos23.account.currency.remove", name) }

            static var myMoney: String { pp23("pasos23.account.name.myMoney") }
            static var nameQuestion: String { pp23("pasos23.account.name.question") }
            static var nameSubtitleOwn: String { pp23("pasos23.account.name.subtitleOwn") }
            static func nameSuggestQuestion(_ name: String) -> String { pp23("pasos23.account.name.suggest", name) }
            static var nameSubtitle: String { pp23("pasos23.account.name.subtitle") }
            static var nameEditQuestion: String { pp23("pasos23.account.name.editQuestion") }
            static var namePlaceholder: String { pp23("pasos23.account.name.placeholder") }
            static func nameExample(_ example: String) -> String { pp23("pasos23.account.name.example", example) }
            static var nameKeep: String { pp23("pasos23.account.name.keep") }
            static var nameChange: String { pp23("pasos23.account.name.change") }
            static var exampleChecking: String { pp23("pasos23.account.example.checking") }
            static var exampleSavings: String { pp23("pasos23.account.example.savings") }
            static var exampleCard: String { pp23("pasos23.account.example.card") }

            static var balanceQuestionSingle: String { pp23("pasos23.account.balance.single") }
            static var balanceQuestionCardSingle: String { pp23("pasos23.account.balance.cardSingle") }
            static func balanceQuestionIn(_ word: String) -> String { pp23("pasos23.account.balance.in", word) }
            static func balanceQuestionCardIn(_ word: String) -> String { pp23("pasos23.account.balance.cardIn", word) }
            static func balanceQuestionAnd(_ word: String) -> String { pp23("pasos23.account.balance.and", word) }
            static var balanceSubtitle: String { pp23("pasos23.account.balance.subtitle") }
            static var balanceSubtitleCard: String { pp23("pasos23.account.balance.subtitleCard") }
            static var balanceFieldLabel: String { pp23("pasos23.account.balance.field") }
            static var helpMe: String { pp23("pasos23.account.balance.helpMe") }
            static var startAtZero: String { pp23("pasos23.account.balance.startAtZero") }
            static var oweNothing: String { pp23("pasos23.account.balance.oweNothing") }
            static func noneIn(_ word: String) -> String { pp23("pasos23.account.balance.noneIn", word) }
            static func oweNothingIn(_ word: String) -> String { pp23("pasos23.account.balance.oweNothingIn", word) }
            static var signPositive: String { pp23("pasos23.account.balance.signPositive") }
            static var signNegative: String { pp23("pasos23.account.balance.signNegative") }
            static var send: String { pp23("pasos23.account.send") }

            static var helperCardTitle: String { pp23("pasos23.account.helper.card.title") }
            static var helperCardIntro: String { pp23("pasos23.account.helper.card.intro") }
            static var helperLimit: String { pp23("pasos23.account.helper.limit") }
            static var helperLimitHint: String { pp23("pasos23.account.helper.limitHint") }
            static var helperRemaining: String { pp23("pasos23.account.helper.remaining") }
            static var helperRemainingHint: String { pp23("pasos23.account.helper.remainingHint") }
            static var helperUsed: String { pp23("pasos23.account.helper.used") }
            static var helperLeft: String { pp23("pasos23.account.helper.left") }
            static var helperGeneralTitle: String { pp23("pasos23.account.helper.general.title") }
            static var helperGeneralIntro: String { pp23("pasos23.account.helper.general.intro") }
            static var helperInBank: String { pp23("pasos23.account.helper.inBank") }
            static var helperSaved: String { pp23("pasos23.account.helper.saved") }
            static var helperInCash: String { pp23("pasos23.account.helper.inCash") }
            static var helperCashTitle: String { pp23("pasos23.account.helper.cash.title") }
            static var helperCashIntro: String { pp23("pasos23.account.helper.cash.intro") }
            static var helperCashRow: String { pp23("pasos23.account.helper.cash.row") }
            static var helperCheckingTitle: String { pp23("pasos23.account.helper.checking.title") }
            static var helperCheckingIntro: String { pp23("pasos23.account.helper.checking.intro") }
            static var helperCheckingRow: String { pp23("pasos23.account.helper.checking.row") }
            static var helperSavingsTitle: String { pp23("pasos23.account.helper.savings.title") }
            static var helperSavingsIntro: String { pp23("pasos23.account.helper.savings.intro") }
            static var helperSavingsRow: String { pp23("pasos23.account.helper.savings.row") }
            static var helperResultOwe: String { pp23("pasos23.account.helper.resultOwe") }
            static var helperResultHave: String { pp23("pasos23.account.helper.resultHave") }
            static func useAmount(_ amount: String) -> String { pp23("pasos23.account.helper.use", amount) }
            static var useThisBalance: String { pp23("pasos23.account.helper.useThis") }
            static var helperFootnote: String { pp23("pasos23.account.helper.footnote") }

            static var statementQuestion: String { pp23("pasos23.account.statement.question") }
            static var statementSubtitle: String { pp23("pasos23.account.statement.subtitle") }
            static var paymentQuestion: String { pp23("pasos23.account.payment.question") }
            static var paymentSubtitle: String { pp23("pasos23.account.payment.subtitle") }
            static var dayPrefix: String { pp23("pasos23.account.day.prefix") }
            static var dayPlaceholder: String { pp23("pasos23.account.day.placeholder") }
            static var dayFieldLabel: String { pp23("pasos23.account.day.field") }
            static var dontKnow: String { pp23("pasos23.account.day.dontKnow") }
            static var preferNotToSay: String { pp23("pasos23.account.day.preferNot") }

            static var reminderQuestion: String { pp23("pasos23.account.reminder.question") }
            static var reminderSubtitle: String { pp23("pasos23.account.reminder.subtitle") }
            static var reminderSubtitleEachCurrency: String { pp23("pasos23.account.reminder.subtitleEach") }
            static var reminderSubtitleNoStatement: String { pp23("pasos23.account.reminder.subtitleNoStatement") }
            static var noReminder: String { pp23("pasos23.account.reminder.none") }

            static var doneTitle: String { pp23("pasos23.account.done.title") }
            static func doneSubtitle(_ name: String) -> String { pp23("pasos23.account.done.subtitle", name) }
            static func doneSubtitleWith(_ name: String, _ currencies: String) -> String {
                pp23("pasos23.account.done.subtitleWith", name, currencies)
            }
            static var seeMyYala: String { pp23("pasos23.account.done.seeMyYala") }
            static var createAnother: String { pp23("pasos23.account.done.another") }

            static var cardPlaceholderName: String { pp23("pasos23.account.card.placeholderName") }
            static var cardPlaceholderType: String { pp23("pasos23.account.card.placeholderType") }
            static var cardBalance: String { pp23("pasos23.account.card.balance") }
            static var cardOwe: String { pp23("pasos23.account.card.owe") }
            static func cardBalanceIn(_ word: String) -> String { pp23("pasos23.account.card.balanceIn", word) }
            static func cardOweIn(_ word: String) -> String { pp23("pasos23.account.card.oweIn", word) }
            static func cardLine(_ word: String) -> String { pp23("pasos23.account.card.line", word) }
            static func cardClosesOn(_ day: Int) -> String { pp23("pasos23.account.card.closesOn", day) }
            static func cardPayBy(_ day: Int) -> String { pp23("pasos23.account.card.payBy", day) }
            static func cardReminds(_ when: String) -> String { pp23("pasos23.account.card.reminds", when) }
        }

        // MARK: - Paso 2 · Aprender a registrar (Y23-08 a Y23-10)

        enum Record {
            static var introEyebrow: String { pp23("pasos23.record.intro.eyebrow") }
            static var manualTitle: String { pp23("pasos23.record.manual.title") }
            static var manualMessage: String { pp23("pasos23.record.manual.message") }
            static var voiceTitle: String { pp23("pasos23.record.voice.title") }
            static var voiceMessage: String { pp23("pasos23.record.voice.message") }
            static var photoTitle: String { pp23("pasos23.record.photo.title") }
            static var photoMessage: String { pp23("pasos23.record.photo.message") }
            static var aiTitle: String { pp23("pasos23.record.ai.title") }
            static var aiMessage: String { pp23("pasos23.record.ai.message") }
            static var tryFreeOnce: String { pp23("pasos23.record.tryFreeOnce") }
            static var startManual: String { pp23("pasos23.record.startManual") }
            static var skipStep: String { pp23("pasos23.record.skipStep") }

            static var manualShort: String { pp23("pasos23.record.manual.short") }
            static var voiceShort: String { pp23("pasos23.record.voice.short") }
            static var photoShort: String { pp23("pasos23.record.photo.short") }
            static var firstRecord: String { pp23("pasos23.record.between.first") }
            static func records(_ count: Int) -> String {
                String.localizedStringWithFormat(pp23("pasos23.record.between.many"), count)
            }
            static var keepGoing: String { pp23("pasos23.record.between.keepGoing") }
            static var nowVoice: String { pp23("pasos23.record.now.voice") }
            static var nowPhoto: String { pp23("pasos23.record.now.photo") }
            static var nowAI: String { pp23("pasos23.record.now.ai") }
            static var nextVoice: String { pp23("pasos23.record.next.voice") }
            static var nextPhoto: String { pp23("pasos23.record.next.photo") }
            static var nextAI: String { pp23("pasos23.record.next.ai") }
            static var courtesyOnce: String { pp23("pasos23.record.courtesyOnce") }
            static var tryVoice: String { pp23("pasos23.record.try.voice") }
            static var tryPhoto: String { pp23("pasos23.record.try.photo") }
            static var tryAI: String { pp23("pasos23.record.try.ai") }
            static var skip: String { pp23("pasos23.record.skip") }
            static var goToPanel: String { pp23("pasos23.record.goToPanel") }
            static var stateDone: String { pp23("pasos23.record.state.done") }
            static var stateSkipped: String { pp23("pasos23.record.state.skipped") }
            static var stateNext: String { pp23("pasos23.record.state.next") }
            static var statePending: String { pp23("pasos23.record.state.pending") }
            static var inInbox: String { pp23("pasos23.record.inInbox") }

            static var trialVoice: String { pp23("pasos23.record.trial.voice") }
            static var trialPhoto: String { pp23("pasos23.record.trial.photo") }
            static var trialAI: String { pp23("pasos23.record.trial.ai") }
            static var useExampleReceipt: String { pp23("pasos23.record.exampleReceipt") }
            static var useExampleReceiptHint: String { pp23("pasos23.record.exampleReceiptHint") }
            static var aiGuideTitle: String { pp23("pasos23.record.aiGuide.title") }
            static var aiGuideMessage: String { pp23("pasos23.record.aiGuide.message") }

            static var guideAmountTitle: String { pp23("pasos23.record.guide.amount.title") }
            static var guideAmountMessage: String { pp23("pasos23.record.guide.amount.message") }
            static var guideCategoryTitle: String { pp23("pasos23.record.guide.category.title") }
            static var guideCategoryMessage: String { pp23("pasos23.record.guide.category.message") }
            static var guideAccountTitle: String { pp23("pasos23.record.guide.account.title") }
            static var guideAccountMessage: String { pp23("pasos23.record.guide.account.message") }
            static var guideNameTitle: String { pp23("pasos23.record.guide.name.title") }
            static var guideNameMessage: String { pp23("pasos23.record.guide.name.message") }
            static var guideNameWrite: String { pp23("pasos23.record.guide.name.write") }
            static var guideNameSkip: String { pp23("pasos23.record.guide.name.skip") }
            static var guideSaveTitle: String { pp23("pasos23.record.guide.save.title") }
            static var guideSaveMessage: String { pp23("pasos23.record.guide.save.message") }

            static var cleanupTitle: String { pp23("pasos23.record.cleanup.title") }
            static func cleanupMessage(_ count: Int) -> String {
                String.localizedStringWithFormat(pp23("pasos23.record.cleanup.message"), count)
            }
            static func cleanupDelete(_ count: Int) -> String {
                String.localizedStringWithFormat(pp23("pasos23.record.cleanup.delete"), count)
            }
            static var cleanupMarkSome: String { pp23("pasos23.record.cleanup.markSome") }
            static var cleanupKeepAll: String { pp23("pasos23.record.cleanup.keepAll") }
            static func cleanupDone(_ count: Int) -> String {
                String.localizedStringWithFormat(pp23("pasos23.record.cleanup.done"), count)
            }
            static var inboxGuideTitle: String { pp23("pasos23.record.inboxGuide.title") }
            static var inboxGuideMessage: String { pp23("pasos23.record.inboxGuide.message") }
        }
    }
}
