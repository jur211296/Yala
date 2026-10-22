//
//  SharedContainerServiceTests.swift
//  YalaTests
//

import Foundation
import Testing
@testable import Yala

@Suite("SharedContainerService")
struct SharedContainerServiceTests {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/PendingImages/\(name)")
    }

    @Test func ordersByCreationDateDescending() {
        let older = url("older.jpg")
        let newest = url("newest.jpg")
        let middle = url("middle.jpg")
        let input: [(url: URL, date: Date)] = [
            (older, Date(timeIntervalSince1970: 100)),
            (newest, Date(timeIntervalSince1970: 300)),
            (middle, Date(timeIntervalSince1970: 200)),
        ]
        let ordered = SharedContainerService.orderByCreationDescending(input)
        #expect(ordered == [newest, middle, older])
        // `.first` (lo que consume la recuperación) es la imagen más reciente.
        #expect(ordered.first == newest)
    }

    @Test func emptyInput_returnsEmpty() {
        #expect(SharedContainerService.orderByCreationDescending([]).isEmpty)
    }

    @Test func singleItem_returnsIt() {
        let only = url("only.jpg")
        #expect(SharedContainerService.orderByCreationDescending([(only, Date(timeIntervalSince1970: 1))]) == [only])
    }
}
