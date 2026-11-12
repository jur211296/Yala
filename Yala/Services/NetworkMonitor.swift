//
//  NetworkMonitor.swift
//  Yala
//
//  Simple network connectivity monitor using NWPathMonitor.
//

import Foundation
import Network

/// Monitors network connectivity status.
@MainActor @Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private(set) var isConnected = true

    private init() {
        #if DEBUG
        // `-uitest-network-offline`: sin conexión fija, sin escuchar a la red del simulador.
        if UITestHooks.networkOffline {
            isConnected = false
            return
        }
        #endif
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
