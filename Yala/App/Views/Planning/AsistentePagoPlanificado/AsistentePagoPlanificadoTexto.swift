//
//  AsistentePagoPlanificadoTexto.swift
//  Yala
//
//  Los textos propios del asistente de «Nuevo pago planificado» (`asistentePago.*` en `AsistentePagoPlanificado.strings`,
//  los 16 idiomas), leídos con el idioma de la app (variante → padre → main → la clave), como `AsistenteCreacionTexto`.
//  Los del contenedor («Usar formulario», «Paso 2 de 7», descartar) son los compartidos; las respuestas de tipo, día y
//  aviso vienen de Primeros pasos (`L10n.PrimerosPasos23.Payment`).
//

import Foundation

extension L10n {
    enum AsistentePagoPlanificado {
        static let tabla = "AsistentePagoPlanificado"

        static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
            let sentinel = "__YALA_MISSING__"
            var value = resolution.bundle.localizedString(forKey: key, value: sentinel, table: tabla)
            if value == sentinel, let parent = resolution.parentBundle {
                value = parent.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            if value == sentinel {
                value = Bundle.main.localizedString(forKey: key, value: sentinel, table: tabla)
            }
            return value == sentinel ? key : value
        }

        private static func s(_ key: String) -> String { string("asistentePago.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: LanguageManager.resolved.locale, arguments: args)
        }

        /// Lo que se crea, encima del progreso: el mismo título que el formulario.
        static var titulo: String { NSLocalizedString("scheduled.new", comment: "") }
        static var descartarTitulo: String { s("discard.title") }
        static var crear: String { s("create") }
        /// «Crear», a tamaños de accesibilidad: «Crear pago» puede no caber junto a Atrás en un iPhone SE.
        static var crearCorto: String { s("createShort") }

        static var nombrePregunta: String { s("name.question") }
        static var nombreDetalle: String { s("name.detail") }
        static var montoPregunta: String { s("amount.question") }
        static var montoDetalle: String { s("amount.detail") }
        static var frecuenciaPregunta: String { s("frequency.question") }
        static var frecuenciaDetalle: String { s("frequency.detail") }

        static func frecuenciaPista(_ frecuencia: FirstScheduledPaymentFlowLogic.Frequency) -> String {
            switch frecuencia {
            case .monthly: return s("frequency.monthlyHint")
            case .weekly: return s("frequency.weeklyHint")
            case .yearly: return s("frequency.yearlyHint")
            case .once: return s("frequency.onceHint")
            }
        }

        static func diaPregunta(_ frecuencia: FirstScheduledPaymentFlowLogic.Frequency) -> String {
            switch frecuencia {
            case .monthly: return s("day.question.monthly")
            case .weekly: return s("day.question.weekly")
            case .yearly: return s("day.question.yearly")
            case .once: return s("day.question.once")
            }
        }

        static var diaDetalle: String { s("day.detail") }
        static var otroDia: String { s("day.other") }
        /// «El día 18».
        static func elDia(_ dia: Int) -> String { f("day.ofMonth", dia) }

        static var resumenPregunta: String { s("summary.question") }
        static var resumenDetalle: String { s("summary.detail") }
        static var resumenTipo: String { s("summary.kind") }
        static var resumenNombre: String { s("summary.name") }
        static var resumenMonto: String { s("summary.amount") }
        static var resumenFrecuencia: String { s("summary.frequency") }
        static var resumenCuando: String { s("summary.when") }
        static var resumenAviso: String { s("summary.reminder") }
        static var sinAviso: String { s("reminder.none") }

        // Lo compartido y «¿Algo más?» (encargo del 21-nov).
        static var compartidoPregunta: String { s("shared.question") }
        static var compartidoDetalle: String { s("shared.detail") }
        static var soloMio: String { s("shared.no") }
        static var soloMioPista: String { s("shared.noHint") }
        /// «3 miembros · PEN».
        static func grupoPista(_ miembros: Int, _ moneda: String) -> String { f("shared.groupHint", miembros, moneda) }
        static var repartoPregunta: String { s("split.question") }
        static var repartoDetalle: String { s("split.detail") }
        static var repartoMoneda: String { s("split.currency") }
        static var repartoDivision: String { s("split.division") }
        static var repartoCambiar: String { s("split.change") }
        static var algoMasPregunta: String { s("extra.question") }
        static var algoMasDetalle: String { s("extra.detail") }
        static var algoMasCuenta: String { s("extra.account") }
        static var algoMasNota: String { s("extra.note") }
        static var algoMasEtiquetas: String { s("extra.tags") }
        static var algoMasTermina: String { s("extra.ends") }
        static var algoMasUltimoPago: String { s("extra.endDate") }
        static var resumenCompartido: String { s("summary.shared") }
        static var resumenDivision: String { s("summary.split") }
        static var resumenCuenta: String { s("summary.account") }
        static var resumenNota: String { s("summary.note") }
        static var resumenEtiquetas: String { s("summary.tags") }
        static var resumenTermina: String { s("summary.ends") }
        static var resumenEstado: String { s("summary.status") }
        static var pausado: String { s("summary.paused") }
        /// En el formulario, bajo la fila que falta tras tocar ✓.
        static var faltaGrupo: String { s("missing.group") }
        static var faltaDivision: String { s("missing.division") }
    }
}
