//
//  ContentTransitions.swift
//  Yala
//
//  Cómo entra el contenido que llega (cards C1, C3 y C7 de la auditoría de fluidez, 2026-11-01):
//  `docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`.
//
//  - **Lo que se va al terminar una carga** (el esqueleto, un `ProgressView`, la tarjeta «Analizando…») se funde con
//    `AnyTransition.loadingPlaceholder`, y desde el primer fotograma de su salida deja de existir para la
//    accesibilidad y para los toques. Un fundido normal deja dos copias de la pantalla durante 0,25 s: cada botón
//    sale dos veces en el árbol de accesibilidad y un XCUITest que toque justo entonces cae con «varios elementos»
//    (por eso la pasada de la card pjum retiró el fundido del esqueleto).
//  - **Filas que entran o se van** (`animatesRowEdits(ids:)`): solo una edición pequeña —borrar, deshacer, añadir—
//    se anima. Cambiar de filtro o de período suele cambiar la lista entera, y animar cientos de filas a la vez es más
//    tirón que fluidez: eso sigue en seco. En una lista corta, un filtro que solo cambia 1-3 filas también se funde: no
//    se distingue de una edición, y ahí no tira de nada.
//
//  Todo implícito (`.animation` / `.transaction(value:)`) porque casi todo vive dentro de una pestaña, donde
//  `ContentView` apaga las transacciones que cruzan la `TabView` (regla «Animar dentro de una pestaña» de
//  `swiftui-ds.md`). Con Reducir movimiento, nada se anima.
//

import SwiftUI

// MARK: - Lo que se va al terminar una carga

/// La salida de un marcador de carga: se funde, y mientras se funde ni se lee ni se toca.
struct LoadingExitTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            // No es animable: se aplica entero en el primer fotograma de la salida. Así, mientras dura el fundido,
            // en el árbol solo queda la copia que llega.
            .accessibilityHidden(!phase.isIdentity)
            .allowsHitTesting(phase.isIdentity)
    }
}

extension AnyTransition {
    /// El marcador de una carga (esqueleto, `ProgressView`, «Analizando…»): entra fundiéndose y se va con
    /// `LoadingExitTransition`. Lo que llega en su lugar lleva `.transition(.opacity)`.
    static var loadingPlaceholder: AnyTransition {
        .asymmetric(insertion: .opacity, removal: AnyTransition(LoadingExitTransition()))
    }
}

// MARK: - Una pieza que cambia de estado en su sitio

extension AnyTransition {
    /// Una pieza que pasa de un estado a otro sin moverse (el borrador del chat: pendiente → guardado o descartado,
    /// card C8): el estado nuevo entra fundiéndose y el viejo se funde sin leerse ni tocarse, como `loadingPlaceholder`.
    /// Así no hay dos «Guardar» en el árbol durante el fundido.
    static var stateSwap: AnyTransition {
        .asymmetric(insertion: .opacity, removal: AnyTransition(LoadingExitTransition()))
    }
}

// MARK: - Filas que entran o se van

/// ¿El cambio de una lista es una edición pequeña que merece animarse? Valor puro: lo prueba `RowListEditLogicTests`.
enum RowListEditLogic {
    /// Cuántas filas pueden entrar o irse a la vez para que se anime: un borrado, un deshacer, un alta, un par de
    /// liquidaciones. Más que eso es otra lista (otro filtro, otro período, la primera carga).
    static let maxAnimatedChanges = 3

    /// `true` si de `old` a `new` entran o se van entre 1 y `maxAnimatedChanges` filas y las que siguen conservan su
    /// orden. Una fila que cambia de sitio (otra fecha, otro estado) no cuenta como edición pequeña.
    static func isSmallEdit<ID: Hashable>(from old: [ID], to new: [ID]) -> Bool {
        guard old != new else { return false }
        let oldSet = Set(old)
        let newSet = Set(new)
        let changed = oldSet.subtracting(newSet).count + newSet.subtracting(oldSet).count
        guard changed > 0, changed <= maxAnimatedChanges else { return false }
        return old.filter(newSet.contains) == new.filter(oldSet.contains)
    }

