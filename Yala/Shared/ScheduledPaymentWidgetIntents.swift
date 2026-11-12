//
//  ScheduledPaymentWidgetIntents.swift
//  Shared
//
//  El botón «Ya lo pagué» del widget de Pagos planificados (decisión B de Jürgen, 2026-11-03). Corre en la extensión y
//  no abre Yala ni su base de datos: deja la petición en el App Group (`ScheduledPaymentWidgetPaidStore`) y recarga el
//  widget, que la pinta pagada. La app crea el registro al correr (ver la cabecera de `ScheduledPaymentWidgetPay`).
//  Target membership: YalaWidgetsExtension only (excluded from Yala main), como `ControlCenterIntents`.
//

import AppIntents
import Foundation
import WidgetKit

struct MarkScheduledPaymentPaidIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.payments.markPaid.intentTitle"
    static var description = IntentDescription("widget.payments.markPaid.intentDescription")
    static var openAppWhenRun: Bool = false
    /// Solo lo dispara el botón del widget: no sale en Atajos.
    static var isDiscoverable: Bool = false

    @Parameter(title: "widget.payments.markPaid.paramPayment")
    var paymentID: String

    @Parameter(title: "widget.payments.markPaid.paramDate")
    var occurrence: Date

    init() {}

    init(paymentID: String, occurrence: Date) {
        self.paymentID = paymentID
        self.occurrence = occurrence
    }

    func perform() async throws -> some IntentResult {
        ScheduledPaymentWidgetPaidStore.append(
            ScheduledPaymentWidgetPaidRequest(paymentID: paymentID, occurrence: occurrence, requestedAt: .now),
            defaults: UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier))
        WidgetCenter.shared.reloadTimelines(ofKind: "ScheduledPaymentsWidget")
        return .result()
    }
}
