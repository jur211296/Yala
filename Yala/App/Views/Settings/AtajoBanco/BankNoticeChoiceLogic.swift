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

    /// El aviso de ejemplo de «Probar con un aviso de ejemplo». Con los bancos de Perú (región o moneda), el de siempre,
    /// en soles. Fuera, «Tu banco o app» lleva la moneda principal de Yala (o la de la región si no la hay) y un comercio
    /// genérico: antes decía «S/ 25.00 en Starbucks Larcomar» también en Estados Unidos.
    static func sampleText(for bank: BankNoticeBank, regionCode: String?, mainCurrencyCode: String?) -> String {
        guard bank == .other, !offersPeruvianBanks(regionCode: regionCode, mainCurrencyCode: mainCurrencyCode) else {
            return BankNoticeSamples.text(for: bank)
        }
        let code = sampleCurrencyCode(regionCode: regionCode, mainCurrencyCode: mainCurrencyCode)
        return "Tu banco\nPagaste \(code) \(sampleAmount(currencyCode: code)) en CAFE CENTRAL con tu tarjeta ****3456."
    }

    /// La moneda del ejemplo fuera de Perú: la principal de Yala; sin ella, la de la región del iPhone; sin las dos, USD.
    static func sampleCurrencyCode(regionCode: String?, mainCurrencyCode: String?) -> String {
        if let main = mainCurrencyCode?.uppercased(), main.count == 3 { return main }
        if let region = regionCode, let regional = Locale(identifier: "und_\(region.uppercased())").currency?.identifier {
            return regional.uppercased()
        }
        return "USD"
    }

    /// 25 con los decimales de esa moneda: «25.00» en USD, «25» en JPY.
    static func sampleAmount(currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let digits = formatter.maximumFractionDigits
        return String(format: "%.\(digits)f", 25.0)
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
