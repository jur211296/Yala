//
//  L10n+Lote23ChicoGruposAjustes.swift
//  Yala
//
//  Textos del lote chico de 2.3 de Grupos y Ajustes (decisiones 36, 47 y 48 de la revisión 2.3): la línea al pie de
//  «Menos pagos» en Saldos, «Registros favoritos», «Presupuestos en el Panel» y el subtítulo de «Cómo usas Yala» con
//  «Solo gastos». En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func lote23chico(_ key: String) -> String {
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
    enum Lote23Chico {

        // MARK: - Grupos · «Menos pagos» al pie de Saldos (decisión 36, A1)

        /// «Yala juntó las deudas para que haya menos pagos.»
        static var simplifiedNote: String { lote23chico("groups.lote23chico.simplifiedNote") }
        /// «Ver las deudas de cada par»
        static var showPairs: String { lote23chico("groups.lote23chico.showPairs") }
        /// Con las de cada par a la vista: qué son y que para saldar se vuelve a las juntadas.
        static var pairsNote: String { lote23chico("groups.lote23chico.pairsNote") }
        /// «Ver con menos pagos»
        static var showSimplified: String { lote23chico("groups.lote23chico.showSimplified") }

        // MARK: - Ajustes · filas que abren lo que dicen (decisión 47, B1)

        /// «Registros favoritos» (antes «Favoritos», que se confundía con los presupuestos favoritos).
        static var favoriteRecords: String { lote23chico("settings.lote23chico.favoriteRecords") }
        /// Pie de Organización: dónde están ahora las filas que salieron.
        static var organizationFooter: String { lote23chico("settings.lote23chico.organizationFooter") }
        /// «Presupuestos en el Panel»: la fila de Configurar Panel y el título de la pantalla de las estrellas.
        static var budgetsOnPanel: String { lote23chico("panel.lote23chico.budgetsOnPanel") }
        /// Subtítulo de la fila de Configurar Panel.
        static var budgetsOnPanelHint: String { lote23chico("panel.lote23chico.budgetsOnPanelHint") }

        // MARK: - Ajustes · «Solo gastos» dentro de «Cómo usas Yala» (decisión 48, F1)

        /// Subtítulo de la fila «Cómo usas Yala» con «Solo gastos» encendido: la fila dice el modo entero.
        static var fullExpensesOnly: String { lote23chico("usageMode.lote23chico.fullExpensesOnly") }
    }
}
