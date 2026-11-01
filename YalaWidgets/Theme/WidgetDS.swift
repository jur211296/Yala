//
//  WidgetDS.swift
//  YalaWidgets
//
//  Espejo del sistema de diseño de la app (`DS`, `Yala/App/Theme/DesignTokens.swift`) para los widgets: los MISMOS
//  nombres y los MISMOS valores, porque este target no compila los ficheros de la app. Un widget nuevo o rediseñado
//  solo usa esto y `WidgetColors`: nada de números sueltos.
//
//  Lo fija `WidgetDesignSystemParityTests`, que compara cada token con el de `DS`. Si cambias uno allí, cámbialo aquí.
//
//  El `WDS` viejo (`WidgetDesignTokens.swift`) se retiró en la tanda 3 del rediseño (S35f2), con los últimos widgets
//  que lo usaban (Categorías y Subcategorías).
//

import SwiftUI

enum WidgetDS {

    // MARK: - Spacing (= DS.Spacing)

    enum Spacing {
        static let none: CGFloat = 0
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: - Radius (= DS.Radius)

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let card: CGFloat = 14
        static let lg: CGFloat = 16
    }

    // MARK: - Opacity (= DS.Opacity)

    enum Opacity {
        static let overlay: Double = 0.4
        static let subtle: Double = 0.1
        static let faint: Double = 0.05
    }

    // MARK: - Icon (= DS.Icon)

    enum Icon {
        /// Insignia pequeña: la de la cabecera y la de las filas compactas.
        static let badgeSmall: CGFloat = 24
        /// Insignia de fila en los tamaños grandes.
        static let badgeMedium: CGFloat = 32
        /// El círculo del icono en los azulejos de entrada rápida.
        static let badgeLarge: CGFloat = 40
        static let sizeSmall: CGFloat = 12
        static let sizeMedium: CGFloat = 16
    }

    // MARK: - Sizing (= DS.Sizing)

    enum Sizing {
        /// Barra de progreso compacta (presupuestos, reparto).
        static let progressBarHeight: CGFloat = 4
    }

    // MARK: - Chart (solo widgets: `DS` no tiene tokens de gráfica)

    /// Las gráficas de los widgets: una línea, su área tenue y el punto de hoy. Sin ejes. No es espejo de nada: el test
    /// de paridad no lo mira.
    enum Chart {
        static let lineWidth: CGFloat = 2
        /// La línea de referencia (el período anterior): más fina y punteada.
        static let referenceLineWidth: CGFloat = 1.5
        static let referenceDash: [CGFloat] = [3, 3]
        /// Área del punto de hoy (`symbolSize` se da en puntos cuadrados: ~6 pt de diámetro).
        static let pointArea: CGFloat = 36
        /// Alto de la mini curva del tamaño pequeño.
        static let sparklineHeight: CGFloat = 24
        /// Barras de «Entradas y salidas»: alto de una barra de total y hueco entre las barras de cada día (en
        /// proporción del ancho del día).
        static let totalBarHeight: CGFloat = 8
        static let dayBarWidthRatio: CGFloat = 0.6
        /// Donut del Resumen del mes: diámetro en el iPad y en el extragrande vertical, grosor del aro (proporción del
        /// radio) y separación entre porciones (grados).
        static let donutSize: CGFloat = 104
        static let donutInnerRatio: CGFloat = 0.62
        static let donutAngularInset: CGFloat = 1.5
        /// Donut de las tartas de Categorías y Subcategorías (grande del iPhone, con el total en el centro).
        static let donutSizeLarge: CGFloat = 156
        /// Punto de color de una leyenda.
        static let legendDot: CGFloat = 8
        /// Columna del porcentaje en una leyenda o un ranking: los «%» quedan alineados («8 %» y «31 %»).
        static let legendPercentWidth: CGFloat = 34
    }

    // MARK: - Typography (= DS.Typography)

    enum Typography {
        /// Título de un widget, como el de los widgets del Panel (`PanelSmallWidgetHeader`).
        static let subheadlineEmphasized = Font.subheadline.weight(.semibold)
        static let subheadline = Font.subheadline
        /// Rótulo de fila.
        static let label = Font.subheadline.weight(.medium)
        static let labelSmall = Font.caption.weight(.medium)
        static let labelTiny = Font.caption2.weight(.medium)
        static let headline = Font.headline.weight(.semibold)
        /// Cifras de un resumen con varias (Resumen del mes).
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let caption = Font.caption
        static let captionSmall = Font.caption2
        /// Píldoras y marcas («Vencido», «−12 %»).
        static let badgeLabel = Font.caption2.weight(.bold)
        static let indicator = Font.caption2.weight(.semibold)
        static let captionMono = Font.caption.monospacedDigit()
        /// La cifra grande, la misma del hero del Panel.
        static let panelHeroAmount = Font.system(size: 36, weight: .semibold)
        /// Símbolo y decimales de `panelHeroAmount`.
        static let panelHeroAmountSecondary = Font.system(size: 17, weight: .regular)
    }
}
