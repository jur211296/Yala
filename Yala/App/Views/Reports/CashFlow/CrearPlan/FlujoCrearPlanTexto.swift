//
//  FlujoCrearPlanTexto.swift
//  Yala
//
//  Los textos de crear el plan del flujo de caja (`flujoCrearPlan.*` en `FlujoCrearPlan.strings`, los 16 idiomas),
//  leídos con el idioma de la app (variante → padre → main → la clave), como `L10n.FlujoCambiarLimite`.
//

import Foundation

extension L10n {
    enum FlujoCrearPlan {
        static let tabla = "FlujoCrearPlan"

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

        private static func s(_ key: String) -> String { string("flujoCrearPlan.\(key)") }
        private static func f(_ key: String, _ args: CVarArg...) -> String {
            String(format: s(key), locale: AppLocale.current, arguments: args)
        }

        // MARK: Cabecera: se parte del saldo de las cuentas (P5)

        static var tienesHoy: String { s("hero.label") }

        /// Debajo de la cifra: en cuántas cuentas está y que el plan parte de ahí.
        static func pie(cuentas: Int) -> String {
            switch cuentas {
            case 0: return s("hero.caption.none")
            case 1: return s("hero.caption.one")
            default: return f("hero.caption.other", cuentas)
            }
        }

        // MARK: Grupos por categoría

        static var sinCategoria: String { s("group.uncategorized") }
        static var desplegado: String { s("group.expanded") }
        static var plegado: String { s("group.collapsed") }
        /// «2 de 3 elegidas».
        static func elegidas(_ elegidas: Int, de total: Int) -> String { f("group.selected", elegidas, total) }

        // MARK: Límite fijo (P4)

        static var limitesFijos: String { s("limits.note") }

        // MARK: Agregar línea › Desde mis gastos

        static var calcularCon: String { s("addLine.seed") }
        static func limiteAlMes(esIngreso: Bool) -> String {
            s(esIngreso ? "addLine.limit.income" : "addLine.limit.expense")
        }
        static var eligeSubcategoria: String { s("addLine.pickSubcategory") }

        /// Las claves que la pantalla usa, para la prueba de que existen en los 16 idiomas.
        static let claves: [String] = [
            "flujoCrearPlan.hero.label",
            "flujoCrearPlan.hero.caption.none",
            "flujoCrearPlan.hero.caption.one",
            "flujoCrearPlan.hero.caption.other",
            "flujoCrearPlan.group.uncategorized",
            "flujoCrearPlan.group.expanded",
            "flujoCrearPlan.group.collapsed",
            "flujoCrearPlan.group.selected",
            "flujoCrearPlan.limits.note",
            "flujoCrearPlan.addLine.seed",
            "flujoCrearPlan.addLine.limit.expense",
            "flujoCrearPlan.addLine.limit.income",
            "flujoCrearPlan.addLine.pickSubcategory",
        ]
    }
}
