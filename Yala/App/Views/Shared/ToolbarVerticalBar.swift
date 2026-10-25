//
//  ToolbarVerticalBar.swift
//  Yala
//
//  iPhone Duo (compilando con el SDK de iOS 27.1): con el Duo cerrado, y abierto en horizontal, las barras de
//  navegación, herramientas y pestañas pasan a una barra vertical en el lateral, bajo la barra de estado. Pasan solos
//  los botones con icono; un item con vista propia (la bandeja del Panel, con su contador) se queda fuera si no se le
//  pide, y en el Panel —sin título arriba— acababa flotando abajo, encima de la gráfica. Y en la barra vertical cabe
//  poco: lo que no cabe se va al menú «···» del sistema. Estas envolturas dicen qué hace cada item; en un iPhone y en un
//  iPad, sin barra vertical y con sitio, no cambian nada.
//

import SwiftUI

extension ToolbarContent {
    /// Un item con vista propia que también va en la barra vertical. Para los que ya son un botón con icono no hace
    /// falta: van solos. Con `false`, el comportamiento del sistema (se queda en horizontal), sin cambiar de identidad.
    @ToolbarContentBuilder
    func joinsVerticalBar(_ joins: Bool = true) -> some ToolbarContent {
        if #available(iOS 27.1, *) {
            axisBehavior(joins ? .verticalPreferred : .automatic)
        } else {
            self
        }
    }

    /// El último en irse al menú «···» cuando falta sitio: lo que lleva contador o se usa a menudo (Apple, «Designing
    /// for iPhone Duo»). Un item con vista propia, además, no tiene cómo pintarse dentro del menú.
    @ToolbarContentBuilder
    func overflowsLast() -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            visibilityPriority(.high)
        } else {
            self
        }
    }

    /// El primero en irse al menú «···» cuando falta sitio: un ajuste de la pantalla que se toca poco. Necesita título
    /// además de icono, que es lo que el menú enseña.
    @ToolbarContentBuilder
    func overflowsFirst() -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            visibilityPriority(.low)
        } else {
            self
        }
    }
}

extension View {
    /// Opción 2 de Jürgen (2026-10-24) para las páginas de pestaña del Duo cerrado: cuando la barra vertical no da para
    /// todo, ceden las pestañas —se pliegan a un botón— y no los botones de la página (avatar, bandeja, Filtros…). Sin
    /// esto, en el Panel cerrado el avatar no cabía y Filtros acababa en «···». Va en la página, dentro de su pila: puesto
    /// en la `TabView` o en el contenido de cada `Tab`, no hacía nada (medido).
    ///
    /// Solo en ancho compacto. Abierto en horizontal (ancho regular, siete pestañas) también plegaba las pestañas del
    /// Panel, y el abierto no se rediseña: ahí se queda el comportamiento del sistema. Se pasa siempre un valor, sin `if`,
    /// para que la página no cambie de identidad al plegar o abrir. Sin barra vertical no cambia nada.
    func prefersToolbarItemsInVerticalBar() -> some View {
        modifier(PrefersToolbarItemsInVerticalBar())
    }

    /// No se pinta cuando la barra que lo lleva es vertical. Para un botón de barra de solo texto que ya está en el menú
    /// de la pantalla («Seleccionar» de Registros, dentro de «···»): sin icono nunca pasa a la vertical y se quedaba en
    /// una barra aparte arriba, y darle icono cambiaría el iPhone, cuya barra horizontal prefiere el icono.
    /// `.axisBehavior(.horizontalOnly)` no basta: la barra del título grande es horizontal y lo deja ahí.
    /// Medido el 2026-10-24: el sistema da el borde de la barra vertical en el Duo cerrado, y `nil` en el iPhone, en el
    /// Duo abierto en vertical y en la columna de la lista del Duo abierto en horizontal, que van en horizontal.
    func hiddenInVerticalBar() -> some View {
        modifier(HiddenInVerticalBar())
    }

    /// Nada de lo que se desplaza pasa por detrás de la barra vertical: se recorta en el borde del scroll, solo por el
    /// lado de la barra. Regla A del ancho en el iPhone Duo cerrado (2026-10-24), la de Apple (`app-resizability`:
    /// contenido y controles en el área segura; bajo la barra, solo fondos). Sin esto, los carruseles horizontales —las
    /// cuentas y los chips del Panel, las tarjetas del Welcome— llegaban hasta el borde físico por detrás de la barra y
    /// los widgets no: un `ScrollView` horizontal pinta hasta el borde de la pantalla aunque su página acabe antes.
    ///
    /// Medido el 2026-10-24: el marco del scroll vertical de la página ya acaba en el borde del área segura, así que se
    /// recorta en su propio borde. No se lee el inset: el de `GeometryProxy` es el del espacio ofrecido y, restado, el
    /// recorte quedaba 84 pt más adentro (lo que avisa `app-resizability`, regla 13).
    ///
    /// Va en el scroll vertical de la página (lo pone `scrollViewGlassEdges`), no en cada carrusel. Sin barra vertical
    /// (el iPhone, el Duo abierto en vertical, la columna de la lista) el recorte queda a 10.000 pt de cada borde: no
    /// corta nada, y la vista no cambia de identidad al plegar o abrir, así que el scroll no vuelve arriba.
    func staysOutOfVerticalBar() -> some View {
        modifier(StaysOutOfVerticalBar())
    }
}

private struct StaysOutOfVerticalBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(StaysOutOfVerticalBar271())
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct StaysOutOfVerticalBar271: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var verticalEdge
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.clipShape(VerticalBarSideClip(barSide: barSide))
    }

    /// El lado físico de la barra, o `nil` si no hay. `toolbarVerticalEdge` sigue la dirección del texto.
    private var barSide: VerticalBarSideClip.Side? {
        guard let verticalEdge else { return nil }
        return (verticalEdge == .trailing) == (layoutDirection == .leftToRight) ? .right : .left
    }
}

/// Un rectángulo que no corta nada salvo por el lado de la barra vertical, donde acaba en el borde de la vista.
private struct VerticalBarSideClip: Shape {
    enum Side { case left, right }
    let barSide: Side?

    func path(in rect: CGRect) -> Path {
        var clip = rect.insetBy(dx: -10_000, dy: -10_000)
        switch barSide {
        case .right: clip.size.width = rect.maxX - clip.minX
        case .left:
            clip.size.width = clip.maxX - rect.minX
            clip.origin.x = rect.minX
        case nil: break
        }
        return Path(clip)
    }
}

private struct HiddenInVerticalBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(HiddenInVerticalBar271())
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct HiddenInVerticalBar271: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    func body(content: Content) -> some View {
        if verticalEdge == nil {
            content
        }
    }
}

private struct PrefersToolbarItemsInVerticalBar: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbarVerticalCompressionBehavior(horizontalSizeClass == .compact ? .prefersToolbarItems : .automatic)
        } else {
            content
        }
    }
}
