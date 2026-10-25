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

    /// Para un carrusel horizontal dentro de una página con `staysOutOfVerticalBar`: en vez del tajo seco contra el borde de
    /// la barra vertical, se funde a transparente en sus últimos `fadeWidth` pt, y acaba justo en ese borde. Solo mientras
    /// queda contenido por ver hacia la barra: al llegar al final, el fundido se quita y la última tarjeta se ve entera.
    /// Jürgen, 2026-10-25 (Duo cerrado, «el corte»): el tajo hacía que la barra pareciera una pieza aparte.
    ///
    /// Va en el carrusel y no en la página porque un fundido de página también borraría el borde de lo que no se mueve
    /// (la tarjeta de Saldo, «Todo el tiempo»). Sin barra vertical, o fuera de una página que la respete, no hace nada.
    func fadesTowardVerticalBar(fadeWidth: CGFloat = 32) -> some View {
        modifier(FadesTowardVerticalBar(fadeWidth: fadeWidth))
    }

    /// La excepción a la regla A: la vista ocupa también la columna de la barra vertical, y su contenido se centra en la
    /// pantalla entera. Solo donde la columna lleva poco y el hueco pesaba más que la regla (Jürgen, 2026-10-25):
    /// - las pantallas con logo del Welcome (la columna lleva la hora, el wifi y como mucho «‹»): con el ancho seguro el
    ///   logo, el carrusel y el titular quedaban descentrados y el carrusel cortado en seco;
    /// - la lista de Ajustes (la columna lleva la X): el avatar descentrado y el hueco a la derecha. Al desplazar, las
    ///   filas pasan bajo la hora y la X; lo vio y lo eligió así.
    ///
    /// Ignora el área segura solo por el lado de la barra. Sin barra vertical (el iPhone, también girado; el Duo abierto)
    /// no ignora nada: el iPhone en horizontal sigue apartándose de la isla. Siempre el mismo modificador, sin `if`, para
    /// no cambiar de identidad al plegar o abrir.
    func extendsUnderVerticalBar() -> some View {
        modifier(ExtendsUnderVerticalBar())
    }
}

private struct ExtendsUnderVerticalBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(ExtendsUnderVerticalBar271())
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct ExtendsUnderVerticalBar271: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    func body(content: Content) -> some View {
        content.ignoresSafeArea(.container, edges: barEdges)
    }

    /// `toolbarVerticalEdge` y `Edge.Set` siguen los dos la dirección del texto.
    private var barEdges: Edge.Set {
        switch verticalEdge {
        case .leading: .leading
        case .trailing: .trailing
        case nil: []
        }
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
    /// Dónde acaba la página en la pantalla, para que los carruseles de dentro se fundan justo ahí
    /// (`fadesTowardVerticalBar`).
    @State private var pageSpan: ClosedRange<CGFloat>?

    func body(content: Content) -> some View {
        content
            .environment(\.verticalBarPageEdge, verticalBarPageEdge)
            .clipShape(VerticalBarSideClip(barSide: barSide))
            .onGeometryChange(for: ClosedRange<CGFloat>.self) { proxy in
                let frame = proxy.frame(in: .global)
                return frame.minX...frame.maxX
            } action: { pageSpan = $0 }
    }

    private var verticalBarPageEdge: VerticalBarPageEdge? {
        guard let barSide, let pageSpan, let verticalEdge else { return nil }
        return VerticalBarPageEdge(
            side: barSide,
            globalX: barSide == .right ? pageSpan.upperBound : pageSpan.lowerBound,
            towardTrailing: verticalEdge == .trailing
        )
    }

    /// El lado físico de la barra, o `nil` si no hay. `toolbarVerticalEdge` sigue la dirección del texto.
    private var barSide: VerticalBarSideClip.Side? {
        guard let verticalEdge else { return nil }
        return (verticalEdge == .trailing) == (layoutDirection == .leftToRight) ? .right : .left
    }
}

/// Un rectángulo que no corta nada salvo por el lado de la barra vertical, donde acaba en el borde de la vista.
struct VerticalBarSideClip: Shape {
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

/// El borde de la página por el lado de la barra vertical, en coordenadas de pantalla: lo publica `staysOutOfVerticalBar`
/// para los carruseles de dentro. `nil` sin barra.
struct VerticalBarPageEdge: Equatable {
    /// El lado físico de la barra.
    let side: VerticalBarSideClip.Side
    /// La x del borde en `.global`.
    let globalX: CGFloat
    /// La barra está al final del texto (la x del contenido de un scroll crece hacia ella).
    let towardTrailing: Bool
}

extension EnvironmentValues {
    @Entry var verticalBarPageEdge: VerticalBarPageEdge? = nil
}

private struct FadesTowardVerticalBar: ViewModifier {
    let fadeWidth: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(FadesTowardVerticalBar271(fadeWidth: fadeWidth))
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct FadesTowardVerticalBar271: ViewModifier {
    let fadeWidth: CGFloat
    @Environment(\.verticalBarPageEdge) private var pageEdge
    /// Dónde está el carrusel en la pantalla: su x de inicio, su ancho y su alto. Sin la y a propósito, que cambia con
    /// cada desplazamiento vertical de la página y redibujaría el carrusel sin necesidad.
    @State private var span = CarouselSpan()
    @State private var moreTowardBar = false

    /// Lo que la máscara se sale por los lados sin fundido, para no cortar nada que asome (sombras, cristal, el
    /// contenido de un carrusel con `scrollClipDisabled`). La página ya recorta por el lado de la barra.
    private static let reach: CGFloat = 10_000

    func body(content: Content) -> some View {
        content
            .mask(alignment: .topLeading) { mask }
            .onGeometryChange(for: CarouselSpan.self) { proxy in
                let frame = proxy.frame(in: .global)
                return CarouselSpan(minX: frame.minX, width: frame.width, height: frame.height)
            } action: { span = $0 }
            .onScrollGeometryChange(for: Bool.self) { geo in
                guard let pageEdge else { return false }
                return pageEdge.towardTrailing
                    ? geo.visibleRect.maxX < geo.contentSize.width - 1
                    : geo.visibleRect.minX > 1
            } action: { _, more in moreTowardBar = more }
    }

    /// Siempre la misma estructura —una franja opaca y un degradado a cada lado— y solo cambian los anchos, para no
    /// cambiar de identidad al plegar o abrir. En coordenadas físicas: el lado ya viene resuelto.
    private var mask: some View {
        let fades = pageEdge != nil && moreTowardBar
        let fade = fades ? fadeWidth : 0
        let side = pageEdge?.side
        // Dónde está el borde de la página en las coordenadas del carrusel.
        let edgeX = (pageEdge?.globalX ?? 0) - span.minX
        let leftStart = side == .left && fades ? edgeX : -Self.reach
        let rightEnd = side == .right && fades ? edgeX : span.width + Self.reach
        return HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: side == .left ? fade : 0)
            Rectangle()
                .frame(width: max(0, rightEnd - leftStart - (side == .left || side == .right ? fade : 0)))
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: side == .right ? fade : 0)
        }
        .frame(height: span.height + 2 * Self.reach)
        .offset(x: leftStart, y: -Self.reach)
        .environment(\.layoutDirection, .leftToRight)
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

nonisolated private struct CarouselSpan: Equatable, Sendable {
    var minX: CGFloat = 0
    var width: CGFloat = 0
    var height: CGFloat = 0
}
