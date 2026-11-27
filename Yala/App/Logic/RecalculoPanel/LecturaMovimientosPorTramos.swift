//
//  LecturaMovimientosPorTramos.swift
//  Yala
//
//  Lote 7 de eficiencia (27-nov-2026). La lectura de TODOS los movimientos por tramos, reanudable: cada `leerTramo()` lee
//  uno y dice si terminó. La escribió YALA-IOS-K (2026-11-13) dentro de `PanelViewModel.fetchTransactionsInSlices`; aquí
//  vive una vez para el Panel y para la foto de los widgets, que leía los 16.004 movimientos del iPhone 14 de una vez en
//  su primera etapa (~0,41 s de hilo principal en el arranque en frío).
//
//  Cada tramo sigue al anterior por su CLAVE de orden, no por posición: lo que se guarde entre dos tramos no desplaza a
//  los siguientes. La clave se repite (importaciones, recurrentes con el mismo instante), así que cada tramo vuelve a pedir
//  la del último y lo ya leído se descarta por su identidad: ni salta filas ni las cuenta dos veces. Si un tramo entero es
//  de la misma clave y no trae nada nuevo, no hay forma de avanzar por clave y se lee el resto de una vez.
//
//  La lectura termina cuando un tramo no trae nada nuevo, no cuando trae menos de `tamano`: con cambios sin guardar en el
//  contexto un tramo puede traer una fila de más o de menos, y cortar por la cuenta dejaría fuera el resto del historial.
//  Lo que se borró mientras se leía se descarta al final (`vivos`): leer un `@Model` borrado aborta en el iPhone.
//

import Foundation
import SwiftData

@MainActor
final class LecturaMovimientosPorTramos {

    /// El orden de la lectura: del más nuevo al más viejo, lo que necesitan la tendencia, los saldos y la foto.
    static var orden: [SortDescriptor<TransactionItem>] {
        [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
    }

    private let context: ModelContext
    private let tamano: Int
    private var leidos: [TransactionItem] = []
    private var vistos = Set<PersistentIdentifier>()
    private var frontera: (date: Date, createdAt: Date)?

    /// Tramos leídos.
    private(set) var tramos = 0
    /// `true` cuando ya no hay más que leer (o falló una lectura).
    private(set) var terminada = false
    /// La lectura que falló, si alguna: quien la usa decide (el Panel lee de una vez con su `catch`).
    private(set) var fallo: Error?

    init(context: ModelContext, tamano: Int) {
        self.context = context
        self.tamano = max(tamano, 1)
    }

    /// Lee un tramo. `true` si ya terminó.
    func leerTramo() -> Bool {
        guard !terminada else { return true }
        var descriptor = FetchDescriptor<TransactionItem>(sortBy: Self.orden)
        if let frontera {
            let date = frontera.date
            let createdAt = frontera.createdAt
            descriptor.predicate = #Predicate<TransactionItem> {
                $0.date < date || ($0.date == date && $0.createdAt <= createdAt)
            }
        }
        descriptor.fetchLimit = tamano
        let tramo: [TransactionItem]
        do {
            tramo = try context.fetch(descriptor)
        } catch {
            fallo = error
            terminada = true
            return true
        }
        tramos += 1
        var nuevos = 0
        for tx in tramo where vistos.insert(tx.persistentModelID).inserted {
            leidos.append(tx)
            nuevos += 1
        }
        guard let ultimo = tramo.last, nuevos > 0 || tramo.count >= tamano else {
            terminada = true
            return true
        }
        guard nuevos > 0 else {
            // Un tramo entero con la misma clave: no se puede avanzar por clave. El resto, de una vez.
            let date = ultimo.date
            let createdAt = ultimo.createdAt
            var resto = FetchDescriptor<TransactionItem>(sortBy: Self.orden)
            resto.predicate = #Predicate<TransactionItem> {
                $0.date < date || ($0.date == date && $0.createdAt <= createdAt)
            }
            do {
                for tx in try context.fetch(resto) where vistos.insert(tx.persistentModelID).inserted { leidos.append(tx) }
            } catch {
                fallo = error
            }
            terminada = true
            return true
        }
        frontera = (ultimo.date, ultimo.createdAt)
        return false
    }

    /// Lo leído sin lo que se borró mientras se leía.
    var vivos: [TransactionItem] {
        leidos.filter { !$0.isDeleted && $0.modelContext != nil }
    }
}
