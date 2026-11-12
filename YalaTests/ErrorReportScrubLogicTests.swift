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
