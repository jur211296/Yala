//
//  AsistenteFavoritoLogica.swift
//  Yala
//
//  Las reglas, sin vista, del asistente de «Nuevo favorito» (encargo del 17-nov): qué preguntas tocan con el tipo
//  elegido, cuándo se puede seguir, el nombre propuesto y lo que pasa al formulario con «Usar formulario». La vista es
//  `AsistenteFavoritoView`; lo respondido vive en `AsistenteFavoritoEstado`. Se guarda por el camino del formulario
//  (`FavoriteEditorViewModel.saveFavorite`).
//

import Foundation
import SwiftData

enum AsistenteFavoritoLogica {

    enum Paso: String, Hashable, CaseIterable {
        /// ¿Qué quieres guardar? Gasto, ingreso o transferencia.
        case tipo
        /// ¿En qué categoría va? (no en una transferencia).
        case categoria
        /// ¿Cómo lo llamamos?
        case nombre
        /// ¿Cuánto es normalmente? (vacío: se pone al usarlo).
        case monto
        /// ¿Con qué cuenta? (en una transferencia, la de origen).
        case cuenta
        /// ¿A qué cuenta va? (solo en una transferencia).
        case destino
        /// ¿Lo creamos así? (el resumen, que crea).
        case resumen
    }

    /// Las preguntas que tocan con el tipo elegido. Con un solo tipo posible («Solo gastos») no se pregunta el tipo.
    static func pasos(tipo: TransactionType, tiposDisponibles: Int) -> [Paso] {
        let inicio: [Paso] = tiposDisponibles > 1 ? [.tipo] : []
        if tipo == .transfer {
            return inicio + [.nombre, .monto, .cuenta, .destino, .resumen]
        }
        return inicio + [.categoria, .nombre, .monto, .cuenta, .resumen]
    }

    /// Lo contestado, para decidir si «Siguiente» se enciende. Las cuentas van como ids genéricos para probarlo sin
    /// SwiftData.
    struct Respuestas<ID: Equatable>: Equatable {
        var tipo: TransactionType = .expense
        var nombre = ""
        var montoTexto = ""
        var origen: ID?
        var destino: ID?
    }

    static func puedeSeguir<ID: Equatable>(en paso: Paso, _ r: Respuestas<ID>) -> Bool {
        switch paso {
        case .tipo, .categoria, .cuenta:
            return true
        case .nombre:
            return !nombreLimpio(r.nombre).isEmpty
        case .monto:
            return montoValido(r.montoTexto)
        case .destino:
            return cuentasValidas(r)
        case .resumen:
            // Todo lo obligatorio, por si algo se vació al volver atrás.
            return !nombreLimpio(r.nombre).isEmpty && montoValido(r.montoTexto) && cuentasValidas(r)
        }
    }

    static func nombreLimpio(_ nombre: String) -> String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Vacío vale (el favorito pide el monto al usarlo, como en el formulario); escrito, tiene que ser mayor que cero.
    static func montoValido(_ texto: String) -> Bool {
        let limpio = texto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return true }
        return AmountInputHelper.parseDecimal(limpio) > 0
    }

    /// El monto escrito, o `nil` si se deja para cuando se use.
    static func monto(_ texto: String) -> Double? {
        let limpio = texto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return nil }
        let valor = AmountInputHelper.parseDecimal(limpio)
        return valor > 0 ? valor : nil
    }

    /// Una transferencia no va de una cuenta a sí misma (la misma regla que el formulario). Falta una: vale.
    static func cuentasValidas<ID: Equatable>(_ r: Respuestas<ID>) -> Bool {
        FavoriteEditorTransferLogic.accountsAreValid(
            isTransfer: r.tipo == .transfer, origin: r.origen, destination: r.destino)
    }

    // MARK: - Lo sugerido

    /// El nombre que llega escrito: el de la categoría elegida; en una transferencia, «Transferencia». Sin categoría, nada
    /// (la persona lo escribe).
    static func nombrePropuesto(tipo: TransactionType, categoria: String?, transferencia: String) -> String {
        if tipo == .transfer { return transferencia }
        return categoria ?? ""
    }

    /// El destino que llega elegido: el que había si sigue valiendo; si no, la primera cuenta distinta del origen.
    static func destinoSugerido<ID: Equatable>(actual: ID?, origen: ID?, cuentas: [ID]) -> ID? {
        if let actual, actual != origen, cuentas.contains(actual) { return actual }
        return cuentas.first { $0 != origen }
    }

    // MARK: - Al formulario

    /// Lo respondido, tal cual lo recibe el formulario. La categoría y el destino solo si caben en el tipo elegido.
    static func alFormulario(
        tipo: TransactionType,
        nombre: String,
        montoTexto: String,
        subcategoria: PersistentIdentifier?,
        origen: PersistentIdentifier?,
        destino: PersistentIdentifier?
    ) -> FavoriteWizardPrefill {
        let esTransferencia = tipo == .transfer
        return FavoriteWizardPrefill(
            type: tipo,
            name: nombreLimpio(nombre),
            amount: monto(montoTexto),
            subcategoryID: esTransferencia ? nil : subcategoria,
            accountID: origen,
            destinationAccountID: esTransferencia ? destino : nil
        )
    }
}
