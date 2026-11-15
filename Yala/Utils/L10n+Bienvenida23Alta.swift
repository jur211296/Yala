//
//  L10n+Bienvenida23Alta.swift
//  Yala
//
//  Textos del lote 02 de la bienvenida 2.3 (`docs/onboarding-2-3/SPEC.md`, cards Y23-01 a Y23-04 y Y23-06): la vitrina
//  y sus accesos, la puerta de Grupos y la conversación de tres preguntas. En su propio fichero, como los de cada lote,
//  para no pisar `L10n.swift` con otras sesiones. Los nombres de sitio son los de la decisión 51 de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func b23(_ key: String) -> String {
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

extension L10n {
    /// Y23-01 y Y23-06 · la vitrina, sus accesos y la puerta de Grupos.
    enum Showcase {
        static var financesTitle: String { b23("bienvenida23.showcase.financesTitle") }
        static var financesTitleAccent: String { b23("bienvenida23.showcase.financesTitleAccent") }
        static var groupsTitle: String { b23("bienvenida23.showcase.groupsTitle") }
        static var groupsTitleAccent: String { b23("bienvenida23.showcase.groupsTitleAccent") }

        static var receiptName: String { b23("bienvenida23.showcase.receipt.name") }
        static var receiptCaption: String { b23("bienvenida23.showcase.receipt.caption") }
        static var voiceName: String { b23("bienvenida23.showcase.voice.name") }
        static var voiceCaption: String { b23("bienvenida23.showcase.voice.caption") }
        static var organizeName: String { b23("bienvenida23.showcase.organize.name") }
        static var organizeCaption: String { b23("bienvenida23.showcase.organize.caption") }
        static var splitName: String { b23("bienvenida23.showcase.split.name") }
        static var splitCaption: String { b23("bienvenida23.showcase.split.caption") }
        static var budgetName: String { b23("bienvenida23.showcase.budget.name") }
        static var budgetCaption: String { b23("bienvenida23.showcase.budget.caption") }
        static var whoOwesName: String { b23("bienvenida23.showcase.whoOwes.name") }
        static var whoOwesCaption: String { b23("bienvenida23.showcase.whoOwes.caption") }
        static var settleName: String { b23("bienvenida23.showcase.settle.name") }
        static var settleCaption: String { b23("bienvenida23.showcase.settle.caption") }

        /// El rótulo de los datos de ejemplo de cada demo.
        static var example: String { b23("bienvenida23.showcase.example") }
        static var groupsDoorLink: String { b23("bienvenida23.showcase.groupsDoorLink") }
        static var pause: String { b23("bienvenida23.showcase.pause") }
        static var resume: String { b23("bienvenida23.showcase.resume") }
        /// «Ordena tus gastos, 3 de 6»: la vitrina para VoiceOver.
        static func position(_ name: String, _ index: Int, _ count: Int) -> String {
            String(format: b23("bienvenida23.showcase.position"), name, index, count)
        }

        static var enterWithGoogle: String { b23("bienvenida23.access.google") }
        static var enterWithApple: String { b23("bienvenida23.access.apple") }
        static var enterWithICloud: String { b23("bienvenida23.access.iCloud") }
        static var iCloudLine: String { b23("bienvenida23.access.iCloudLine") }
        static var groupsNeedAccount: String { b23("bienvenida23.access.groupsNeedAccount") }
        /// Y23-06 · el tercer camino de Grupos.
        static var groupsAccountOnlyTitle: String { b23("bienvenida23.groups.accountOnlyTitle") }
        static var groupsAccountOnlyBody: String { b23("bienvenida23.groups.accountOnlyBody") }
        static var groupsSubtitleThree: String { b23("bienvenida23.groups.subtitleThree") }

        // Datos de ejemplo de las demos.
        static var demoLunch: String { b23("bienvenida23.demo.lunch") }
        static var demoTaxi: String { b23("bienvenida23.demo.taxi") }
        static var demoMarket: String { b23("bienvenida23.demo.market") }
        static var demoPower: String { b23("bienvenida23.demo.power") }
        static var demoDinner: String { b23("bienvenida23.demo.dinner") }
        static var demoFood: String { b23("bienvenida23.demo.food") }
        static var demoTransport: String { b23("bienvenida23.demo.transport") }
        static var demoHome: String { b23("bienvenida23.demo.home") }
        static var demoYou: String { b23("bienvenida23.demo.you") }
        static var demoPaidSplit: String { b23("bienvenida23.demo.paidSplit") }
        static func demoVoiceSaid(_ amount: String) -> String {
            String(format: b23("bienvenida23.demo.voiceSaid"), amount)
        }
        static var demoVoiceDone: String { b23("bienvenida23.demo.voiceDone") }
        static func demoPerMonth(_ amount: String) -> String {
            String(format: b23("bienvenida23.demo.perMonth"), amount)
        }
        static func demoSpentSoFar(_ amount: String) -> String {
            String(format: b23("bienvenida23.demo.spentSoFar"), amount)
        }
        static var demoLeft: String { b23("bienvenida23.demo.left") }
        static func demoOwesYou(_ name: String) -> String {
            String(format: b23("bienvenida23.demo.owesYou"), name)
        }
        static func demoYouOwe(_ name: String) -> String {
            String(format: b23("bienvenida23.demo.youOwe"), name)
        }
        static func demoPaidYou(_ name: String) -> String {
            String(format: b23("bienvenida23.demo.paidYou"), name)
        }
        static var demoAllSettled: String { b23("bienvenida23.demo.allSettled") }
    }

