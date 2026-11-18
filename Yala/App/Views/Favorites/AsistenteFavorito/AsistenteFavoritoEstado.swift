//
//  AsistenteFavoritoEstado.swift
//  Yala
//
//  Lo respondido en el asistente de «Nuevo favorito» y por dónde va. Lo crea QUIEN PRESENTA la hoja
//  (`FavoritesListView`) y lo olvida en su `onDismiss`: el contenido de una hoja puede rehacerse sin cerrarla y su
//  `@State` nace de cero (`swiftui-ds.md`). Cada pregunta llega con lo sugerido ya elegido.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AsistenteFavoritoEstado {
    typealias Logica = AsistenteFavoritoLogica

    enum Modo: Equatable {
        case asistente
        /// «Usar formulario»: el formulario de siempre, con lo respondido (nada si aún no se respondió nada).
        case formulario(FavoriteWizardPrefill?)
    }

    private(set) var modo: Modo = .asistente
    var navegador = AsistenteCreacionNavegador<Logica.Paso>(inicio: .tipo)
    /// Los tipos que se ofrecen («Solo gastos»: solo Gasto, y la pregunta del tipo no sale).
    private(set) var tiposDisponibles: [TransactionType] = [.expense, .income, .transfer]

    var tipo: TransactionType = .expense
    /// `nil`: «Sin categoría».
    var subcategoriaID: PersistentIdentifier?
    var nombre = ""
    /// La persona escribió el nombre: deja de seguir al propuesto cuando cambia la categoría.
    var nombreEditado = false
    /// El monto tal cual se escribe (con separadores). Vacío: se pone al usarlo.
    var montoTexto = ""
    var origenID: PersistentIdentifier?
    var destinoID: PersistentIdentifier?
    /// Ya se preparó para esta apertura de la hoja: un contenido rehecho no vuelve a empezar.
    private(set) var preparado = false

    init() {}

    var pasos: [Logica.Paso] {
        Logica.pasos(tipo: tipo, tiposDisponibles: tiposDisponibles.count)
    }

    /// Arranca de cero con lo sugerido. `cuentaSugerida`: la del último registro (o la única).
    func empezar(tiposDisponibles: [TransactionType], cuentaSugerida: PersistentIdentifier?) {
        self.tiposDisponibles = tiposDisponibles.isEmpty ? [.expense] : tiposDisponibles
        modo = .asistente
        tipo = self.tiposDisponibles.contains(.expense) ? .expense : self.tiposDisponibles[0]
        subcategoriaID = nil
        nombre = ""
        nombreEditado = false
        montoTexto = ""
        origenID = cuentaSugerida
        destinoID = nil
        navegador = AsistenteCreacionNavegador(inicio: pasos.first ?? .nombre)
        preparado = true
    }

    /// Al aparecer la hoja: empieza solo si esta apertura aún no empezó (un contenido rehecho conserva lo respondido).
    func prepararSiHaceFalta(tiposDisponibles: [TransactionType], cuentaSugerida: () -> PersistentIdentifier?) {
        guard !preparado else { return }
        empezar(tiposDisponibles: tiposDisponibles, cuentaSugerida: cuentaSugerida())
    }

    /// Al cerrarse la hoja: lo respondido se tira ya (la próxima apertura no lo enseña ni un instante).
    func olvidar() {
        empezar(tiposDisponibles: tiposDisponibles, cuentaSugerida: nil)
        preparado = false
    }

    /// Cambiar de tipo: la categoría es de un tipo (gasto o ingreso) y una transferencia no la lleva.
    func elegirTipo(_ nuevo: TransactionType) {
        guard nuevo != tipo else { return }
        tipo = nuevo
        subcategoriaID = nil
        if !nombreEditado { nombre = "" }
    }

    var respuestas: Logica.Respuestas<PersistentIdentifier> {
        Logica.Respuestas(tipo: tipo, nombre: nombre, montoTexto: montoTexto, origen: origenID, destino: destinoID)
    }

    var puedeSeguir: Bool { Logica.puedeSeguir(en: navegador.actual, respuestas) }

    /// «Usar formulario»: con algo respondido pasa lo respondido; sin nada, el formulario vacío de siempre.
    func usarFormulario() {
        let prefill = navegador.tieneRespuestas
            ? Logica.alFormulario(tipo: tipo, nombre: nombre, montoTexto: montoTexto, subcategoria: subcategoriaID,
                                  origen: origenID, destino: destinoID)
            : nil
        modo = .formulario(prefill)
    }
}
