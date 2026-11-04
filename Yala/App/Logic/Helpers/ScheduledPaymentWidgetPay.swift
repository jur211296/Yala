//
//  ScheduledPaymentWidgetPay.swift
//  Yala
//
//  «Marcar como pagado» en el widget de Pagos planificados (decisión B de Jürgen, 2026-11-03: solo marcar pagado, sin
//  «repetir favorito»). El botón del widget marca el pago de HOY sin abrir Yala.
//
//  Cómo, y por qué así: el intent del botón corre en la extensión del widget y NO toca SwiftData. Abrir un segundo
//  `ModelContainer` sobre el store de la app dejaba una ventana de reconciliación que vaciaba la UI hasta un cold launch
//  (`Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`), y por eso Apple Pay y Siri encolan en el App Group. Este
//  botón hace lo mismo: deja una PETICIÓN (pago + fecha) en el App Group, el widget lo pinta pagado en el acto, y la app
//  la convierte en el registro con la misma lógica que «Ya lo pagué → Apuntarlo ahora» la próxima vez que corre
//  (`ScheduledPaymentDraftService.processWidgetPaidRequests`, desde `InboundCaptureDrain`).
//
//  Membership: Yala (para los tests y el drenaje) + YalaWidgetsExtension (vía exception set en el pbxproj, como
//  `WidgetSelectionFallback`). Sin dependencias de la app ni de WidgetKit.
//

import Foundation

/// Una petición del widget: marca como pagada la fecha `occurrence` del pago `paymentID`.
nonisolated struct ScheduledPaymentWidgetPaidRequest: Codable, Equatable, Sendable {
    /// Identidad estable: nombra la key en el App Group.
    var id: UUID = UUID()
    /// `ScheduledPayment.id`.
    let paymentID: String
    /// La fecha del pago que se marca (su `nextDueDate` en la foto del widget).
    let occurrence: Date
    /// Cuándo se tocó el botón.
    let requestedAt: Date
}

/// La cola en el App Group, una key por petición: el intent escribe desde la extensión y la app lee y borra desde su
/// proceso, y `UserDefaults` no tiene compare-and-swap entre procesos (molde de `ApplePayPendingStore`).
nonisolated enum ScheduledPaymentWidgetPaidStore {

    static let keyPrefix = "scheduledPaymentWidgetPaid."

    static func append(_ request: ScheduledPaymentWidgetPaidRequest, defaults: UserDefaults?) {
        guard let defaults else { return }
        do {
            defaults.set(try JSONEncoder().encode(request), forKey: keyPrefix + request.id.uuidString)
        } catch {
            #if DEBUG
            print("ScheduledPaymentWidgetPaidStore: Error encoding request: \(error)")
            #endif
        }
    }

    /// Todas las peticiones, sin borrarlas, por orden de toque. Lo corrupto se descarta (no reintentar en bucle).
    static func peekAll(defaults: UserDefaults?) -> [(key: String, request: ScheduledPaymentWidgetPaidRequest)] {
        guard let defaults else { return [] }
        var result: [(key: String, request: ScheduledPaymentWidgetPaidRequest)] = []
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(keyPrefix) {
            guard let data = value as? Data else {
                defaults.removeObject(forKey: key)
                continue
            }
            do {
                result.append((key, try JSONDecoder().decode(ScheduledPaymentWidgetPaidRequest.self, from: data)))
            } catch {
                #if DEBUG
                print("ScheduledPaymentWidgetPaidStore: Error decoding \(key): \(error)")
                #endif
                defaults.removeObject(forKey: key)
            }
        }
        return result.sorted { $0.request.requestedAt < $1.request.requestedAt }
    }

    static func remove(keys: [String], defaults: UserDefaults?) {
        guard let defaults else { return }
        for key in keys { defaults.removeObject(forKey: key) }
    }
}

/// Qué pago lleva el botón y qué pinta el widget mientras la app no ha corrido.
nonisolated enum ScheduledPaymentWidgetPayLogic {

    /// Se marca en un toque lo mismo que «Apuntarlo ahora» de la hoja «Ya lo pagué»: un pago personal con cuenta y
    /// subcategoría. Uno compartido se aprueba con el formulario de grupo, y uno de monto variable necesita que digas
    /// cuánto fue: esos abren Yala, como siempre.
    static func canMarkPaid(isGroupPayment: Bool, hasAccount: Bool, hasSubcategory: Bool, isVariableAmount: Bool) -> Bool {
        !isGroupPayment && hasAccount && hasSubcategory && !isVariableAmount
    }

    /// El botón sale solo en el pago de HOY (su próxima fecha es hoy), no en uno vencido ni en uno que viene.
    static func showsButton(canMarkPaid: Bool, nextDueDate: Date, now: Date, calendar: Calendar) -> Bool {
        canMarkPaid && calendar.isDate(nextDueDate, inSameDayAs: now)
    }

    /// ¿Hay una petición para esa fecha de ese pago? El widget lo pinta pagado hasta que la app la convierta.
    static func isRequested(
        paymentID: String, nextDueDate: Date, requests: [ScheduledPaymentWidgetPaidRequest], calendar: Calendar
    ) -> Bool {
        requests.contains { $0.paymentID == paymentID && calendar.isDate($0.occurrence, inSameDayAs: nextDueDate) }
    }

    /// Qué hace la app con una petición al drenarla.
    enum Resolution: Equatable {
        /// Se apunta: la fecha sigue pendiente.
        case record
        /// Ya no hay nada que hacer (el pago ya avanzó de esa fecha, se borró o ya no se puede marcar): se retira.
        case discard
    }

    /// La petición se apunta solo si el pago existe, sigue pudiéndose marcar y su próxima fecha es aún la del toque. Si
    /// ya avanzó (la persona lo apuntó desde la app, o lo saltó), apuntarlo otra vez duplicaría el registro.
    static func resolve(
        request: ScheduledPaymentWidgetPaidRequest, paymentExists: Bool, canMarkPaid: Bool, nextDueDate: Date?,
        calendar: Calendar
    ) -> Resolution {
        guard paymentExists, canMarkPaid, let nextDueDate,
              calendar.isDate(nextDueDate, inSameDayAs: request.occurrence) else { return .discard }
        return .record
    }
}
