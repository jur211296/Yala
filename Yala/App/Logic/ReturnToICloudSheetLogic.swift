//
//  ReturnToICloudSheetLogic.swift
//  Yala
//
//  Revisión 2.3, zona 41, decisión 53 (V2): **volver a tu iCloud es una hoja con fases**. Hasta aquí eran tres globos
//  anclados al botón —«Tu iCloud ya tiene datos de Yala», «¿Borrarlos de tu iCloud?» y «¿Volver a iCloud?»— con letra de
//  9-10 pt, y la tarjeta prometía «sin perder nada» y «queda en pausa por si vuelves», cuando volver a la nube con esa
//  cuenta hoy no se puede.
//
//  Las fases, en orden:
//   1. **Qué pasa** con cada cosa: tus datos, tu cuenta de Yala, lo que hay en ella y volver a la nube con ella.
//   2. **Qué hacer con lo que ya hay** en tu iCloud, solo si la pregunta previa encontró algo: tarjetas con la cifra.
//   3. **Confirmar** lo elegido. Es lo único que empieza la vuelta.
//
//  Pura: qué fase sigue y qué texto lleva cada elección. Lo que empieza la vuelta lo decide `StorageSettingsView` en el
//  `onDismiss` de la hoja, con la elección que esta le devuelve.
//

import Foundation

/// Lo que la persona eligió en la hoja. Cada caso empieza su vuelta (`StorageSettingsView.onReturnSheetDismissed`).
enum ReturnToICloudChoice: Equatable {
    /// Sin nada ajeno en iCloud: la vuelta de siempre.
    case plain
    /// «Sumarlos a mis datos»: la vuelta que suma lo que había en iCloud.
    case mergePrior
    /// «Empezar sin ellos»: borra de iCloud lo ajeno y, si termina, vuelve.
    case discardPrior
}

/// Las fases de la hoja.
enum ReturnToICloudPhase: Equatable {
    case whatHappens
    case choosePrior
    case confirm(ReturnToICloudChoice)
}

enum ReturnToICloudSheetLogic {

    /// «Seguir» desde «qué pasa»: con datos ajenos, la elección; sin ellos, la confirmación de la vuelta de siempre.
    static func phaseAfterWhatHappens(priorData: ICloudForeignCorpus?) -> ReturnToICloudPhase {
        priorData == nil ? .confirm(.plain) : .choosePrior
    }

    /// La línea de la fase de elegir, con la cifra. Sin cifras que decir, la versión que no promete números.
    static func priorBody(_ corpus: ICloudForeignCorpus) -> String {
        let parts = ReverseICloudPriorDataLogic.summaryParts(corpus)
        return parts.isEmpty
            ? L10n.Storage.Revert.Sheet.priorBodyNoCount
            : L10n.Storage.Revert.Sheet.priorBody(parts.joined(separator: ", "))
    }

    /// Lo que se dice bajo «Sumarlos a mis datos». **Los registros de grupos se nombran aparte**: llegan sin su grupo si
    /// esta cuenta no está en él (ticket `prior-icloud-group-records-summed-without-their-group`).
    static func mergeDetail(_ corpus: ICloudForeignCorpus) -> String {
        corpus.groupTransactions > 0
            ? L10n.Storage.Revert.Sheet.mergeDetail + " " + L10n.Storage.Revert.Prior.groupsNote
            : L10n.Storage.Revert.Sheet.mergeDetail
    }

    /// La línea de la confirmación que repite lo elegido, con su cifra. `nil` en la vuelta de siempre: no hay elección
    /// que repetir.
    static func confirmLine(_ choice: ReturnToICloudChoice, priorData: ICloudForeignCorpus?) -> String? {
        let parts = priorData.map { ReverseICloudPriorDataLogic.summaryParts($0) } ?? []
        let summary = parts.joined(separator: ", ")
        switch choice {
        case .plain:
            return nil
        case .mergePrior:
            return parts.isEmpty
                ? L10n.Storage.Revert.Sheet.confirmMergeNoCount
                : L10n.Storage.Revert.Sheet.confirmMerge(summary)
        case .discardPrior:
            return parts.isEmpty
                ? L10n.Storage.Revert.Sheet.confirmDiscardNoCount
                : L10n.Storage.Revert.Sheet.confirmDiscard(summary)
        }
    }

    /// El botón que empieza la vuelta. El de «Empezar sin ellos» dice que borra, y va en rojo.
    static func confirmButton(_ choice: ReturnToICloudChoice) -> String {
        choice == .discardPrior ? L10n.Storage.Revert.Sheet.confirmDiscardButton : L10n.Storage.Revert.button
    }
}
