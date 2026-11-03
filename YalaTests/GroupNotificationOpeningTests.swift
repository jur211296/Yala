//
//  GroupNotificationOpeningTests.swift
//  YalaTests
//
//  Card th4n: la marca del aviso de grupo tocado. Solo la consume la apertura de ESE grupo y caduca: una apertura
//  posterior por otro camino (un enlace, «Ver grupo») no se toma por la del aviso, que espera a la red.
//

import Foundation
import Testing
@testable import Yala

@Suite("Aviso de grupo tocado — la marca de la apertura")
@MainActor
struct GroupNotificationOpeningTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func theSameGroup_consumesItOnce() {
        let opening = GroupNotificationOpening()
        opening.request("g-1", now: start)
        #expect(opening.consume(matching: "g-1", now: start.addingTimeInterval(2)))
        #expect(!opening.consume(matching: "g-1", now: start.addingTimeInterval(3)), "La marca se consumió dos veces.")
    }

    @Test func anotherGroup_doesNotConsumeIt() {
        let opening = GroupNotificationOpening()
        opening.request("g-1", now: start)
        #expect(!opening.consume(matching: "g-2", now: start))
        #expect(opening.consume(matching: "g-1", now: start), "Otro grupo se llevó la marca del aviso.")
    }

    /// Pasado su rato, la marca ya no vale (y se olvida): el grupo no llegó a abrirse desde el aviso.
    @Test func anExpiredMark_doesNotCount() {
        let opening = GroupNotificationOpening()
        opening.request("g-1", now: start)
        #expect(!opening.consume(matching: "g-1", now: start.addingTimeInterval(GroupNotificationOpening.lifetime + 1)))
        #expect(!opening.consume(matching: "g-1", now: start))
    }
}
