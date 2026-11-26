//
//  NewRecordTutorialGuide.swift
//  Yala
//
//  Y23-08: la guía de foco sobre el formulario de HOY (`NewTransactionView`, sin rediseñarlo) dentro de «Aprender a
//  registrar». Cinco pasos, con `CoachMarkOverlay`: 1 «Empieza por el monto» · 2 «¿En qué fue?» (abre la hoja real de
//  categorías) · 3 «Tu cuenta ya está puesta» · 4 «Un nombre, si quieres» (Escribir / Saltar) · 5 «Guárdalo». Cada paso
//  avanza al hacer la acción, y «Omitir guía» deja el formulario normal.
//

import SwiftUI

nonisolated enum NewRecordTutorialGuide {

    static let amountAnchor = "new_record_guide_amount"
    static let categoryAnchor = "new_record_guide_category"
    static let accountAnchor = "new_record_guide_account"
    static let descriptionAnchor = "new_record_guide_description"
    static let saveAnchor = "new_record_guide_save"

    /// Los índices de los pasos, por nombre.
    enum Step: Int {
        case amount = 0, category, account, description, save
    }

    /// El paso que toca según lo que ya está puesto. Sin monto, el monto; sin categoría, la categoría; después, el que
    /// ya iba (cuenta, nombre o guardar) sin volver atrás.
    /// Con más de una cuenta se salta «Tu cuenta ya está puesta»: su texto dice que es la única (la ficha la da por
    /// única; después de «Crear otra cuenta» no lo es).
    static func step(hasAmount: Bool, hasCategory: Bool, current: Int, hasSingleAccount: Bool = true) -> Int {
        if !hasAmount { return Step.amount.rawValue }
        if !hasCategory { return Step.category.rawValue }
        let next = max(current, Step.account.rawValue)
        return next == Step.account.rawValue && !hasSingleAccount ? Step.description.rawValue : next
    }

    /// Lo que el formulario tiene que dejar a la vista: el ancla del paso que se ve, o nada si la guía no se ve.
    static func scrollTarget(isShowing: Bool, index: Int) -> String? {
        guard isShowing else { return nil }
        let anchors = [amountAnchor, categoryAnchor, accountAnchor, descriptionAnchor, saveAnchor]
        return anchors.indices.contains(index) ? anchors[index] : nil
    }

    /// Con el teclado puesto o una hoja encima la guía se esconde (lo que señala queda tapado) y vuelve al cerrarse.
    static func isShowing(isActive: Bool, keyboardVisible: Bool, sheetOpen: Bool) -> Bool {
        isActive && !keyboardVisible && !sheetOpen
    }
}

extension NewRecordTutorialGuide {
    /// «Tu cuenta ya está puesta» sale con una sola cuenta de la persona. Cuenta las cuentas que ella ve como suyas
    /// (`billableUserAccounts`: ni archivadas, ni de sistema de Grupos, ni líneas de otra moneda), no las filas: una
    /// cuenta con soles y dólares se guarda como dos filas (la principal y su línea en USD) y la guía se saltaba el paso
    /// (observación del iPhone 14, 25-nov-2026). Un enlace que no se reconoce como línea (su principal no está) cuenta
    /// como cuenta aparte, como en el límite Free.
    @MainActor
    static func hasSingleAccount(_ accounts: [Account]) -> Bool {
        accounts.billableUserAccounts.count <= 1
    }

    @MainActor
    static var steps: [CoachMarkStep] {
        typealias T = L10n.PrimerosPasos23.Record
        return [
            CoachMarkStep(id: amountAnchor, title: T.guideAmountTitle, message: T.guideAmountMessage,
                          advancesByAction: true),
            CoachMarkStep(id: categoryAnchor, title: T.guideCategoryTitle, message: T.guideCategoryMessage,
                          advancesByAction: true),
            CoachMarkStep(id: accountAnchor, title: T.guideAccountTitle, message: T.guideAccountMessage,
                          advancesByAction: true, primaryLabel: L10n.Common.understood),
            CoachMarkStep(id: descriptionAnchor, title: T.guideNameTitle, message: T.guideNameMessage,
                          advancesByAction: true, primaryLabel: T.guideNameSkip, secondaryLabel: T.guideNameWrite),
            CoachMarkStep(id: saveAnchor, title: T.guideSaveTitle, message: T.guideSaveMessage,
                          advancesByAction: true),
        ]
    }
}

/// Monta la guía sobre el formulario y la hace avanzar con lo que la persona hace: escribir el monto (al cerrar el
/// teclado), elegir una categoría. Un solo modificador, para no alargar la cadena del `body` del formulario.
struct NewRecordTutorialGuideHost: ViewModifier {
    @Binding var isActive: Bool
    @Binding var index: Int
    /// Activa y sin teclado ni hoja encima.
    let isShowing: Bool
    let hasAmount: Bool
    let hasCategory: Bool
    let hasSingleAccount: Bool
    let onWriteName: () -> Void

    /// «Escribir» abrió el teclado en el nombre: al cerrarlo, la guía pasa a «Guárdalo».
    @State private var awaitsName = false

    func body(content: Content) -> some View {
        content
            .coachMarkOverlay(
                steps: NewRecordTutorialGuide.steps,
                isPresented: isShowing ? $isActive : .constant(false),
                currentIndex: $index,
                // La guía de «Aprender a registrar»: es el paso, no un consejo de más (Panel progresivo).
                partOfPrimerosPasos: true,
                onSecondary: { _ in
                    awaitsName = true
                    onWriteName()
                },
                onComplete: {}
            )
            .onChange(of: GuideInputs(isShowing: isShowing, hasAmount: hasAmount, hasCategory: hasCategory)) { _, _ in
                sync()
            }
    }

    private struct GuideInputs: Equatable {
        let isShowing: Bool
        let hasAmount: Bool
        let hasCategory: Bool
    }

    private func sync() {
        guard isActive else { return }
        if awaitsName, isShowing, index == NewRecordTutorialGuide.Step.description.rawValue {
            awaitsName = false
            index = NewRecordTutorialGuide.Step.save.rawValue
            return
        }
        let next = NewRecordTutorialGuide.step(
            hasAmount: hasAmount, hasCategory: hasCategory, current: index, hasSingleAccount: hasSingleAccount)
        if next != index { index = next }
    }
}