    /// Y23-04 · la conversación de tres preguntas.
    enum Conversation {
        static var subtitle: String { b23("bienvenida23.chat.subtitle") }
        static var cardTitle: String { b23("bienvenida23.chat.cardTitle") }
        static var rowName: String { b23("bienvenida23.chat.rowName") }
        static var rowCurrency: String { b23("bienvenida23.chat.rowCurrency") }
        static var rowTracking: String { b23("bienvenida23.chat.rowTracking") }
        static var pending: String { b23("bienvenida23.chat.pending") }
        static var typing: String { b23("bienvenida23.chat.typing") }

        static var hello: String { b23("bienvenida23.chat.hello") }
        static var askName: String { b23("bienvenida23.chat.askName") }
        static func askProposedName(_ name: String) -> String {
            String(format: b23("bienvenida23.chat.askProposedName"), name)
        }
        static func yesCallMe(_ name: String) -> String {
            String(format: b23("bienvenida23.chat.yesCallMe"), name)
        }
        static var otherName: String { b23("bienvenida23.chat.otherName") }
        static var namePlaceholder: String { b23("bienvenida23.chat.namePlaceholder") }
        static var send: String { b23("bienvenida23.chat.send") }

        static func niceToMeet(_ name: String) -> String {
            String(format: b23("bienvenida23.chat.niceToMeet"), name)
        }
        static var askCurrency: String { b23("bienvenida23.chat.askCurrency") }
        static var byRegion: String { b23("bienvenida23.chat.byRegion") }
        static var dollars: String { b23("bienvenida23.chat.dollars") }
        static var otherCurrency: String { b23("bienvenida23.chat.otherCurrency") }

        static var askTracking: String { b23("bienvenida23.chat.askTracking") }
        static var incomeAndExpenses: String { b23("bienvenida23.chat.incomeAndExpenses") }
        static var expensesOnly: String { b23("bienvenida23.chat.expensesOnly") }
        static var whatsTheDifference: String { b23("bienvenida23.chat.whatsTheDifference") }
        static var incomeAndExpensesExplained: String { b23("bienvenida23.chat.incomeAndExpensesExplained") }
        static var expensesOnlyExplained: String { b23("bienvenida23.chat.expensesOnlyExplained") }

        static func readyNamed(_ name: String) -> String {
            String(format: b23("bienvenida23.chat.readyNamed"), name)
        }
        static var ready: String { b23("bienvenida23.chat.ready") }
        static var yourYalaIsReady: String { b23("bienvenida23.chat.yourYalaIsReady") }
        static var enterYala: String { b23("bienvenida23.chat.enterYala") }
    }

    /// Y23-02 · el acceso único: «Vamos a crear tu cuenta» y «¿Cargamos tus datos y entramos?».
    enum UnifiedAccess {
        static var createTitle: String { b23("bienvenida23.access.createTitle") }
        static var createBody: String { b23("bienvenida23.access.createBody") }
        /// Con el mismo correo, Apple y Google abren la misma cuenta (GoTrue enlaza las identidades por correo verificado,
        /// decisión de Jürgen del 13-nov); con otro correo, otra cuenta.
        static var sameEmailNote: String { b23("bienvenida23.access.sameEmailNote") }
        /// El punto de acceso del consentimiento sin nombrar iCloud: en el alta del Welcome no se menciona (13-nov).
        static var consentAccessDetail: String { b23("bienvenida23.access.consentAccessDetail") }
        /// La cuenta nueva acaba de crearse y aún faltan las tres preguntas: no es «¡Tu cuenta está lista!».
        static var createdTitle: String { b23("bienvenida23.access.createdTitle") }
        static var createdBody: String { b23("bienvenida23.access.createdBody") }
        static var useAnotherAccount: String { b23("bienvenida23.access.useAnotherAccount") }
        static var existsTitle: String { b23("bienvenida23.access.existsTitle") }
        static var existsBody: String { b23("bienvenida23.access.existsBody") }
        static var loadAndEnter: String { b23("bienvenida23.access.loadAndEnter") }
    }
}
