//
//  ApproximateMarkThreshold.swift
//  Yala
//
//  Cuándo un total se gana el «≈».
//
//  Decisión de producto de Jürgen (2026-09-08), ticket
//  `approximate-mark-ors-over-whole-period`: la marca deja de ser un OR sobre todo el período y pasa
//  a pedir que la parte aproximada PESE.
//
//  El motivo lo dice el propio código de `FXPnLLogic`: marcar de más erosiona la marca igual que no
//  ponerla. Con el OR bastaba UNA transacción con tasa aproximada —editar la nota de una de hace dos
//  años, crear una sin red, cambiar la divisa preferida— para que el número grande del mes entero
//  saliera con «≈». Para el usuario multidivisa eso pasaba casi siempre, y una marca que sale
//  siempre deja de significar nada.
//

import Foundation

/// El umbral vive **solo aquí**. Si aparece un `0.05` suelto en un calculador, es un bug de
/// duplicación: los calculadores llaman a `marks(approximate:total:)`, no comparan a mano.
enum ApproximateMarkThreshold {

    /// Un total se marca «≈» cuando la parte que salió de una tasa aproximada llega a esta fracción
    /// de su propio lado (gasto sobre gasto, ingreso sobre ingreso).
    ///
    /// **5 %** es la decisión del 2026-09-08: por debajo, el error posible es menor que el redondeo
    /// que el usuario ya ve en pantalla; por encima, la marca informa de algo real.
    static let fraction: Double = 0.05

    /// Suelo de ruido, en la divisa preferida. Se aplica **a los dos lados del cociente**.
    ///
    /// Alineado a propósito con `FXPnLLogic.nearZero` (0.01): dos suelos distintos para el mismo
    /// problema es como divergen. Un céntimo es el grano más fino que el usuario ve en las divisas
    /// de 2 decimales; en las de 3 (KWD, BHD, OMR) se traga hasta 10 fils, y ese error es
    /// deliberado — por debajo de un céntimo la proporción es ruido de coma flotante, no una señal.
    private static let noiseFloor: Double = 0.01

    /// ¿Se marca este total?
    ///
    /// - Parameters:
    ///   - approximate: **suma de MAGNITUDES** (`Σ|contribución|`) de los importes que salieron de
    ///     una tasa aproximada.
    ///   - total: **suma de MAGNITUDES** de todos los importes que forman el número que se muestra,
    ///     o su valor absoluto cuando el número es una resta (ahí el denominador honesto es lo que
    ///     el usuario ve).
    ///
    /// > Importante: los dos son **magnitudes sumadas, nunca netos**. Es la misma conclusión a la
    /// > que llegó `FXPnLLogic` con su `exposedBase = Σ|costBasis|`, y por el mismo motivo: **los
    /// > errores de dos conversiones distintas no se cancelan entre sí**. Un gasto de 1.000 y un
    /// > reembolso de 900, los dos con tasa dudosa, no dejan 100 de incertidumbre: dejan 1.900. Si
    /// > el numerador se acumulara con signo, dos aproximaciones opuestas se anularían y el número
    /// > saldría limpio precisamente cuando menos lo está.
    ///
    /// Tres casos, y el orden importa:
    ///
    /// 1. **Nada aproximado ⇒ nunca marca.** Va primero porque es el caso que blinda al usuario
    ///    monomoneda: sin esta salida, un total de cero con cero aproximado caería en el caso 2 y
    ///    marcaría un número en el que no hubo ninguna conversión.
    /// 2. **Denominador inservible ⇒ marca.** Cuando no se puede medir la proporción, se avisa: el
    ///    error posible es que la marca sobre, no que falte, y ese es el lado seguro. Pasa de verdad
    ///    en el número que resta un lado del otro (un mes que cierra casi en cero).
    /// 3. **Proporción.** El caso normal.
    static func marks(approximate: Double, total: Double) -> Bool {
        let approximateMagnitude = abs(approximate)
        // El suelo va aquí y no en `> 0`: con `Double`, una cancelación que deja 1e-15 pasaría un
        // `> 0` y marcaría, mientras que la misma cancelación exacta no. Dos respuestas para el
        // mismo caso de usuario según cómo cayeran los decimales.
        guard approximateMagnitude > noiseFloor else { return false }

        let totalMagnitude = abs(total)
        guard totalMagnitude > noiseFloor else { return true }

        // El umbral se dijo INCLUSIVO, y en binario eso no sale gratis por ninguno de los dos
        // caminos: `0.15 / 3.0` da 0.049999999999999996 (se queda corto por abajo) y `0.05 * 3.0` da
        // 0.15000000000000002 (se pasa por arriba). Un 5 % exacto quedaría fuera en los dos casos,
        // por un ulp. La tolerancia relativa es lo que lo hace inclusivo de verdad; es diez órdenes
        // de magnitud menor que cualquier diferencia que importe (49 % contra 50 % ni se inmuta).
        let threshold = fraction * totalMagnitude
        return approximateMagnitude >= threshold * (1 - 1e-9)
    }
}
