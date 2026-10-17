//
//  ReverseICloudPriorDataLogic.swift
//  Yala
//
//  «Volver a iCloud» no suma sin avisar lo que ya había en el iCloud del teléfono (ticket
//  `reverse-to-icloud-merges-prior-icloud-data-without-asking`, decisión A de Jürgen del 2026-10-15).
//
//  La vuelta monta el espejo de CloudKit sobre la zona del Apple ID, y el espejo baja todo lo que encuentra. En una
//  cuenta nacida en la nube esa zona no es suya: puede traer el corpus de otra cuenta de Yala que usó este iPhone, o el
//  de otro dispositivo con el mismo Apple ID. Medido en el QA del 15-oct: 25 movimientos de la cuenta + 9 gastos de
//  grupo de otra, y el aviso decía «No perderás nada». Desde aquí, antes de las confirmaciones se pregunta a iCloud y,
//  si hay algo ajeno, la persona elige: sumarlo o empezar sin ello.
//
//  Solo la vuelta de un teléfono NACIDO EN LA NUBE pregunta. En una cuenta migrada la zona es su propio corpus, y la
//  vuelta está construida sobre él (el mapa de coordenadas y la reconciliación: `ReverseEligibility`).
//

import Foundation

enum ReverseICloudPriorDataLogic {

    /// Qué hace el botón «Volver a iCloud» antes de sus confirmaciones.
    enum Gate: Equatable {
        /// Nada que avisar: las confirmaciones de siempre.
        case proceed
        /// El iCloud tiene datos que el espejo sumaría: el aviso con la elección.
        case ask(ICloudForeignCorpus)
        /// No se pudo preguntar. La vuelta no empieza: seguir sería sumar sin avisar.
        case cannotCheck(String)
        /// No hay cuenta de iCloud a la que preguntar. Tampoco empieza: la vuelta se quedaría esperando a que la persona
        /// abra iCloud, y en ese momento el espejo bajaría lo que hubiera sin que nadie lo mirara.
        case needsICloud
    }

    /// ¿Pregunta esta vuelta a iCloud? Solo la de un teléfono nacido en la nube (`StorageModePersistence.isBornCloud`, una
    /// afirmación POSITIVA: su ausencia no lo es, y entonces la vuelta exige el mapa de una cuenta migrada).
    static func asksICloud(isBornCloud: Bool) -> Bool {
        isBornCloud
    }

    /// La respuesta de iCloud → qué hace el botón.
    static func gate(_ check: ICloudForeignCorpusCheck) -> Gate {
        switch check {
        case .noAccount:
            return .needsICloud
        case .failed(let reason):
            return .cannotCheck(reason)
        case .measured(let corpus):
            return corpus.hasAnyData ? .ask(corpus) : .proceed
        }
    }

    /// Las cifras del aviso, en el orden en que se leen. Vacío si ninguna casilla tiene nada que decir: el texto cae
    /// entonces a la versión sin cifras, que no promete números que no tiene.
    static func summaryParts(_ corpus: ICloudForeignCorpus) -> [String] {
        var parts: [String] = []
        if corpus.transactions > 0 {
            parts.append(corpus.truncated
                ? L10n.Welcome.PrivateICloud.foundAtLeast(corpus.transactions)
                : L10n.Welcome.Restore.foundTransactions(corpus.transactions))
        }
        if corpus.groupTransactions > 0 {
            parts.append(L10n.Storage.Revert.Prior.groupRecords(corpus.groupTransactions))
        }
        if corpus.accounts > 0 {
            parts.append(L10n.Welcome.Restore.foundAccounts(corpus.accounts))
        }
        if corpus.budgets > 0 {
            parts.append(L10n.Welcome.Restore.foundBudgets(corpus.budgets))
        }
        if parts.isEmpty && corpus.truncated {
            parts.append(L10n.Welcome.PrivateICloud.foundUnknownAmount)
        }
        return parts
    }

    /// El cuerpo del aviso. **Los registros de grupos se nombran aparte**: llegan sin su grupo si esta cuenta no está en
    /// él, y en la Bandeja no se pueden descartar (ticket `prior-icloud-group-records-summed-without-their-group`).
    static func message(_ corpus: ICloudForeignCorpus) -> String {
        let parts = summaryParts(corpus)
        var message = parts.isEmpty
            ? L10n.Storage.Revert.Prior.bodyNoCount
            : L10n.Storage.Revert.Prior.body(parts.joined(separator: ", "))
        if corpus.groupTransactions > 0 {
            message += " " + L10n.Storage.Revert.Prior.groupsNote
        }
        return message
    }
}
