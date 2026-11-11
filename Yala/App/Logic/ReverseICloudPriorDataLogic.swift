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

    /// El texto de un borrado de «Empezar sin ellos» que no terminó. **Solo culpa a la conexión si no había red**: el
    /// recorrido parado y cualquier otro fallo dicen que lo borrado se queda borrado y que el reintento sigue con lo que
    /// quede, que es verdad porque cada intento vuelve a leer la zona (QA guiado del 2026-10-19: el texto culpaba a la
    /// conexión de un corte por plazo).
    static func wipeFailureMessage(_ outcome: ForeignWipeOutcome) -> String {
        switch outcome {
        case .failed(_, network: true): return L10n.Storage.Revert.Prior.wipeFailed
        case .done, .stalled, .failed:  return L10n.Storage.Revert.Prior.wipeStopped
        }
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

    /// Qué aviso sale cuando la pregunta previa no se pudo hacer. **Con el plazo sin avance de la revisión
    /// (`ICloudZoneScanEnd.stalledReason`) no se culpa a la conexión** (card dfja, lote N3): hasta ese día el texto decía
    /// «Puede ser la conexión» también cuando lo que venció fue la revisión, con la red bien. Cualquier otro motivo
    /// —un `CKError`, un registro que no se deja leer— conserva el texto de siempre, igual que la puerta privada del
    /// Welcome (`WelcomePrivateICloudGateLogic.wasStalled`).
    enum CheckFailedNotice: Equatable {
        /// No hay cuenta de iCloud a la que preguntar.
        case needsICloud
        /// La revisión dejó de avanzar.
        case stalled
        /// No se pudo preguntar por otra causa.
        case cannotCheck
    }

    /// El aviso de una pregunta que no se pudo hacer. `nil` para las respuestas que no son un fallo.
    static func checkFailedNotice(_ gate: Gate) -> CheckFailedNotice? {
        switch gate {
        case .needsICloud: return .needsICloud
        case .cannotCheck(let reason): return reason == ICloudZoneScanEnd.stalledReason ? .stalled : .cannotCheck
        case .proceed, .ask: return nil
        }
    }

    /// Título y cuerpo de cada aviso.
    static func checkFailedTitle(_ notice: CheckFailedNotice) -> String {
        switch notice {
        case .needsICloud: return L10n.Storage.Revert.Prior.noAccountTitle
        case .stalled: return L10n.Storage.Revert.Prior.stalledTitle
        case .cannotCheck: return L10n.Storage.Revert.Prior.checkFailedTitle
        }
    }

    static func checkFailedBody(_ notice: CheckFailedNotice) -> String {
        switch notice {
        case .needsICloud: return L10n.Storage.Revert.Prior.noAccountBody
        case .stalled: return L10n.Storage.Revert.Prior.stalledBody
        case .cannotCheck: return L10n.Storage.Revert.Prior.checkFailedBody
        }
    }

    /// Las cifras de lo que hay en tu iCloud, en el orden en que se leen (las usa la hoja de volver,
    /// `ReturnToICloudSheetLogic`). Vacío si ninguna casilla tiene nada que decir: el texto cae
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
}
