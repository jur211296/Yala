//
//  L10n+UXAudit22Lote13Decididas.swift
//  Yala
//
//  Textos del lote decidido 2.2 · 13 (Grupos: crear el primer grupo, educativo, consentimiento y entrar con Apple o
//  Google: L12-6, L12-7, L12-9, L12-12, L13-8), implementadas el 2026-10-21. En su propio fichero, como los de cada lote,
//  para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l13d(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum GroupsCreate {

        // MARK: - L12-6 · la frase de Ajustes de Grupos, pegada a la nota del registro personal

        /// «Si no lo quieres, se apaga en Ajustes de Grupos.»: sigue a la nota del paso 2 del educativo.
        static var bridgeOff: String { l13d("groups.d13.bridgeOff") }

        // MARK: - L12-7 · los dos botones entran o crean

        /// «Si ya tienes cuenta, entras; si no, se crea.»: bajo «Continuar con Apple/Google».
        static var signInEitherWay: String { l13d("groups.d13.signin.eitherWay") }

        // MARK: - L12-9 · el formulario con palabras de persona

        static var namePlaceholder: String { l13d("groups.d13.form.namePlaceholder") }
        static var simplify: String { l13d("groups.d13.form.simplify") }
        static var simplifyHint: String { l13d("groups.d13.form.simplifyHint") }
        static var singleCurrency: String { l13d("groups.d13.form.singleCurrency") }
        static var splitType: String { l13d("groups.d13.form.splitType") }

        // MARK: - L12-12 · el nombre de la persona dentro del formulario de su primer grupo

        static var yourName: String { l13d("groups.d13.form.yourName") }

        // MARK: - L13-8 · «Grupo» del botón + sin grupos

        /// «Para dividir un gasto, primero crea un grupo».
        static var noGroupsTitle: String { l13d("groups.d13.fab.noGroupsTitle") }
        /// «Ahora apunta el gasto»: arriba del gasto que se abre tras crear el grupo.
        static var expenseNowNotice: String { l13d("groups.d13.expense.nowNotice") }
    }
}
