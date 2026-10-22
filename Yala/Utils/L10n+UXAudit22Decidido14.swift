//
//  L10n+UXAudit22Decidido14.swift
//  Yala
//
//  Textos del lote decidido 2.2 · 14 (Grupos: invitar, la web de invitación, unirse, aprobar solicitudes y avisos),
//  implementado el 2026-10-21. Van en su propio fichero, como los de cada lote, para no pisar `L10n.swift`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l14d(_ key: String) -> String {
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
    enum UXD14 {

        // MARK: - L12-8 · Avisos del grupo dentro de «está listo» y «Ya estás en»

        static var notifyTitle: String { l14d("groups.d14.notify.title") }
        static var notifyWhy: String { l14d("groups.d14.notify.why") }
        static var notifyEnable: String { l14d("groups.d14.notify.enable") }
        static var notifyEnabled: String { l14d("groups.d14.notify.enabled") }
        static var notifyDenied: String { l14d("groups.d14.notify.denied") }

        // MARK: - L12-14 · El mensaje que viaja con el enlace

        static func shareMessage(inviter: String, group: String) -> String {
            String(format: l14d("groups.d14.share.message"), inviter, group)
        }
        static func shareMessageNoInviter(group: String) -> String {
            String(format: l14d("groups.d14.share.messageNoInviter"), group)
        }

        // MARK: - L12-17 · La tarjeta del grupo antes de la cuenta

        static func invitedBy(_ name: String) -> String { String(format: l14d("groups.d14.invite.invitedBy"), name) }
        static var invitedFallback: String { l14d("groups.d14.invite.invitedFallback") }
        static var nextAccount: String { l14d("groups.d14.invite.nextAccount") }

        // MARK: - L12-18 · «Ya estás en «X»»

        static func readyTitle(_ group: String) -> String { String(format: l14d("groups.d14.ready.title"), group) }
        static var readyTitleNoName: String { l14d("groups.d14.ready.titleNoName") }
        static func readyWith(_ names: String) -> String { String(format: l14d("groups.d14.ready.with"), names) }
        /// «Ana, Beto y Carla» en el idioma de la app (no en el de la región, que es lo que daría `Locale.current`).
        static func names(_ names: [String]) -> String {
            let formatter = ListFormatter()
            formatter.locale = AppLocale.current
            return formatter.string(from: names) ?? names.joined(separator: ", ")
        }
        static var readyAddExpense: String { l14d("groups.d14.ready.addExpense") }
        static var readyViewGroup: String { l14d("groups.d14.ready.viewGroup") }

        // MARK: - L12-19 · La pestaña mientras se conecta

        static var onTheWayTitle: String { l14d("groups.d14.onTheWay.title") }
        static var onTheWayMessage: String { l14d("groups.d14.onTheWay.message") }

        // MARK: - L12-20 · El aviso al ser aprobado

        static var approvedBody: String { l14d("groups.d14.approved.body") }

        // MARK: - L19-1 · Solicitudes para unirse

        static func requestsBannerOne(_ name: String) -> String {
            String(format: l14d("groups.d14.requests.bannerOne"), name)
        }
        static var requestsBannerMany: String { l14d("groups.d14.requests.bannerMany") }
        static var requestsBannerBodyOne: String { l14d("groups.d14.requests.bannerBodyOne") }
        static var requestsBannerBodyMany: String { l14d("groups.d14.requests.bannerBodyMany") }
        static var requestsReview: String { l14d("groups.d14.requests.review") }
        static func requestsSection(_ count: Int) -> String {
            String(format: l14d("groups.d14.requests.section"), count)
        }
        static var requestsOpenedToday: String { l14d("groups.d14.requests.openedToday") }
        static var requestsOpenedYesterday: String { l14d("groups.d14.requests.openedYesterday") }
        static func requestsOpenedOn(_ date: String) -> String {
            String(format: l14d("groups.d14.requests.openedOn"), date)
        }
        static var requestsConsequence: String { l14d("groups.d14.requests.consequence") }
        static var requestsAccept: String { l14d("groups.d14.requests.accept") }
        static func requestsAcceptConfirm(_ name: String) -> String {
            String(format: l14d("groups.d14.requests.acceptConfirm"), name)
        }

        /// «Abrió tu enlace de invitación hoy / ayer / el 12 oct», según el día en que pidió unirse.
        static func requestOpened(_ date: Foundation.Date, now: Foundation.Date = .now,
                                  calendar: Calendar = .current) -> String {
            if calendar.isDate(date, inSameDayAs: now) { return requestsOpenedToday }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
               calendar.isDate(date, inSameDayAs: yesterday) {
                return requestsOpenedYesterday
            }
            let formatter = DateFormatter()
            formatter.locale = AppLocale.current
            formatter.setLocalizedDateFormatFromTemplate("dMMM")
            return requestsOpenedOn(formatter.string(from: date))
        }
    }
}
