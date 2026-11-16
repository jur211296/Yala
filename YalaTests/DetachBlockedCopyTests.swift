//
//  DetachBlockedCopyTests.swift
//  YalaTests
//
//  El texto del aviso «No pudimos desasociar» de «¿Dónde viven tus datos?», recorrido como FUNCIÓN (ticket
//  `blocked-copy-mapping-lives-in-three-views-untestable`). Hasta el 2026-11-06 era un `switch` privado de
//  `GroupsAssociationSection` y solo lo vigilaban source-scans de ortografía: fijaban los literales que había, no que cada
//  motivo llegara a su frase. Ahora vive en `SignOutBlockedCopy.detachBlockedMessage(for:)`, con Ajustes y el Welcome.
//
//  La tabla es EXHAUSTIVA sobre `BlockReason.allCases`: un motivo nuevo que nadie clasifique aquí pone rojo
//  `everyReason_isClassified`, igual que el compilador obliga a pronunciarlo en el `switch`.
//

import Testing

@testable import Yala

@MainActor
@Suite("Desasociar · qué dice el aviso cuando se bloquea, por motivo")
struct DetachBlockedCopyTests {

    private typealias Reason = CloudSignOutFlowLogic.BlockReason

    private static func copy(_ notice: CloudSignOutFlowLogic.DetachBlockedNotice?) -> String {
        SignOutBlockedCopy.detachBlockedMessage(for: notice)
    }

    /// Los motivos cuyo hecho es el mismo en el cierre de sesión y en el desasociar: el texto se COMPARTE, y el título del
    /// aviso ya dice cuál de los dos gestos falló.
    private static let sharedWithSignOut: Set<Reason> = [
        .channelPaused, .attestUnavailable, .groupsChangesFromAnotherAccount, .uploadRetryLater, .groupsCaptureUnfinished,
    ]

    /// Los que el desasociar dice con su propio texto: hablan de soltar la cuenta, no de cerrar la sesión.
    private static var ownText: [Reason: String] {
        [
            .sessionExpired: L10n.Storage.Groups.detachBlockedSession,
            .permanent: L10n.Storage.Groups.detachBlockedPermanent,
            .bridgeUnreadable: L10n.Storage.Groups.detachBlockedBridge,
            .sessionNotClosed: L10n.Storage.Groups.detachBlockedSessionNotClosed,
            .detachBusy: L10n.Storage.Groups.detachBusy,
        ]
    }

    /// El resto no llega a este gesto (los pone solo un cierre de sesión) o es el outbox que aún drena: el texto que no
    /// afirma ninguna causa concreta.
    private static let generic: Set<Reason> = [
        .transient, .exportUnconfirmed, .personalAttestUnavailable, .syncStoppedNeedsUpdate, .syncStoppedMidMigration,
        .syncStoppedNeedsRelaunch, .personalUploadRetryLater, .cloudSessionExpired, .signOutSessionSurvived,
        .migrationInFlight, .migrationUnreadable, .personalCaptureUnfinished,
    ]

    @Test("Cada motivo está en una sola clase de la tabla")
    func everyReason_isClassified() {
        let own = Set(Self.ownText.keys)
        for reason in Reason.allCases {
            let classes = [Self.sharedWithSignOut.contains(reason), own.contains(reason), Self.generic.contains(reason)]
            #expect(classes.filter { $0 }.count == 1, "\(reason) no está en exactamente una clase de la tabla")
        }
    }

    @Test("Lo que comparte hecho con el cierre de sesión dice el MISMO texto que el cierre")
    func sharedReasons_sayWhatTheSignOutSays() {
        for reason in Self.sharedWithSignOut {
            #expect(Self.copy(.reason(reason)) == SignOutBlockedCopy.message(for: reason), "\(reason)")
            #expect(Self.copy(.reason(reason)) != L10n.Storage.Groups.detachBlockedTransient, """
                \(reason) cae en «inténtalo en un momento», que esperar no arregla
                """)
        }
    }

    @Test("Lo propio del desasociar dice su texto")
    func ownReasons_sayTheirOwnText() {
        for (reason, text) in Self.ownText {
            #expect(Self.copy(.reason(reason)) == text, "\(reason)")
        }
    }

    @Test("El resto, y el aviso ausente, el texto que no afirma causa")
    func everythingElse_saysTheGenericText() {
        for reason in Self.generic {
            #expect(Self.copy(.reason(reason)) == L10n.Storage.Groups.detachBlockedTransient, "\(reason)")
        }
        #expect(Self.copy(nil) == L10n.Storage.Groups.detachBlockedTransient)
    }

    @Test("Con la captura atascada y otra causa, el texto nombra las dos")
    func twoCauses_nameBoth() {
        #expect(Self.copy(.alsoCaptureUnfinished(.noSession))
                == L10n.Storage.Groups.detachBlockedSessionAndCaptureUnfinished)
        #expect(Self.copy(.alsoCaptureUnfinished(.attestUnavailable))
                == L10n.Storage.Groups.detachBlockedAttestAndCaptureUnfinished)
        #expect(Self.copy(.alsoCaptureUnfinished(.otherAccount))
                == L10n.Storage.Groups.detachBlockedOtherAccountAndCaptureUnfinished)
    }

    /// Control de que la tabla discrimina: si los textos coincidieran, las aserciones de arriba pasarían con un mapeo que
    /// lo mandara todo al mismo sitio.
    @Test("Los textos de las clases son distintos entre sí")
    func theTexts_areDistinct() {
        var texts: Set<String> = [L10n.Storage.Groups.detachBlockedTransient]
        for reason in Self.sharedWithSignOut { texts.insert(Self.copy(.reason(reason))) }
        for text in Self.ownText.values { texts.insert(text) }
        #expect(texts.count == 1 + Self.sharedWithSignOut.count + Self.ownText.count)
    }
}