    /// `true` si la edición pequeña vacía la lista o le pone su primera fila (card 1jvv): es lo que cambia la lista por
    /// su estado vacío, o al revés. Un filtro que deja la lista vacía de golpe no es pequeño y sigue en seco.
    static func crossesEmpty<ID: Hashable>(from old: [ID], to new: [ID]) -> Bool {
        old.isEmpty != new.isEmpty && isSmallEdit(from: old, to: new)
    }
}

/// Anima la lista solo cuando el cambio de sus filas es una edición pequeña (`RowListEditLogic`).
///
/// Recuerda la última lista que vio: en la pasada en que cambian los `ids` aún guarda la anterior, y con las dos decide
/// si esa transacción se anima. No toca ninguna otra transacción, y solo compara cuando los `ids` cambian (el cierre de
/// `.transaction(value:)` corre entonces): una lista de miles de filas no paga la comparación en cada render.
///
/// La animación cubre el contenedor entero, no solo las filas: lo que cambie en la misma transacción y no deba fundirse
/// (una frase con la cifra de arriba) lleva `.transaction { $0.animation = nil }`.
private struct RowEditAnimationModifier<ID: Hashable>: ViewModifier {
    let ids: [ID]
    /// Solo cuando la lista pasa a vacía o deja de estarlo (`crossesEmpty`): el modo del contenedor que monta la lista
    /// Y su vacío. Las filas las sigue animando el modificador de dentro, con su propio contenedor.
    var onlyAcrossEmpty = false
    /// `false` mientras la lista aún no ha cargado (Presupuestos carga en su `onAppear`, Registros con su primer filtrado):
    /// esa primera carga no es una edición, y con 1-3 filas se fundía el vacío cada vez que se abría la pantalla. La lista
    /// que se recuerda empieza cuando pasa a `true`.
    var settled = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastIDs: [ID]?

    func body(content: Content) -> some View {
        content
            .transaction(value: ids) { [lastIDs, ids, reduceMotion, onlyAcrossEmpty] transaction in
                guard !reduceMotion, let lastIDs else { return }
                let animates = onlyAcrossEmpty
                    ? RowListEditLogic.crossesEmpty(from: lastIDs, to: ids)
                    : RowListEditLogic.isSmallEdit(from: lastIDs, to: ids)
                guard animates else { return }
                transaction.animation = DS.Animation.appear
            }
            .onAppear { lastIDs = settled ? ids : nil }
            .onChange(of: ids) { _, newIDs in lastIDs = settled ? newIDs : nil }
            .onChange(of: settled) { _, isSettled in lastIDs = isSettled ? ids : nil }
    }
}

extension View {
    /// Las filas que entran o se van con una edición pequeña (borrar, deshacer, añadir) lo hacen fundiéndose y las
    /// demás se desplazan; un cambio de lista entero sigue en seco. Va en el contenedor de las filas, con los ids en el
    /// orden en que se pintan.
    func animatesRowEdits<ID: Hashable>(ids: [ID]) -> some View {
        modifier(RowEditAnimationModifier(ids: ids))
    }

    /// La lista y su estado vacío se relevan fundiéndose cuando una edición pequeña borra la última fila o añade la
    /// primera (card 1jvv). Va en el contenedor que monta las DOS ramas —un `ZStack`, para que durante el fundido no se
    /// apilen una debajo de otra: `.top` dentro de un scroll, centrado si el vacío ocupa la página—, y cada rama lleva
    /// `.transition(.stateSwap)`: la que se va deja de leerse y de tocarse desde el primer fotograma. La rama que lleva el
    /// título grande en su scroll (el detalle de grupo) entra y sale con `.identity`: fundida, se funde el título con ella.
    /// Con `animatesRowEdits` dentro de la rama con filas, la lista se desmontaba antes de que nadie pudiera animar el
    /// cambio, y al volver a montarse no recordaba la lista vacía.
    ///
    /// Bastan las `maxAnimatedChanges + 1` primeras filas (`prefix`): para cruzar el vacío con una edición pequeña, un
    /// lado está vacío y el otro tiene como mucho 3; con 4 o más, el cambio ya no es pequeño. Así una lista de miles de
    /// filas no paga el recorrido entero en cada render.
    func animatesEmptyStateSwap<ID: Hashable>(ids: [ID], settled: Bool = true) -> some View {
        modifier(RowEditAnimationModifier(ids: ids, onlyAcrossEmpty: true, settled: settled))
    }
}
