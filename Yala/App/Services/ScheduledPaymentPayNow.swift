//
//  ScheduledPaymentPayNow.swift
//  Yala
//
//  «Ya lo pagué → Apuntarlo ahora» (UX 2.2 · L10-9, L10-11) en un solo sitio: lo usan la hoja de «Ya lo pagué»
//  (`ScheduledPaymentsViewModel.recordPaymentNow`) y el botón del widget de Pagos planificados, cuyas peticiones se
//  convierten aquí en el registro cuando la app corre (`processWidgetPaidRequests`, desde `InboundCaptureDrain`).
//

import Foundation
import SwiftData

@MainActor
enum ScheduledPaymentPayNow {

    /// El borrador con el que se apunta una fecha: el pendiente que ya espera en la Bandeja para ese pago y ese mes
    /// (el que dejó el vencimiento), o uno nuevo (`isNew`). La fecha del registro es la del pago si ya llegó, y hoy si
    /// se paga por adelantado: la Bandeja no deja guardar registros con fecha futura. Un pago compartido no pasa por
    /// aquí: se aprueba con el formulario de grupo (`DraftService` lo rechazaría).
    static func draftForPaying(
        _ payment: ScheduledPayment, occurrence: Date, context: ModelContext, now: Date = .now
    ) -> (draft: InboxDraft, isNew: Bool)? {
        guard !payment.isGroupPayment else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let targetDate = min(calendar.startOfDay(for: occurrence), today)
        let paymentID = payment.id.uuidString
        do {
            let descriptor = FetchDescriptor<InboxDraft>(
                predicate: #Predicate<InboxDraft> { draft in
                    draft.sourceScheduledPaymentID == paymentID && draft.statusRaw == "pending"
                }
            )
            if let existing = try context.fetch(descriptor).first(where: {
                calendar.isDate($0.date ?? $0.createdAt, equalTo: occurrence, toGranularity: .month)
            }) {
                return (existing, false)
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentPayNow: Error fetching pending drafts: \(error)")
            #endif
            return nil
        }
        let draft = ScheduledPaymentDraftService.createDraftForOccurrence(from: payment, date: targetDate, context: context)
        return (draft, true)
    }

    /// «Apuntarlo ahora» en un toque: el borrador de esa fecha con el monto elegido, aprobado por el mismo camino que la
    /// Bandeja (`DraftService.approveDraft`: registro, fecha pagada y próxima fecha). Lanza lo que lance la Bandeja.
    @discardableResult
    static func recordPaymentNow(
        _ payment: ScheduledPayment,
        occurrence: Date,
        amount: Double,
        draftService: DraftService,
        currencyConverter: CurrencyConverter,
        context: ModelContext,
        now: Date = .now
    ) throws -> TransactionItem? {
        guard amount > 0, let (draft, isNew) = draftForPaying(payment, occurrence: occurrence, context: context, now: now)
        else { return nil }
        draft.amount = payment.isIncome ? abs(amount) : -abs(amount)
        if draft.account == nil { draft.account = payment.account }
        if draft.subcategory == nil { draft.subcategory = payment.subcategory }
        let transaction: TransactionItem
        do {
            transaction = try draftService.approveDraft(draft, currencyConverter: currencyConverter)
        } catch {
            // Un borrador recién creado que no se pudo aprobar no se queda en el contexto: el siguiente guardado lo
            // dejaría en la Bandeja sin que nadie lo pidiera.
            if isNew { context.delete(draft) }
            throw error
        }
        ScheduledPaymentNotificationService.shared.requestSummaryReplan()
        return transaction
    }

    // MARK: - Las peticiones del widget

    /// Convierte las peticiones del botón del widget en registros, con `recordPaymentNow` y el monto del pago. Devuelve
    /// cuántos registros creó. Una petición cuyo pago ya avanzó de esa fecha, se borró o ya no se puede marcar se
    /// retira sin apuntar nada (apuntarla duplicaría el registro). Una que falla al aprobar se queda para la próxima vez.
    @discardableResult
    static func processWidgetPaidRequests(
        context: ModelContext,
        defaults: UserDefaults? = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier),
        draftService injected: DraftService? = nil,
        currencyConverter: CurrencyConverter = .shared,
        now: Date = .now
    ) -> Int {
        let pending = ScheduledPaymentWidgetPaidStore.peekAll(defaults: defaults)
        guard !pending.isEmpty else { return 0 }
        // Crea borradores y guarda en el store personal: como Apple Pay y Siri, espera a que el import de iCloud asiente.
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("ScheduledPaymentPayNow.processWidgetPaidRequests", "import not quiescent")
            return 0
        }
        // La Bandeja aprueba con el contexto que le dieron las vistas; aquí puede que no haya abierto ninguna todavía.
        let draftService = injected ?? DraftService.shared
        draftService.setContext(context)
        let calendar = Calendar.current
        var created = 0
        var done: [String] = []
        for (key, request) in pending {
            let payment: ScheduledPayment?
            do {
                guard let uuid = UUID(uuidString: request.paymentID) else {
                    done.append(key)
                    continue
                }
                var descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == uuid })
                descriptor.fetchLimit = 1
                payment = try context.fetch(descriptor).first
            } catch {
                #if DEBUG
                print("ScheduledPaymentPayNow: Error fetching payment: \(error)")
                #endif
                continue
            }
            let canMarkPaid = payment.map {
                ScheduledPaymentWidgetPayLogic.canMarkPaid(
                    isGroupPayment: $0.isGroupPayment, hasAccount: $0.account != nil,
                    hasSubcategory: $0.subcategory != nil, isVariableAmount: $0.isVariableAmount)
            } ?? false
            let resolution = ScheduledPaymentWidgetPayLogic.resolve(
                request: request, paymentExists: payment != nil, canMarkPaid: canMarkPaid,
                nextDueDate: payment?.nextDueDate, calendar: calendar)
            guard resolution == .record, let payment else {
                done.append(key)
                continue
            }
            do {
                if try recordPaymentNow(
                    payment, occurrence: request.occurrence, amount: payment.amount, draftService: draftService,
                    currencyConverter: currencyConverter, context: context, now: now) != nil {
                    created += 1
                }
                done.append(key)
            } catch {
                #if DEBUG
                print("ScheduledPaymentPayNow: Error recording widget request: \(error)")
                #endif
            }
        }
        ScheduledPaymentWidgetPaidStore.remove(keys: done, defaults: defaults)
        return created
    }
}
