//
//  HojaCuentaTarjetaLogica.swift
//  Yala
//
//  Lo que decide la cabecera de la hoja de una cuenta (pedido de Jürgen del 17-nov-2026, variante A «Wallet»): el tamaño
//  de la tarjeta, la barra de lo que debes (facturado frente a por facturar) y si el bloque de la tarjeta de crédito
//  ofrece añadir las fechas. Pura, sin vistas, para medirla en `YalaTests/HojaCuentaTarjeta/`.
//
//  La barra NO es «% de la línea usado»: Yala aún no guarda el límite de la tarjeta. Reparte lo que debes entre lo que ya
//  se facturó (lo que pagas en la próxima fecha de pago) y lo que entra en el corte siguiente.
//

import CoreGraphics
import Foundation

nonisolated enum HojaCuentaTarjetaLogica {

    /// Proporción de una tarjeta bancaria (ISO/IEC 7810 ID-1: 85,6 × 53,98 mm).
    static let proporcionTarjeta: CGFloat = 85.6 / 53.98

    /// Ancho tope de la tarjeta: en el iPad o el iPhone girado no crece más que en un iPhone grande.
    static let anchoMaximoTarjeta: CGFloat = 280

    /// El ancho de la tarjeta en un hueco de `disponible` puntos: todo el hueco hasta el tope. Nunca negativo.
    static func anchoTarjeta(disponible: CGFloat, tope: CGFloat = anchoMaximoTarjeta) -> CGFloat {
        guard disponible.isFinite, disponible > 0 else { return 0 }
        return min(disponible, tope)
    }

    /// El alto que corresponde a un ancho, en proporción de tarjeta.
    static func altoTarjeta(ancho: CGFloat) -> CGFloat {
        guard ancho > 0 else { return 0 }
        return ancho / proporcionTarjeta
    }

    // MARK: - Barra de lo que debes

    /// Lo facturado y lo por facturar de UNA divisa.
    struct Reparto: Equatable {
        let facturado: Double
        let porFacturar: Double

        /// La parte facturada de lo que debes, entre 0 y 1.
        var fraccionFacturada: Double {
            let total = facturado + porFacturar
            guard total > 0 else { return 0 }
            return min(max(facturado / total, 0), 1)
        }
    }

    /// La barra solo va con UNA divisa y con algo que deber: entre divisas no se suma, y con todo en cero no reparte nada.
    /// Las cifras negativas (un pago de más) cuentan como cero.
    static func reparto(lineas: [(facturado: Double, porFacturar: Double)]) -> Reparto? {
        guard lineas.count == 1, let linea = lineas.first else { return nil }
        let facturado = max(linea.facturado, 0)
        let porFacturar = max(linea.porFacturar, 0)
        guard facturado + porFacturar > 0 else { return nil }
        return Reparto(facturado: facturado, porFacturar: porFacturar)
    }

    // MARK: - Uso de línea («16 % usado · 6.752,50 disponible de 8.000,00»)

    /// Cuánto de la línea de crédito usas. Hoy Yala no guarda el límite de la tarjeta (decisión de Jürgen del
    /// 22-nov-2026: será un campo nuevo, en otro encargo), así que la hoja lo recibe como `nil` y no pinta la línea.
    struct UsoDeLinea: Equatable {
        let usado: Double
        let limite: Double

        /// La parte usada de la línea. Puede pasar de 1 si te pasaste del límite: se dice tal cual.
        var fraccionUsada: Double { usado / limite }
        /// Lo que te queda por usar. Nunca negativo.
        var disponible: Double { max(limite - usado, 0) }
    }

    /// Solo con un límite de verdad (positivo y finito) y con UNA divisa: sin límite no hay línea (ni texto vacío ni
    /// «0 %»), y entre divisas no se suma. Lo que debes es facturado + por facturar; un pago de más cuenta como cero.
    static func usoDeLinea(lineas: [(facturado: Double, porFacturar: Double)], limite: Double?) -> UsoDeLinea? {
        guard let limite, limite.isFinite, limite > 0 else { return nil }
        guard lineas.count == 1, let linea = lineas.first else { return nil }
        let usado = max(linea.facturado, 0) + max(linea.porFacturar, 0)
        return UsoDeLinea(usado: usado, limite: limite)
    }

    // MARK: - Bloque de la tarjeta de crédito

    /// Qué enseña el bloque de la tarjeta de crédito bajo el monto.
    enum Bloque: Equatable {
        /// Ninguno: no es tarjeta de crédito, es la cuenta de Grupos o el Panel está en «solo gastos» (sin saldos).
        case ninguno
        /// El estado de cuenta: lo que debes repartido, la fecha de pago y la del próximo corte.
        case estadoDeCuenta
        /// Tarjeta sin día de corte o de pago: pide las fechas y abre Editar.
        case pedirFechas
    }

    static func bloque(
        esTarjetaDeCredito: Bool,
        tieneEstadoDeCuenta: Bool,
        esCuentaDeSistema: Bool,
        soloGastos: Bool,
        puedeEditar: Bool
    ) -> Bloque {
        guard esTarjetaDeCredito, !esCuentaDeSistema, !soloGastos else { return .ninguno }
        if tieneEstadoDeCuenta { return .estadoDeCuenta }
        return puedeEditar ? .pedirFechas : .ninguno
    }

    // MARK: - Entrada de la tarjeta

    /// Cómo está la tarjeta antes de entrar: un poco más abajo, un poco más pequeña y transparente. Con Reducir
    /// movimiento, ya en su sitio (sin desplazamiento ni escala; solo aparece).
    struct Entrada: Equatable {
        let desplazamiento: CGFloat
        let escala: CGFloat
        let opacidad: Double
    }

    static func entradaInicial(reducirMovimiento: Bool) -> Entrada {
        reducirMovimiento
            ? Entrada(desplazamiento: 0, escala: 1, opacidad: 1)
            : Entrada(desplazamiento: 28, escala: 0.92, opacidad: 0)
    }

    static let entradaFinal = Entrada(desplazamiento: 0, escala: 1, opacidad: 1)
}
