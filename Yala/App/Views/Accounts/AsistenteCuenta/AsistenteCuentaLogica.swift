//
//  AsistenteCuentaLogica.swift
//  Yala
//
//  Las reglas, sin vista, del asistente de «Nueva cuenta» (encargo del 18-nov): qué preguntas tocan con lo respondido,
//  cuándo se puede seguir, lo que se guarda y lo que pasa al formulario con «Usar formulario». Las preguntas son las de
//  «Primera cuenta» (`FirstAccountFlowLogic`), con una sola moneda, como el formulario: el formulario no admite otras
//  monedas al crear, así que no podrían pasar a «Usar formulario» sin perderse. La vista es `AsistenteCuentaView`; lo
//  respondido vive en `AsistenteCuentaEstado`.
//

import Foundation

nonisolated enum AsistenteCuentaLogica {

    enum Paso: String, Hashable, CaseIterable {
        /// ¿Qué tipo de cuenta es?
        case tipo
        /// ¿En qué moneda está este dinero? (en tarjeta, «¿En qué moneda usas esta tarjeta?»).
        case moneda
        /// ¿Cómo la llamamos?
        case nombre
        /// ¿Cuánto tienes hoy? (en tarjeta, «¿Cuánto debes hoy?»).
        case saldo
        /// ¿Qué día cierra tu tarjeta? Solo en tarjeta.
        case cierre
        /// ¿Hasta qué día puedes pagarla? Solo en tarjeta.
        case pago
        /// ¿Cuándo te recordamos pagarla? Solo en tarjeta y sabiendo el día de pago.
        case recordatorio
        /// ¿La creamos así? (el resumen, que crea).
        case resumen
    }

    typealias Tipo = FirstAccountFlowLogic.Kind

    /// El tipo que llega marcado: la cuenta del banco, la más común después de la primera.
    static let tipoSugerido: Tipo = .checking

    /// Las preguntas, en orden, con lo respondido.
    static func pasos(tipo: Tipo, diaDePago: Int?) -> [Paso] {
        var pasos: [Paso] = [.tipo, .moneda, .nombre, .saldo]
        if tipo.isCard {
            pasos += [.cierre, .pago]
            if diaDePago != nil { pasos.append(.recordatorio) }
        }
        pasos.append(.resumen)
        return pasos
    }

    /// Lo contestado, para decidir si «Siguiente» se enciende y para guardar.
    struct Respuestas: Equatable {
        var tipo: Tipo = AsistenteCuentaLogica.tipoSugerido
        var moneda: String = "USD"
        var nombre: String = ""
        /// El saldo escrito, ya leído y sin signo (vacío = 0). `nil` = lo escrito no se lee como número.
        var saldo: Double? = 0
        /// El botón − junto al saldo (no en tarjeta: ahí lo escrito es siempre lo que se debe).
        var saldoNegativo = false
        var diaDeCierre: Int?
        var diaDePago: Int?
        /// Días antes del pago; `nil` = «No me lo recuerdes».
        var recordatorio: Int?
    }

    static func puedeSeguir(en paso: Paso, _ r: Respuestas, nombresExistentes: [String]) -> Bool {
        switch paso {
        case .tipo, .moneda, .cierre, .pago, .recordatorio:
            return true
        case .nombre:
            return nombreValido(r.nombre, existentes: nombresExistentes)
        case .saldo:
            return r.saldo != nil
        case .resumen:
            // Todo lo obligatorio, por si algo se vació al volver atrás.
            return nombreValido(r.nombre, existentes: nombresExistentes) && r.saldo != nil
        }
    }

    static func nombreLimpio(_ nombre: String) -> String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Con texto y sin repetir el de otra cuenta (sin mirar mayúsculas), la misma regla que el formulario
    /// (`AccountFormViewModel.isNameUnique`).
    static func nombreValido(_ nombre: String, existentes: [String]) -> Bool {
        let limpio = nombreLimpio(nombre)
        guard !limpio.isEmpty else { return false }
        return !nombreRepetido(limpio, existentes: existentes)
    }

    static func nombreRepetido(_ nombre: String, existentes: [String]) -> Bool {
        let buscado = nombreLimpio(nombre).lowercased()
        guard !buscado.isEmpty else { return false }
        return existentes.contains { nombreLimpio($0).lowercased() == buscado }
    }

    /// Un nombre libre para el tipo: el propuesto y, si ya hay una cuenta con ese nombre, «Efectivo 2», «Efectivo 3»…
    static func nombreLibre(_ propuesto: String, existentes: [String]) -> String {
        guard nombreRepetido(propuesto, existentes: existentes) else { return propuesto }
        var n = 2
        while nombreRepetido("\(propuesto) \(n)", existentes: existentes) { n += 1 }
        return "\(propuesto) \(n)"
    }

    /// El saldo que se guarda, con su signo: en tarjeta lo que se debe va en negativo, como en el formulario.
    static func saldoGuardado(_ r: Respuestas) -> Double {
        let valor = r.saldo ?? 0
        return FirstAccountFlowLogic.storedBalance(kind: r.tipo, magnitude: valor, isNegative: r.saldoNegativo)
    }

    /// Las opciones de «¿Cuándo te recordamos pagarla?»: el mismo día, 1, 3 o 5 días antes; sin día de cierre, solo el
    /// mismo día (`FirstAccountFlowLogic.reminderOptions`).
    static func opcionesDeRecordatorio(diaDeCierre: Int?) -> [Int] {
        FirstAccountFlowLogic.reminderOptions(statementDay: diaDeCierre)
    }

    /// El recordatorio que llega marcado: un día antes; sin día de cierre, el mismo día (la única opción).
    static func recordatorioSugerido(diaDeCierre: Int?) -> Int {
        let opciones = opcionesDeRecordatorio(diaDeCierre: diaDeCierre)
        return opciones.contains(1) ? 1 : (opciones.first ?? 0)
    }

    /// Lo que guarda `FirstAccountCreator`: una sola moneda, el saldo con su signo y, en tarjeta, los días. Un día que no
    /// se sabe va como «No lo sé». En el actor principal, como `FirstAccountDraft`.
    @MainActor
    static func borrador(_ r: Respuestas) -> FirstAccountDraft {
        var draft = FirstAccountDraft(mainCurrency: r.moneda.uppercased())
        draft.kind = r.tipo
        draft.name = nombreLimpio(r.nombre)
        let saldo = saldoGuardado(r)
        draft.balances = saldo == 0 ? [:] : [r.moneda.uppercased(): saldo]
        if r.tipo.isCard {
            draft.statementDay = r.diaDeCierre.map { .day($0) } ?? .unknown
            draft.paymentDay = r.diaDePago.map { .day($0) } ?? .unknown
            draft.reminderLead = r.diaDePago == nil ? nil : r.recordatorio
        }
        return draft
    }

    /// Las monedas que se ofrecen: la principal, las secundarias de Ajustes y, si se eligió otra con «Otra moneda», esa.
    /// Sin repetir y en mayúsculas.
    static func opcionesDeMoneda(principal: String, secundarias: [String], elegida: String) -> [String] {
        var vistas = Set<String>()
        return ([principal] + secundarias + [elegida])
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty && vistas.insert($0).inserted }
    }

    // MARK: - Al formulario

    /// Lo respondido, tal cual lo recibe el formulario. Un nombre aún vacío no se pasa (el formulario lo pide), y el saldo
    /// solo si ya se contestó o se escribió: si no, el formulario lo pide como siempre («Escribe tu saldo (o 0)»).
    static func alFormulario(_ r: Respuestas, saldoRespondido: Bool) -> AccountFormPrefill {
        let saldo = abs(r.saldo ?? 0)
        let esTarjeta = r.tipo.isCard
        let pasaSaldo = saldoRespondido && r.saldo != nil
        let recordatorio = esTarjeta && r.diaDePago != nil ? r.recordatorio : nil
        return AccountFormPrefill(
            name: nombreLimpio(r.nombre),
            kind: r.tipo,
            currencyCode: r.moneda.uppercased(),
            balanceMagnitude: pasaSaldo ? saldo : nil,
            // En tarjeta lo que se debe es «Consumido» (negativo) en el formulario; en las demás, el botón −.
            balanceIsNegative: saldo != 0 && (esTarjeta || r.saldoNegativo),
            statementDay: esTarjeta ? r.diaDeCierre : nil,
            paymentDay: esTarjeta ? r.diaDePago : nil,
            reminderDaysBefore: recordatorio
        )
    }
}

/// Lo que «Usar formulario» le pasa al formulario de cuenta (lo respondido en el asistente de «Nueva cuenta»).
nonisolated struct AccountFormPrefill: Equatable {
    var name: String
    /// El tipo (el formulario lo pasa a `AccountType`) y, con él, el color de la cuenta.
    var kind: FirstAccountFlowLogic.Kind
    var currencyCode: String
    /// El saldo sin signo; `nil` = aún sin contestar.
    var balanceMagnitude: Double?
    var balanceIsNegative: Bool
    var statementDay: Int?
    var paymentDay: Int?
    /// Días antes del pago; `nil` = sin recordatorio.
    var reminderDaysBefore: Int?
}
