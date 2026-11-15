//
//  WidgetColors.swift
//  YalaWidgets
//
//  Semantic colors for widgets, aligned with main app design system.
//  Mirrors the Yala color palette for consistent brand experience.
//

import SwiftUI

/// Semantic colors for widget UI elements
/// Aligned with main app: electricIndigo, hotPink, priorityNeed (teal)
enum WidgetColors {
    // MARK: - Brand Colors (from UIHelpers.swift)

    /// Primary brand color (Electric Indigo #6063F1). Copia de `Color.electricIndigo` de la app: este target no la ve.
    /// La paridad la fija `BrandAccentContrastTests`.
    static let primary = Color(hex: "6063F1")

    /// Electric Indigo - Primary accent, balance positive (#6063F1)
    static let electricIndigo = primary

    /// Hot Pink - Expenses (#FF0080)
    static let hotPink = Color(hex: "FF0080")

    /// Yala Teal - Income (#00C2CB)
    static let yalaTeal = Color(hex: "00C2CB")

    // MARK: - Financial Semantics

    /// Income indicator (teal)
    static let income = yalaTeal

    /// Expense indicator (hot pink)
    static let expense = hotPink

    /// Balance positive (indigo)
    static let balance = electricIndigo

    /// Balance negative / error (red)
    static let negative = Color(hex: "EF4444")

    // MARK: - Status Colors

    /// Warning state (amber)
    static let warning = Color(hex: "F59E0B")

    /// Lo estimado (decisión 34 de 2.3): el tramo punteado de «Mostrar proyectado» y el punto de su cifra corta, en Gasto
    /// y en Saldo. Propio, para no confundirse con el rosa de lo gastado, el índigo del saldo ni el gris del período
    /// anterior. Solo relleno y trazo: el texto de la cifra va en `.secondary`.
    static let estimate = warning

    /// Success state (green)
    static let success = Color(hex: "22C55E")

    /// Accent color (indigo)
    static let accent = electricIndigo

    /// Overdue/error state (red)
    static let overdue = negative

    // MARK: - Helpers

    /// Color for balance based on sign
    static func forBalance(_ value: Double) -> Color {
        value >= 0 ? balance : negative
    }

    /// Color for cash flow based on sign
    static func forCashFlow(_ value: Double) -> Color {
        if value > 0 { return income }
        if value < 0 { return expense }
        return .secondary
    }

    /// Budget progress color based on percentage used
    static func forBudget(percentUsed: Double) -> Color {
        percentUsed >= 100 ? hotPink : electricIndigo
    }

    // MARK: - Trend Charts

    /// Trend line color based on current balance
    static func trendLine(balance: Double) -> Color {
        balance >= 0 ? accent : negative
    }

    /// Trend fill color (with opacity)
    static func trendFill(balance: Double) -> Color {
        trendLine(balance: balance).opacity(0.15)
    }

    /// Income trend line
    static let trendIncome = income

    /// Expense trend line
    static let trendExpense = expense

    // MARK: - Rediseño 2.2 (espejo de la app, `WidgetDesignSystemParityTests`)
    //
    // La paleta de arriba es para RELLENOS (barras, gráficas, insignias): como texto sobre la tarjeta blanca no llega
    // al AA. El texto con color usa los tres de abajo, los mismos de la app.

    // MARK: - Fondo con profundidad (`WidgetCardBackground`, 2026-11-03)
    //
    // Ya no es el `card` de la app: con el gris de sistema, el widget oscuro subía al gris «elevado» (#3A3A3C) y se veía
    // plano junto a los de Apple. Colores fijos, medidos contra los textos de color: el punto más claro del degradado
    // oscuro y el más oscuro del claro siguen dando 4,5:1 a `alertText` y `accentText` (lo fija
    // `WidgetDesignSystemParityTests`).

    /// Arriba del degradado: blanco en claro; casi negro con un punto de índigo en oscuro, como el widget de batería.
    static let cardTop = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Color(hex: "121320")) : UIColor(Color(hex: "FFFFFF"))
    })

    /// Abajo del degradado: un gris perla apenas visible en claro (más oscuro, el índigo bajaría de 4,5:1) y casi negro
    /// en oscuro.
    static let cardBottom = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Color(hex: "08080D")) : UIColor(Color(hex: "FDFDFE"))
    })

    /// El borde fino: iluminado arriba y apagado abajo en oscuro (luz que cae de arriba); un gris tenue y casi parejo en
    /// claro, donde un borde blanco no se vería.
    static let cardEdgeTop = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.16) : UIColor(white: 0, alpha: 0.07)
    })
    static let cardEdgeBottom = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.04) : UIColor(white: 0, alpha: 0.05)
    })

    /// Ingreso como TEXTO (`Color.incomeAmount`): #0F7A80 en claro (5,1:1 sobre blanco) y el turquesa de marca en oscuro.
    static let incomeText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Color(hex: "00C2CB")) : UIColor(Color(hex: "0F7A80"))
    })

    /// «Te pasaste» y lo que avisa como TEXTO (`Color.overBudgetText`): #D6006B en claro (5,2:1), el rosa de marca en
    /// oscuro.
    static let alertText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Color(hex: "FF0080")) : UIColor(Color(hex: "D6006B"))
    })

    /// Índigo como TEXTO o icono sobre la tarjeta (`Color.electricIndigo` en claro, 4,61:1) y, en oscuro, el índigo
    /// claro de los temas oscuros (#818CF8): el de marca da 3,2:1 sobre #1C1C1E.
    static let accentText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Color(hex: "818CF8")) : UIColor(Color(hex: "6063F1"))
    })

    /// «Debes» en Grupos como TEXTO (`Color.groupOweAmount`): rosa de marca, #C80066 en claro y #FF4DA6 en oscuro. Solo en
    /// el widget de Grupos: es el color de la lista de Grupos (decisión de Jürgen, 2026-10-30).
    static let groupOweText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Color(hex: "FF4DA6")) : UIColor(Color(hex: "C80066"))
    })

    /// «Te deben» en Grupos como TEXTO (`Color.groupOwedAmount`): verde, #15803D en claro y #4ADE80 en oscuro.
    static let groupOwedText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Color(hex: "4ADE80")) : UIColor(Color(hex: "15803D"))
    })

    /// Rellenos sólidos con texto blanco encima (los de la app): índigo profundo (`selectedIndigoFill`, 8,8:1), rosa
    /// profundo (`emphasisPinkFill`, 5,2:1) y turquesa profundo (`incomeFill`, 5,1:1).
    static let indigoFill = Color(hex: "3D36B3")
    static let pinkFill = Color(hex: "D6006B")
    static let tealFill = Color(hex: "0F7A80")

    /// El carril de una barra o de un aro: el primario muy tenue, para que se vea igual en claro y en oscuro.
    static let track = Color.primary.opacity(WidgetDS.Opacity.subtle)

    /// El gris de la fila «Otros» de una tarta: `AppConstants.othersColorHex`, el de la tarta del Panel.
    static let othersFill = Color(hex: "8E8E93")

    /// Color de un hex que puede faltar o venir mal: el índigo de marca por defecto.
    static func fill(hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return electricIndigo }
        return Color(hex: hex)
    }
}
