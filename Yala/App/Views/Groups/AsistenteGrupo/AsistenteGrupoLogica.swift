//
//  AsistenteGrupoLogica.swift
//  Yala
//
//  Las reglas, sin vista, del asistente de «Nuevo grupo» (encargo del 17-nov): qué preguntas hay, cuándo se puede
//  seguir, las ideas de nombre (cada una con su icono), los iconos que se ofrecen y lo que pasa al formulario con «Usar
//  formulario». La vista es `AsistenteGrupoView`; lo respondido vive en `AsistenteGrupoEstado`. En el actor principal
//  (el de la app por defecto): lee `GroupFormDefaults` e `ImportarGrupoSeleccion`, que viven ahí.
//

import Foundation

enum AsistenteGrupoLogica {

    enum Paso: String, Hashable, CaseIterable {
        /// ¿Cómo se llama el grupo? (con ideas y «Traer de Splitwise o Tricount»).
        case nombre
        /// ¿Con qué icono lo reconoces?
        case icono
        /// ¿Cómo suelen dividir los gastos?
        case reparto
        /// ¿Juntamos las deudas para que haya menos pagos?
        case deudas
        /// ¿En qué moneda ven lo que se deben?
        case moneda
        /// ¿Lo creamos así? (el resumen, que crea).
        case resumen
    }

    /// Las preguntas, en orden. Ninguna depende de otra: la moneda concreta va DENTRO de su pregunta.
    static let pasos: [Paso] = Paso.allCases

    /// Lo de un grupo recién abierto en el formulario, sin tocar nada: el asistente arranca igual.
    static let iconoPorDefecto = "person.2.fill"
    static let colorPorDefecto = "#8B5CF6"

    // MARK: - Ideas de nombre

    /// Una idea de nombre: tocarla escribe el nombre y, si la persona no eligió icono, propone el suyo.
    enum Idea: String, CaseIterable, Hashable {
        case viaje, casa, pareja, amigos, trabajo

        var icono: String {
            switch self {
            case .viaje: return "airplane"
            case .casa: return "house.fill"
            case .pareja: return "heart.fill"
            case .amigos: return "person.3.fill"
            case .trabajo: return "briefcase.fill"
            }
        }

        var color: String {
            switch self {
            case .viaje: return "#0EA5E9"
            case .casa: return "#F59E0B"
            case .pareja: return "#EC4899"
            case .amigos: return "#6366F1"
            case .trabajo: return "#475569"
            }
        }
    }

    /// Un icono que se ofrece en «¿Con qué icono lo reconoces?», con su color (de la paleta de `IconColorPickerSheet`).
    struct Icono: Hashable {
        let nombre: String
        let color: String
    }

    /// Los iconos de la pregunta: el de siempre primero, los de las ideas y tres de lo que más se comparte.
    static let iconos: [Icono] = [Icono(nombre: iconoPorDefecto, color: colorPorDefecto)]
        + Idea.allCases.map { Icono(nombre: $0.icono, color: $0.color) }
        + [Icono(nombre: "fork.knife", color: "#F97316"),
           Icono(nombre: "car.fill", color: "#22C55E"),
           Icono(nombre: "gift.fill", color: "#D946EF")]

    // MARK: - Lo respondido

    struct Respuestas: Equatable {
        var nombre: String = ""
        var icono: String = iconoPorDefecto
        var color: String = colorPorDefecto
        var reparto: SplitType = .equal
        var menosPagos: Bool = GroupFormDefaults.simplifyDebtsForNewGroup
        var unaSolaMoneda: Bool = false
        var moneda: CurrencyCode = .pen
    }

    static func nombreLimpio(_ nombre: String) -> String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Solo el nombre es obligatorio (como en el formulario); las demás llegan con lo sugerido ya elegido.
    static func puedeSeguir(en paso: Paso, _ r: Respuestas) -> Bool {
        switch paso {
        case .nombre, .resumen:
            return !nombreLimpio(r.nombre).isEmpty
        case .icono, .reparto, .deudas, .moneda:
            return true
        }
    }

    /// Hay algo que se perdería al cerrar: una pregunta pasada con «Siguiente» o un nombre ya escrito en la primera.
    static func tieneAlgo(respondidas: Bool, _ r: Respuestas) -> Bool {
        respondidas || !nombreLimpio(r.nombre).isEmpty
    }

    /// Tocar una idea: el nombre es el de la idea y, si el icono no se eligió a mano, pasa al de la idea. Uno elegido a
    /// mano no se pisa.
    static func aplicar(_ idea: Idea, nombreIdea: String, a r: inout Respuestas, iconoElegidoAMano: Bool) {
        r.nombre = nombreIdea
        guard !iconoElegidoAMano else { return }
        r.icono = idea.icono
        r.color = idea.color
    }

    // MARK: - Al formulario

    /// Lo respondido, tal cual lo recibe el formulario de grupo. Un nombre en blanco llega vacío (sale el ejemplo).
    static func alFormulario(_ r: Respuestas, importacion: ImportarGrupoSeleccion?) -> GroupFormPrefill {
        GroupFormPrefill(
            name: nombreLimpio(r.nombre),
            iconName: r.icono,
            colorHex: r.color,
            splitType: r.reparto,
            simplifyDebts: r.menosPagos,
            showDebtsInSingleCurrency: r.unaSolaMoneda,
            currency: r.moneda,
            importSelection: importacion
        )
    }
}

/// Lo que el asistente le pasa al formulario de grupo con «Usar formulario». El formulario lo lee del entorno
/// (`\.groupFormPrefill`) para que la llamada de la pestaña siga siendo la de siempre (la fija un source-scan).
struct GroupFormPrefill: Equatable {
    var name: String
    var iconName: String
    var colorHex: String
    var splitType: SplitType
    var simplifyDebts: Bool
    var showDebtsInSingleCurrency: Bool
    var currency: CurrencyCode
    var importSelection: ImportarGrupoSeleccion?

    /// Alguna de «Más opciones» no es la de un grupo nuevo: el formulario las abre desplegadas para que se vea.
    var changesMoreOptions: Bool {
        splitType != .equal
            || simplifyDebts != GroupFormDefaults.simplifyDebtsForNewGroup
            || showDebtsInSingleCurrency
    }
}
