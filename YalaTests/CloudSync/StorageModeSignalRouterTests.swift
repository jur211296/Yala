//
//  StorageModeSignalRouterTests.swift
//  YalaTests / CloudSync
//
//  Enrutado PURO de la fuente de quiescencia por `StorageMode` (I9, §i.2). Sin contexto ni red.
//

import Testing

@testable import Yala

@Suite("StorageModeSignalRouter · enrutado puro I9")
struct StorageModeSignalRouterTests {

    @Test func icloud_routesToICloudImport() {
        #expect(StorageModeSignalRouter.quiescenceSource(mode: .icloud) == .icloudImport)
    }

    @Test func cloud_routesToCloudEngine() {
        #expect(StorageModeSignalRouter.quiescenceSource(mode: .cloud) == .cloudEngine)
    }
}
