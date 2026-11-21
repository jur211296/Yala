//
//  FlujoMonedaTexto.swift
//  Yala
//
//  Cómo se escribe un monto en su moneda original («500.00 USD») y un tipo de cambio («3.70») en el flujo de caja. El
//  código va detrás y no el símbolo: con soles y dólares en la misma pantalla, «$» no dice de qué dólar se habla.
//

import Foundation

enum FlujoMonedaTexto {

    /// «500.00 USD», con los separadores del formato regional, los mismos que los montos de la app (`AmountText`).
    static func original(_ monto: Double, moneda: String) -> String {
        let numero = monto.formatted(.number.precision(.fractionLength(2)).locale(Locale.current))
        return "\(numero) \(moneda)"
    }

    /// «3.70»; con una tasa menor que 1 (yenes a soles), cuatro decimales para que no salga «0.03».
    static func tasa(_ factor: Double) -> String {
        let decimales = factor < 1 ? 4 : 2
        return factor.formatted(.number.precision(.fractionLength(decimales)).locale(Locale.current))
    }

    /// La tasa con «≈» delante cuando es aproximada.
    static func tasa(_ tasa: FlujoTasaDelMes.Tasa) -> String {
        tasa.esAproximada ? "≈ \(self.tasa(tasa.factor))" : self.tasa(tasa.factor)
    }

    /// «nov.», el mes abreviado en el idioma de la app.
    static func mesCorto(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().month(.abbreviated).locale(AppLocale.current))
    }
}
