//
//  ErrorReportScrubLogicTests.swift
//  YalaTests
//
//  Lo que la app manda a Sentry no lleva importes, correos ni tokens, y el SDK no arranca con un DSN roto.
//

import Foundation
import Testing

@testable import Yala

@Suite("Sentry · limpieza de los avisos")
struct ErrorReportScrubLogicTests {

    @Test("tapa correos, importes y tokens")
    func scrubsPersonalAndFinancialData() {
        let out = ErrorReportScrubLogic.scrubText(
            "ana.perez@gmail.com pagó S/ 123.45, $9 y 1,234.50 PEN 20; Bearer abc.def eyJhbGciOi.eyJzdWIi.sig sk-proj-abcdefgh123"
        )
        for leak in ["ana.perez", "gmail", "123.45", "$9", "1,234.50", "PEN 20", "abc.def", "eyJ", "sk-proj"] {
            #expect(!out.contains(leak), "se coló «\(leak)» en «\(out)»")
        }
        #expect(out.contains("[email]"))
        #expect(out.contains("[monto]"))
        #expect(out.contains("[token]"))
    }

    @Test("deja lo que no es dato del usuario")
    func keepsTechnicalText() {
        let text = "NSCocoaErrorDomain 134060: el store no abrió (status 500)"
        #expect(ErrorReportScrubLogic.scrubText(text) == text)
    }

    @Test("deja ver los segundos de un cuelgue")
    func keepsHangDurations() {
        let title = "App hanging between 2.0 and 3.0 seconds."
        #expect(ErrorReportScrubLogic.scrubText(title) == title)
        #expect(ErrorReportScrubLogic.scrubText("App hanging for 12.5 seconds.") == "App hanging for 12.5 seconds.")
        #expect(ErrorReportScrubLogic.scrubText("App hanging for 1 second") == "App hanging for 1 second")
    }

    @Test("un importe junto a la duración de un cuelgue se sigue tapando")
    func stillScrubsAmountsNextToDurations() {
        let out = ErrorReportScrubLogic.scrubText("pagó 123.45 y la app colgó between 2.0 and 3.0 seconds; S/ 9.90 seconds")
        #expect(!out.contains("123.45"), "se coló el importe en «\(out)»")
        #expect(!out.contains("9.90"), "se coló el importe con símbolo en «\(out)»")
        #expect(out.contains("between 2.0 and 3.0 seconds"))
        // Una cifra seguida de otra palabra no es una duración.
        #expect(ErrorReportScrubLogic.scrubText("between 2.0 and 3.0 soles") == "between [monto] and [monto] soles")
    }

    @Test("la URL pierde query y fragmento")
    func stripsQuery() {
        #expect(ErrorReportScrubLogic.stripQuery("https://gw.example/rates/live?base=PEN#x") == "https://gw.example/rates/live")
        #expect(ErrorReportScrubLogic.stripQuery("https://gw.example/healthz") == "https://gw.example/healthz")
    }

    @Test("un breadcrumb HTTP conserva método, ruta y status; los demás pierden sus datos")
    func breadcrumbData() {
        let http = ErrorReportScrubLogic.breadcrumbData(
            category: "http",
            type: "http",
            data: ["method": "POST", "url": "https://gw.example/sync/push?from=2026", "status_code": 500, "request_body_size": 120]
        )
        #expect(http?["method"] as? String == "POST")
        #expect(http?["url"] as? String == "https://gw.example/sync/push")
        #expect(http?["status_code"] as? Int == 500)
        #expect(http?["request_body_size"] == nil)

        let touch = ErrorReportScrubLogic.breadcrumbData(category: "touch", type: "user", data: ["view": "Cena con Ana · S/ 80"])
        #expect(touch == nil)
    }

    @Test("sin un DSN usable el SDK no arranca")
    func usableDSN() {
        #expect(ErrorReportScrubLogic.usableDSN(nil) == nil)
        #expect(ErrorReportScrubLogic.usableDSN("") == nil)
        #expect(ErrorReportScrubLogic.usableDSN("$(SENTRY_DSN)") == nil)
        // El `//` del xcconfig corta el DSN escrito sin `$()`: queda «https:».
        #expect(ErrorReportScrubLogic.usableDSN("https:") == nil)
        #expect(ErrorReportScrubLogic.usableDSN(" https://k@o1.ingest.us.sentry.io/2 ") == "https://k@o1.ingest.us.sentry.io/2")
    }
}
