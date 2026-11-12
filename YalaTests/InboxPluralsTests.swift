//
//  InboxPluralsTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 4 · B1. La Bandeja decía «1 pendientes», «1 seleccionados», «2 de 3 listo(s) para aprobar»,
//  «¿eliminar 1 borrador(es)?» y, en el aviso al abrir, «2 pagos y 1 suscripciones y 1 registros automáticos». Ahora
//  esas claves viven en el `.stringsdict` de cada idioma base, y la lista del aviso la une el formateador del idioma.
//
//  Se mide contra el `.lproj` de cada idioma, no contra `L10n`: el idioma del proceso de test no es fijo, y lo que hay
//  que probar es lo que verá alguien con ese idioma.
//

import Foundation
import Testing

@testable import Yala

struct InboxPluralsTests {

    private func format(_ key: String, _ code: String, _ args: CVarArg...) -> String {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
            Issue.record("Falta \(code).lproj")
            return ""
        }
        let format = bundle.localizedString(forKey: key, value: "__FALTA__", table: nil)
        return String(format: format, locale: Locale(identifier: code), arguments: args)
    }

    @Test func spanish_singularAndPlural() {
        #expect(format("inbox.pendingBadge", "es-419", 1) == "1 pendiente")
        #expect(format("inbox.pendingBadge", "es-419", 3) == "3 pendientes")
        #expect(format("inbox.selectedCount", "es-419", 1) == "1 seleccionado")
        #expect(format("inbox.selectedCount", "es-419", 0) == "0 seleccionados")
        #expect(format("inbox.deleteConfirmMessage", "es-419", 1) == "¿Estás seguro de eliminar 1 borrador?")
        #expect(format("inbox.deleteConfirmMessage", "es-419", 2) == "¿Estás seguro de eliminar 2 borradores?")
        #expect(format("inbox.alert.message.scheduled", "es-419", 1) == "Se añadió 1 pago planificado a tu bandeja.")
        #expect(format("inbox.alert.message.subscriptions", "es-419", 1) == "Se añadió 1 suscripción a tu bandeja.")
        #expect(format("inbox.alert.message.mixed.automations", "es-419", 1) == "1 registro automático")
    }

    /// Dos argumentos: el plural lo decide el PRIMERO (los listos), no el total. Con el verbo de la app, «guardar», y
    /// no «aprobar» (UX 2.2 · L4-4).
    @Test func approveableCount_pluralFollowsTheReadyCount() {
        #expect(format("inbox.approveableCount", "es-419", 1, 3) == "1 de 3 listo para guardar")
        #expect(format("inbox.approveableCount", "es-419", 2, 3) == "2 de 3 listos para guardar")
        #expect(format("inbox.approveableCount", "fr", 1, 3) == "1 sur 3 prêt à enregistrer")
    }

    /// El alias `es` es copia de `es-419`: lo que ve quien tiene el iPhone en «Español» a secas.
    @Test func spanishAlias_matchesReference() {
        #expect(format("inbox.pendingBadge", "es", 1) == "1 pendiente")
    }

    @Test func polish_usesFewAndMany() {
        #expect(format("inbox.alert.message.mixed.subscriptions", "pl", 1) == "1 subskrypcja")
        #expect(format("inbox.alert.message.mixed.subscriptions", "pl", 2) == "2 subskrypcje")
        #expect(format("inbox.alert.message.mixed.subscriptions", "pl", 5) == "5 subskrypcji")
    }

    /// «Delete %d draft(s)?» estaba en inglés en alemán, francés, italiano y portugués.
    @Test func deleteConfirm_isTranslated() {
        for code in ["de", "fr", "it", "pt-BR", "pt"] {
            #expect(!format("inbox.deleteConfirmMessage", code, 2).contains("Delete"), "\(code) sigue en inglés")
        }
    }

    @Test func mixedBreakdown_joinsLikeTheLanguage() {
        let es = PendingInboxNotification.joinedBreakdown(
            ["2 pagos", "1 suscripción", "1 registro automático"], locale: Locale(identifier: "es"))
        #expect(es == "2 pagos, 1 suscripción y 1 registro automático")

        let two = PendingInboxNotification.joinedBreakdown(["2 pagos", "1 suscripción"], locale: Locale(identifier: "es"))
        #expect(two == "2 pagos y 1 suscripción")

        let one = PendingInboxNotification.joinedBreakdown(["2 pagos"], locale: Locale(identifier: "es"))
        #expect(one == "2 pagos")
    }

    /// B2: VoiceOver leía el estado crudo del enum («pending», «rejected») en todos los idiomas.
    @Test func draftStatus_isLocalizedForVoiceOver() {
        guard let path = Bundle.main.path(forResource: "es-419", ofType: "lproj"), let bundle = Bundle(path: path) else {
            Issue.record("Falta es-419.lproj")
            return
        }
        let read = { (key: String) in bundle.localizedString(forKey: key, value: "__FALTA__", table: nil) }
        #expect(read("inbox.status.pending") == "pendiente")
        // «guardado» y «descartado»: los verbos que la persona ve en los botones (UX 2.2 · L4-4).
        #expect(read("inbox.status.approved") == "guardado")
        #expect(read("inbox.status.rejected") == "descartado")
        for status in [DraftStatus.pending, .approved, .rejected] {
            #expect(!L10n.Inbox.status(status).hasPrefix("inbox."), "Clave cruda para \(status)")
        }
    }

    /// B5: diez textos de la Bandeja seguían en inglés en alemán, francés, italiano y portugués («Edit draft», «Voice»…).
    @Test func inboxStrings_areNotLeftInEnglish() {
        let keys = ["inbox.editDraft", "inbox.cannotApprove", "inbox.sourceVoice", "inbox.sourceScreenshot",
                    "inbox.sourceScreenshotList", "inbox.sourceReceipt", "inbox.duplicateWarningTitle",
                    "inbox.duplicateWarningMessage", "inbox.createAnyway"]
        for code in ["de", "fr", "it", "pt-BR", "pt", "pt-PT"] {
            for key in keys {
                #expect(format(key, code) != format(key, "en"), "\(key) sigue en inglés en \(code)")
            }
        }
    }
}
