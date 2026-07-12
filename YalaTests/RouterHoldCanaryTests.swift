//
//  RouterHoldCanaryTests.swift
//  YalaTests
//
//  Canario D4: reporta holds SOSTENIDOS (intent aún en cola al vencer el
//  deadline) una sola vez por intent; drenar o salir de la cola cancela.
//  Instancias con dependencias inyectadas — sin singletons, sin .serialized.
//  Sleeps ≤50ms (excepción documentada del repo para forzar deadlines).
//

import Foundation
import Testing
@testable import Yala

@MainActor
private final class ReportBox {
    var reports: [(blocker: String, consumer: String)] = []
}

@Suite("RouterHoldCanary")
@MainActor
struct RouterHoldCanaryTests {

    private func makeSUT(
        stillQueued: @escaping (String) -> Bool = { _ in true }
    ) -> (RouterHoldCanary, ReportBox) {
        let box = ReportBox()
        let sut = RouterHoldCanary(
            threshold: .milliseconds(20),
            stillQueued: stillQueued,
            report: { blocker, consumer in box.reports.append((blocker, consumer)) }
        )
        return (sut, box)
    }

    @Test func sustainedHold_reportsOnce_withBlockerAndConsumer() async throws {
        let (sut, box) = makeSUT()
        sut.noteHold(intentID: "trialExpired", blocker: "proTrialOffer", consumer: "mainTab")
        // Holds repetidos del mismo intent no re-arman ni duplican.
        sut.noteHold(intentID: "trialExpired", blocker: "proTrialOffer", consumer: "mainTab")
        try await Task.sleep(for: .milliseconds(50))
        #expect(box.reports.count == 1)
        #expect(box.reports.first?.blocker == "proTrialOffer")
        #expect(box.reports.first?.consumer == "mainTab")
    }

    @Test func drainedBeforeDeadline_neverReports() async throws {
        let (sut, box) = makeSUT()
        sut.noteHold(intentID: "presentInboxSheet", blocker: "whatsNew", consumer: "panel")
        sut.noteDrained(intentID: "presentInboxSheet")
        try await Task.sleep(for: .milliseconds(50))
        #expect(box.reports.isEmpty)
    }

    @Test func dequeuedElsewhere_neverReports() async throws {
        // Dropeado en background (resetTransients) o supersedido: ya no está
        // en cola al vencer el deadline → no es un hold pegado, no reporta.
        let (sut, box) = makeSUT(stillQueued: { _ in false })
        sut.noteHold(intentID: "milestone:10", blocker: "syncSettingsSheet", consumer: "mainTab")
        try await Task.sleep(for: .milliseconds(50))
        #expect(box.reports.isEmpty)
    }

    @Test func distinctIntents_reportIndependently() async throws {
        let (sut, box) = makeSUT()
        sut.noteHold(intentID: "a", blocker: "proTrialOffer", consumer: "mainTab")
        sut.noteHold(intentID: "b", blocker: "proTrialOffer", consumer: "panel")
        try await Task.sleep(for: .milliseconds(50))
        #expect(box.reports.count == 2)
    }

    @Test func drainedThenHeldAgain_reArmsWatch() async throws {
        let (sut, box) = makeSUT()
        sut.noteHold(intentID: "x", blocker: "whatsNew", consumer: "panel")
        sut.noteDrained(intentID: "x")
        // Un intent futuro con el mismo id vuelve a vigilarse desde cero.
        sut.noteHold(intentID: "x", blocker: "proTrialOffer", consumer: "panel")
        try await Task.sleep(for: .milliseconds(50))
        #expect(box.reports.count == 1)
        #expect(box.reports.first?.blocker == "proTrialOffer")
    }
}
