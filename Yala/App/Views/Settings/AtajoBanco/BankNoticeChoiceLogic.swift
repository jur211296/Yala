//
//  BankNoticeChoiceLogic.swift
//  Yala
//
//  «Avisos del banco», encargo del 23-nov-2026 (pruebas de 2.3 en el iPhone). Reglas puras, para los tests:
//
//  - Qué bancos se ofrecen. Los que tienen reglas (BCP, Yape, Interbank, Plin, BBVA, Scotiabank) son de Perú: se ofrecen
//    si el iPhone está en Perú o si la moneda principal de Yala es el sol. Fuera de Perú solo queda «Tu banco o app»
//    (`.other`), que lee el modelo del iPhone y sirve para cualquier banco.
//  - Cuándo un banco está activo. Abrir su pantalla no cuenta: la persona confirma «Ya lo configuré» o llega un aviso de
//    verdad. Antes, entrar a mirar el BCP lo dejaba en «Activos · Esperando el primer aviso».
//

import Foundation

nonisolated enum BankNoticeChoiceLogic {

    /// ¿Se ofrecen los bancos de Perú? Por la región del iPhone o por la moneda principal (PEN).
    static func offersPeruvianBanks(regionCode: String?, mainCurrencyCode: String?) -> Bool {
        regionCode?.uppercased() == "PE" || mainCurrencyCode?.uppercased() == "PEN"
    }

    /// Los bancos de «¿De qué banco?» que aún no están activos, en el orden de `allCases`.
    static func addableBanks(
        regionCode: String?, mainCurrencyCode: String?, active: [BankNoticeBank]
    ) -> [BankNoticeBank] {
        let pool: [BankNoticeBank] = offersPeruvianBanks(regionCode: regionCode, mainCurrencyCode: mainCurrencyCode)
            ? BankNoticeBank.allCases
            : [.other]
        return pool.filter { !active.contains($0) }
    }

    /// Activo: la persona confirmó que terminó la configuración, o llegó algún aviso de ese banco.
    static func isActive(settings: BankNoticeSettings, activity: BankNoticeActivity) -> Bool {
        settings.isSetUp || !activity.arrivals.isEmpty
    }

    /// «Ya lo configuré»: lo marca activo sin tocar la pausa ni la cuenta por defecto.
    static func confirmingSetup(_ settings: BankNoticeSettings) -> BankNoticeSettings {
        var confirmed = settings
        confirmed.isSetUp = true
        return confirmed
    }
}

extension BankNoticeActivityStore {
    /// «Quitar de Activos»: el banco vuelve a «¿De qué banco?». Borra sus ajustes y lo que Yala sabía de él (estado y
    /// contadores). Si su automatización sigue en Atajos, el próximo aviso lo vuelve a activar: lo dice la confirmación.
    nonisolated static func deactivate(_ bank: BankNoticeBank, defaults: UserDefaults? = appGroupDefaults) {
        guard let defaults else { return }
        defaults.removeObject(forKey: settingsPrefix + bank.rawValue)
        defaults.removeObject(forKey: activityPrefix + bank.rawValue)
    }
}
