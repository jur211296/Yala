//
//  FXRepairQueueLogic.swift
//  Yala
//
//  Cuándo el reparador de tasas provisionales deja de tener nada que hacer y hay que soltarlo.
//  Ticket `repair-queue-has-no-exit-for-partial-rate-rows`.
//

import Foundation

/// La salida del bucle del reparador de arranque.
///
/// **El problema que cierra.** `updateProvisionalTransactions` corre en cada arranque, recorre todas
/// las transacciones marcadas provisionales y pide las tasas de sus fechas. Si esa petición no puede
/// curarlas —porque el proveedor no tiene esa divisa en esa fecha, y no la va a tener mañana
/// tampoco— el barrido repetía exactamente el mismo trabajo inútil en el arranque siguiente, y en el
/// siguiente. No había `fetchLimit`, ni contador de intentos, ni backoff, ni sentinel.
///
/// **Por qué la huella y no un backoff temporal.** Una ventana de tiempo («no reintentes hasta dentro
/// de 24 h») corta el coste pero también corta la cura: si las tasas llegan cinco minutos después, la
/// transacción se queda mal un día entero por una constante que nadie eligió con un dato delante. La
/// huella no es temporal sino **causal**: describe el estado del que dependía el resultado, así que
/// reintenta exactamente cuando algo pudo haber cambiado y no reintenta cuando no.
enum FXRepairQueueLogic {

    /// Estado del que depende el resultado del barrido: cuántas transacciones hay en la cola y
    /// **cuántas de sus fechas siguen sin la tasa que necesitan**.
    ///
    /// **La segunda mitad se mide sobre el disco a propósito, y la primera versión de este fichero se
    /// equivocó justo ahí.** Contaba un contador de escrituras de `persistRate`, y eso deja fuera todo
    /// lo que llega SIN pasar por nuestro código: `ExchangeRate` está espejado por CloudKit y también
    /// lo escribe el applier del Modo Nube. Un dispositivo podía tener ya en disco la fila que cura su
    /// cola —bajada del otro teléfono— y saltarse el barrido porque «no se había persistido nada».
    /// Preguntar por la cobertura observada no tiene ese punto ciego: da igual quién escribiera la
    /// fila.
    ///
    /// Y contar filas tampoco habría servido: `persistRate` FUSIONA sobre la fila existente, así que
    /// completar una fila parcial —el caso que llena la cola— no cambia cuántas filas hay.
    static func fingerprint(provisionalCount: Int, uncoveredDateCount: Int) -> String {
        "\(provisionalCount)|\(uncoveredDateCount)"
    }

    /// ¿Saltarse el barrido? Solo si el estado es idéntico al del último intento que no curó nada.
    ///
    /// Sin huella guardada (primer arranque, o el último barrido SÍ movió algo) siempre se corre. La
    /// huella se escribe **únicamente** cuando un intento COMPLETO no sirvió de nada: si alguna
    /// petición falló por red, o si el guardado no llegó a disco, el resultado es indeterminado y no
    /// se sella nada — sellar ahí convertiría un problema transitorio en una transacción que se queda
    /// mal hasta que el estado cambie por su cuenta.
    static func shouldSkipSweep(current: String, lastFutile: String?) -> Bool {
        guard let lastFutile else { return false }
        return current == lastFutile
    }
}
