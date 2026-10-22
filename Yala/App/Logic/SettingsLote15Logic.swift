//
//  SettingsLote15Logic.swift
//  Yala
//
//  Lógica pura del lote decidido 2.2 · 15 (Ajustes, ayuda y preferencias). Va aparte de las vistas para fijarla con
//  tests: lo que decide qué se ve no puede depender de que alguien lo mire en el simulador.
//

import AVFoundation
import Foundation
import Photos
import UserNotifications

// MARK: - L16-2 · El nombre de serie no se escribe en el campo

nonisolated enum PersonalNameFieldLogic {
    /// Lo que enseña el campo «Nombre». El nombre de serie («Usuario») es un hueco, no un valor: el campo sale vacío y
    /// se ve la pista «Tu nombre». Un nombre que la persona escribió, aunque coincida en mayúsculas, se respeta.
    static func fieldValue(stored: String, defaultName: String) -> String {
        stored == defaultName ? "" : stored
    }
}

// MARK: - L16-4 · Tasas que se pueden leer

nonisolated enum ExchangeRateRowLogic {
    /// Por debajo de esta tasa la fila se lee al revés: «1 PYG = 0.0004581 PEN» no dice nada; «1 PEN = 2,183 PYG», sí.
    static let invertBelow = 0.01

    enum Display: Equatable {
        /// «1 USD = 3.55 PEN»: la tasa tal cual, `1 currency = rate preferred`.
        case direct(Double)
        /// «1 PEN = 2,183 PYG»: cuántas unidades de la divisa débil son una de la principal.
        case inverted(Double)
    }

    /// Cómo se escribe `rate` (cuánto vale 1 de la divisa de la fila en la principal). `nil` si no hay una tasa usable.
    static func display(rate: Double?) -> Display? {
        guard let rate, rate.isFinite, rate > 0 else { return nil }
        return rate < invertBelow ? .inverted(1 / rate) : .direct(rate)
    }

    /// La tasa invertida escrita para leerla: son siempre más de 100 unidades, así que basta con dos decimales
    /// («2,117.49», no «2,117.4863», que además partía la fila en dos líneas).
    static func invertedString(_ units: Double, locale: Locale = .current) -> String {
        guard units.isFinite else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: units)) ?? "—"
    }

    /// Si la divisa entra en la búsqueda: por código («pyg»), por nombre («guaraní», sin importar tildes ni mayúsculas)
    /// o por el nombre del continente. Sin texto, entra todo.
    static func matches(query: String, code: String, name: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return code.range(of: needle, options: options) != nil || name.range(of: needle, options: options) != nil
    }
}

// MARK: - L16-15 · Valorar y recomendar

nonisolated enum AppStoreLinks {
    /// El id de Yala en la App Store (lo usa ya la ficha y el enlace de invitación de grupos).
    static let appID = "6758253109"

    /// La ficha de Yala: lo que se comparte al recomendar.
    static var listingURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appID)") ?? URL(fileURLWithPath: "/")
    }

    /// «Escribir una reseña» directamente. `requestReview()` lo decide Apple y casi nunca sale: la fila no hacía nada.
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") ?? URL(fileURLWithPath: "/")
    }
}

// MARK: - L16-14 · Permisos de Yala

/// El estado de un permiso, ya traducido a lo que la pantalla dice. Los cuatro de iOS se pliegan aquí para que la
/// vista no decida con `switch` sobre tipos del sistema (y para fijarlo con tests).
nonisolated enum PermissionState: Equatable {
    case allowed
    /// Fotos: solo algunas fotos (`.limited`).
    case limited
    /// Fotos: solo guardar, sin leer la galería (`.addOnly` concedido).
    case saveOnly
    case denied
    /// iOS aún no lo preguntó: Yala lo pide la primera vez que se usa. En Configuración todavía no hay interruptor,
    /// así que ahí no se manda a nadie.
    case notAsked

    /// Si tiene sentido el botón «Cambiar en Configuración»: con el permiso sin preguntar, la página de Yala en
    /// Configuración no tiene aún el interruptor y el botón llevaría a un sitio sin nada que tocar.
    var offersSettingsButton: Bool { self != .notAsked }

    static func camera(_ status: AVAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: .allowed
        case .denied, .restricted: .denied
        case .notDetermined: .notAsked
        @unknown default: .notAsked
        }
    }

    static func microphone(_ permission: AVAudioApplication.recordPermission) -> PermissionState {
        switch permission {
        case .granted: .allowed
        case .denied: .denied
        case .undetermined: .notAsked
        @unknown default: .notAsked
        }
    }

    /// Fotos tiene dos permisos: leer la galería (`.readWrite`) y solo guardar (`.addOnly`, el que usan los resúmenes
    /// de grupo). Manda el de leer si ya se contestó; si no, el de guardar.
    static func photos(readWrite: PHAuthorizationStatus, addOnly: PHAuthorizationStatus) -> PermissionState {
        switch readWrite {
        case .authorized: return .allowed
        case .limited: return .limited
        case .denied, .restricted: return .denied
        case .notDetermined: break
        @unknown default: break
        }
        switch addOnly {
        case .authorized, .limited: return .saveOnly
        case .denied, .restricted: return .denied
        default: return .notAsked
        }
    }

    static func notifications(_ status: UNAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        case .notDetermined: .notAsked
        @unknown default: .notAsked
        }
    }
}

// MARK: - L16-16 · «Hacerlo ahora» al terminar un tutorial

enum TutorialDoItNowLogic {
    /// A dónde lleva «Hacerlo ahora». Lo que vive en Ajustes se abre ahí mismo; lo demás cierra Ajustes y va por el
    /// router, como el resto de entradas de la app (la lista de «Primeros pasos» abre presupuestos y pagos igual).
    enum Target: Equatable {
        /// Una pantalla de Ajustes (Cuentas, Categorías, Etiquetas, Favoritos).
        case settings(ProfileDestination)
        /// La hoja de importar, que cuelga de la lista de Ajustes.
        case importFile
        /// El formulario de nuevo registro.
        case newRecord
        /// Planificación › Presupuestos (su «+» a la vista).
        case newBudget
        /// Planificación › Pagos planificados (su «+» a la vista).
        case newScheduledPayment
        /// El Panel.
        case panel
        /// La Bandeja.
        case inbox
    }

    static func target(for tutorial: Tutorial) -> Target {
        switch tutorial {
        case .createAccount: .settings(.accounts)
        case .createCategories: .settings(.categories)
        case .createTags: .settings(.tags)
        case .createFavorites: .settings(.favorites)
        case .importData: .importFile
        case .createRecord: .newRecord
        case .createBudgets: .newBudget
        case .createScheduledPayments: .newScheduledPayment
        case .editPanel, .panelFiltering: .panel
        case .inboxApproval: .inbox
        // Apple Pay es una guía por pasos fuera de Yala (`ApplePayAutomationGuideView`): no usa este cierre. Si algún
        // día lo usara, su pantalla es la propia guía, que vive en Tutoriales.
        case .applePay: .settings(.tips)
        }
    }
}
