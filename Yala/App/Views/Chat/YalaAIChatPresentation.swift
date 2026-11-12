//
//  YalaAIChatPresentation.swift
//  Yala
//
//  Cómo se presenta Yala IA junto a los datos (carril adaptativo, fase 2). En una ventana ancha (iPad) el chat es
//  una columna a la derecha y el Panel, Registros o Estadísticas se estrechan a su lado y siguen a la vista: se
//  pregunta mirando los números. En compacta (iPhone, ventana estrecha) es la hoja de siempre.
//
//  **No es un `.inspector`, y es medido (2026-09-29, iPad Pro 13 en vertical):** colgado de Registros, el inspector
//  pasa a la columna de inspector del `NavigationSplitView` de UIKit, que cuando no caben lista, detalle y chat se
//  SUPERPONE al registro abierto y no lo recoloca, ni apartando la lista ni envolviendo el split en otro contenedor.
//  Y colgado de la columna de detalle, la barra del chat se mete en la del registro aunque esté cerrado. Una columna
//  propia estrecha al contenido igual que redimensionar la ventana, que ya está medido (`ListDetailSplit`).
//
//  El contenido va SIEMPRE dentro del mismo `HStack`, abierto o no el chat y en cualquier ancho: si cambiara de
//  contenedor al redimensionar, perdería lo abierto (el registro, el grupo). Al pasar de ancha a compacta con el
//  chat abierto, la columna se va y sale la hoja; la conversación sigue, porque el chat la guarda al cerrarse y la lee
//  al abrirse (`ChatAssistantViewModel.persistSession`).
//

import SwiftUI

extension View {
    /// Yala IA como columna a la derecha en ventana ancha y como hoja en compacta. Sustituye al
    /// `.sheet { ChatSheetView() }` de sus tres puertas (Panel, Registros y Estadísticas).
    ///
    /// `insideNavigationStack`: la vista que lo lleva está DENTRO de una `NavigationStack` (Estadísticas). La columna
    /// no abre entonces otra pila: pinta su cabecera bajo la barra de quien la contiene.
    ///
    /// `onManualEntry`: abre «Nuevo registro» en quien monta el chat. Lo ofrece el chat sin conexión (decisión 42 de 2.3)
    /// y corre con el chat ya cerrado: en hoja, al terminar de bajar (dos presentaciones a la vez en el mismo ancla se
    /// tumban); en columna, en el acto, porque la columna no es una presentación.
    func yalaAIChat(
        isPresented: Binding<Bool>, insideNavigationStack: Bool = false, onManualEntry: (() -> Void)? = nil
    ) -> some View {
        modifier(YalaAIChatPresentation(
            isPresented: isPresented, insideNavigationStack: insideNavigationStack, onManualEntry: onManualEntry))
    }
}

private struct YalaAIChatPresentation: ViewModifier {
    @Binding var isPresented: Bool
    let insideNavigationStack: Bool
    let onManualEntry: (() -> Void)?
    /// «Nuevo registro» tocado en la hoja: se abre al terminar de cerrarse.
    @State private var wantsManualEntry = false
    /// Size class de la VENTANA en el sitio donde se cuelga el chat (fuera de cualquier split).
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsColumn: Bool {
        YalaAIChatLayoutLogic.showsColumn(isPresented: isPresented, isRegularWidth: horizontalSizeClass == .regular)
    }

    private var showsSheet: Binding<Bool> {
        YalaAIChatLayoutLogic.showsSheet(isPresented: isPresented, isRegularWidth: horizontalSizeClass == .regular)
            ? $isPresented
            : .constant(false)
    }

    private func openManualEntryIfRequested() {
        guard wantsManualEntry else { return }
        wantsManualEntry = false
        onManualEntry?()
    }

    func body(content: Content) -> some View {
        HStack(spacing: DS.Spacing.none) {
            content
            if showsColumn {
                Divider()
                ChatSheetView(
                    presentation: .column(onClose: { isPresented = false }, insideNavigationStack: insideNavigationStack),
                    onManualEntry: onManualEntry.map { open in { isPresented = false; open() } })
                    .frame(width: DS.Adaptive.listColumnMinWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        // La columna entra desde la derecha; con Reducir movimiento, aparece en seco (card C6).
        .animation(reduceMotion ? nil : DS.Animation.appear, value: showsColumn)
        .sheet(isPresented: showsSheet, onDismiss: openManualEntryIfRequested) {
            ChatSheetView(onManualEntry: onManualEntry.map { _ in { wantsManualEntry = true; isPresented = false } })
        }
    }
}
