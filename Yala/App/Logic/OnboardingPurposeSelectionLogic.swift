//
//  OnboardingPurposeSelectionLogic.swift
//  Yala
//
//  Pure decision logic del paso «Propósito» del onboarding: qué card se pinta MARCADA para
//  cada modo de uso, y qué hace tocar la card «Llevar el control de mi dinero».
//
//  EL DEFECTO QUE ORIGINA ESTE FICHERO (chip C5) es uno solo, con dos síntomas: el selector
//  ofrece TRES cards y `OnboardingView` expresaba la selección con un booleano de DOS
//  (`expensesOnlyMode`). Con `.groupsOnly` elegido:
//    1. «Llevar el control» se pintaba marcada (`isSelected: !expensesOnlyMode`) A LA VEZ que
//       «Dividir gastos con amigos» ⇒ dos propósitos marcados.
//    2. Su closure era `if expensesOnlyMode { selectedUsageMode = .fullControl }` ⇒ el tap NO
//       hacía NADA. El usuario que cambiaba de idea tenía que pasar por «Solo anotar gastos».
//  La marca falsa y el tap muerto se tapaban entre sí: la card ya parecía elegida, así que no
//  había motivo para sospechar que el tap se había perdido.
//
//  POR QUÉ LAS DOS SALEN DE LA MISMA FUNCIÓN. La causa no es que los dos predicados fueran
//  incorrectos por separado, es que eran DISTINTOS (`!expensesOnlyMode` para pintar,
//  `expensesOnlyMode` para decidir). Aquí la marca y el tap se derivan ambos de `selectedCard`,
//  así que volver a divergir exige cambiar la SSOT y eso cae en la tabla.
//
//  EL MODO `.dayToDay` NO ES UN DETALLE: `OnboardingUsageMode` tiene CUATRO casos, no tres, y
//  `.dayToDay` es ALCANZABLE desde este mismo paso (medido en el árbol de este commit):
//  `OnboardingView` lo escribe en el paso `.accounts` («Una sola cuenta», `:585`), ese paso NO
//  se salta con `.dayToDay` (`OnboardingStepPlan.skippedSteps` solo le quita `.accountType`) y
//  el flujo tiene botón atrás (`OnboardingView.goBack()`), cuyo `previousStep(before: .accounts)`
//  es `.purpose`. También llega por la migración legacy del `.task` (`OnboardingView:307`).
//  ⇒ el arreglo aparentemente natural —`isSelected: selectedUsageMode == .fullControl`— dejaría
//  CERO cards marcadas en ese estado, cambiando un bug por otro. `.dayToDay` es una variante de
//  «llevar el control» (control con una sola cuenta), así que la card de control representa el
//  CONJUNTO `{.fullControl, .dayToDay}` y por eso la decisión es de pertenencia, no de igualdad.
//
//  Vive fuera del `body` por la lección de `965a4d86` / `9c66c528`: un predicado dentro de un
//  `@ViewBuilder` no lo alcanza ningún unitario, así que romperlo deja la suite entera en VERDE.
//  El cableado lo pinnea un source-scan (`OnboardingPurposeSelectionLogicTests`).
//

import Foundation

/// Modo de uso elegido en el onboarding. Movido fuera de `OnboardingView` (era un enum privado
/// anidado) para que la selección del paso «Propósito» sea pure-logic y testeable — mismo
/// movimiento que hizo `OnboardingStep`, que la vista referencia vía `typealias Step`.
nonisolated enum OnboardingUsageMode: String {
    case expensesOnly, dayToDay, fullControl, groupsOnly
}

/// Las tres cards del paso «Propósito», por su `accessibilityIdentifier`:
/// `onboarding_purpose_control` · `onboarding_purpose_expenses` · `onboarding_purpose_groups`.
nonisolated enum OnboardingPurposeCard: String, CaseIterable {
    case control, expenses, groups
}

nonisolated enum OnboardingPurposeSelectionLogic {

    /// SSOT: la ÚNICA card marcada para un modo dado. Total (devuelve una card para los cuatro
    /// modos) y única (devuelve UNA), que juntas son la invariante que el bug rompía por los dos
    /// lados a la vez — con `.groupsOnly` había dos marcadas.
    ///
    /// `.dayToDay` cae en `.control` a propósito: es «llevar el control» con una sola cuenta, no
    /// un propósito distinto. Ver el encabezado del fichero para por qué ese modo llega aquí.
    static func selectedCard(for mode: OnboardingUsageMode) -> OnboardingPurposeCard {
        switch mode {
        case .fullControl, .dayToDay: return .control
        case .expensesOnly:           return .expenses
        case .groupsOnly:             return .groups
        }
    }

    /// Si la card se pinta marcada. Derivada de `selectedCard` — no un predicado paralelo.
    static func isSelected(_ card: OnboardingPurposeCard, mode: OnboardingUsageMode) -> Bool {
        selectedCard(for: mode) == card
    }

    /// Si tocar «Llevar el control de mi dinero» debe cambiar el modo a `.fullControl`.
    ///
    /// La condición existe y no se sustituye por una asignación incondicional (que es lo que
    /// hacen las otras dos cards): desde `.dayToDay` el usuario YA eligió este propósito, y
    /// reasignar `.fullControl` le cambiaría en silencio la respuesta del paso siguiente de «Una
    /// sola cuenta» a «Varias cuentas». Lo que el bug hacía era usar el predicado equivocado
    /// (`expensesOnlyMode`), que además dejaba fuera `.groupsOnly`.
    static func shouldSelectFullControl(from mode: OnboardingUsageMode) -> Bool {
        !isSelected(.control, mode: mode)
    }
}
