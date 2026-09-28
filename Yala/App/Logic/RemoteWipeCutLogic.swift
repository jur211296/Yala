//
//  RemoteWipeCutLogic.swift
//  Yala
//
//  Qué se lleva el «Vaciar datos» de OTRO dispositivo cuando este lo procesa tarde.
//

import Foundation

/// **El corte del borrado reactivo: se va lo que existía al vaciar, se queda lo que se creó después** (ticket
/// `late-remote-wipe-signal-also-wipes-rows-created-after-it`).
///
/// La señal de «Vaciar datos» es una hora en el iCloud-KV del Apple ID (`lastWipeTimestamp`, reloj del origen). Hasta el
/// 2026-09-28 el receptor la usaba solo para saber si era nueva y borraba TODO: si procesaba la señal tarde —estaba
/// cerrado desde antes del vaciado— se llevaba también lo que el origen había apuntado después, y ese borrado viajaba por
/// el espejo al origen. «Vaciar datos» promete vaciar lo que había, no lo que la persona hizo luego en otro dispositivo.
///
/// **Tres clases de fila, y cada una con su prueba:**
///  - **Con fecha de creación** (`createdAt`, que nace con la fila y en producción nadie reescribe; `lastApprovedAt` en
///    `MerchantMemory`, que nace con ella y solo avanza): se va si es ≤ la señal. Una fila que existía al vaciar la borró
///    el origen; una posterior la creó alguien después.
///  - **Derivada de lo que se va**: un borrador que el arranque de ESTE dispositivo sacó de un pago programado viejo nace
///    después de la señal, pero es lo que se vació. Se va con su pago.
///  - **Sin fecha** (`Account`, `Category`, `Subcategory`, `ExchangeRate`): se decide por quién la usa. Ver `takesUndated`.
enum RemoteWipeCutLogic {

    struct Cut: Equatable {
        /// La hora de la señal que se está procesando.
        let signaledAt: Date
        /// Algún dispositivo terminó el onboarding DESPUÉS de la señal (`lastOnboardingTimestamp > lastWipeTimestamp`, el
        /// `skipOnboarding` del drenaje): el parque ya tiene una vida nueva, con su semilla de categorías y sus cuentas.
        let fleetStartedOver: Bool
    }

    /// El corte, o `nil` si no lo hay. **Sin hora de señal (≤ 0) no hay corte y el borrado es entero**, como antes: no hay
    /// con qué separar lo de antes de lo de después, y conservar lo que no se puede fechar dejaría el vaciado a medias.
    static func cut(signaledAt: Date, fleetStartedOver: Bool) -> Cut? {
        guard signaledAt.timeIntervalSince1970 > 0 else { return nil }
        return Cut(signaledAt: signaledAt, fleetStartedOver: fleetStartedOver)
    }

    /// Una fila con fecha se va si existía al vaciar. El mismo instante cuenta como anterior: se crea «después» de la
    /// señal lo que tiene una hora estrictamente mayor.
    static func takesDated(createdAt: Date, cut: Cut) -> Bool {
        createdAt <= cut.signaledAt
    }

    /// **El parque empezó de nuevo si lo dice la marca o si lo dicen las filas** (review adversarial, lente de sync). La
    /// marca (`lastOnboardingTimestamp` del KV) se congela al DETECTAR la señal y viaja por otro canal que las filas: el
    /// espejo puede traer la semilla y la cuenta nuevas del origen antes que la marca. Una fila personal posterior a la
    /// señal es la misma prueba, medida en el store. **No cuentan** los borradores, las memorias de comercio ni las filas
    /// de grupo: los crea el arranque de ESTE dispositivo antes de procesar la señal (Apple Pay, pagos programados, el
    /// bridge), sin que nadie haya empezado nada. `personalRowsCreatedAt` son solo las que sí cuentan.
    static func startedOver(_ cut: Cut, personalRowsCreatedAt: [Date]) -> Cut {
        guard !cut.fleetStartedOver else { return cut }
        let evidence = personalRowsCreatedAt.contains { !takesDated(createdAt: $0, cut: cut) }
        return Cut(signaledAt: cut.signaledAt, fleetStartedOver: evidence)
    }

    /// Un borrador se va si lo hace ir su fecha, o si deriva de un pago programado que se va.
    static func takesDraft(createdAt: Date, sourceScheduledPaymentID: String?,
                           takenScheduledPaymentIDs: Set<String>, cut: Cut) -> Bool {
        if takesDated(createdAt: createdAt, cut: cut) { return true }
        guard let source = sourceScheduledPaymentID else { return false }
        return takenScheduledPaymentIDs.contains(source)
    }

    /// **Una fila sin fecha, por quién la usa.** «Usa» es una relación desde una fila con fecha, y los borradores y las
    /// memorias de comercio **no protegen** lo que usan: son una pregunta pendiente y una pista, y el arranque de este
    /// dispositivo los crea sobre cuentas y subcategorías viejas antes de procesar la señal. Si protegieran, una categoría
    /// vieja que se queda impediría la semilla del onboarding y el espejo se la llevaría después: sin ninguna categoría.
    /// Sí cuentan como uso de lo que se va.
    ///  1. **La usa algo que se queda ⇒ se queda.** Sin eso, el gasto nuevo sobrevive sin cuenta ni categoría (todas las
    ///     relaciones son `.nullify`) y el saldo del origen deja de cuadrar.
    ///  2. **Solo la usa lo que se va ⇒ se va.** Es del corpus de antes: lo nuevo no puede apuntar a lo que el origen ya
    ///     había borrado.
    ///  3. **No la usa nadie ⇒ se queda solo si el parque ya empezó de nuevo.** Con un onboarding posterior a la señal, lo
    ///     no usado es sobre todo la semilla nueva del origen (sus categorías sin gastos todavía, una cuenta recién creada):
    ///     llevársela la borraría del origen, y su semilla no vuelve a correr. Lo viejo que quede así lo retira el espejo al
    ///     traer los borrados del origen. **Sin ese onboarding se va, como antes**: este dispositivo vuelve al Welcome, y si
    ///     conservara las categorías viejas la semilla no correría (`seedCategoriesIfNeeded` exige cero) y el espejo se
    ///     las llevaría después — sin ninguna categoría.
    ///
    /// `parentTaken` es para la subcategoría: si su categoría se va y a ella no la usa nada que se quede, se va con su
    /// categoría — si no, quedaría suelta, sin categoría.
    static func takesUndated(usedByKept: Bool, usedByTaken: Bool, parentTaken: Bool = false, cut: Cut) -> Bool {
        if usedByKept { return false }
        if usedByTaken || parentTaken { return true }
        return !cut.fleetStartedOver
    }
}
