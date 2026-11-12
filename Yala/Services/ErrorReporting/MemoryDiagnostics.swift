//
//  MemoryDiagnostics.swift
//  Yala
//
//  Lo que Sentry sabe de la memoria de la app (YALA-IOS-B, 2026-11-12). Un cierre por memoria no deja stack y el SDK lo
//  reporta en el arranque siguiente con lo último que guardó del scope, así que lo útil es tener el scope al día:
//
//  - el contexto `memory` (memoria propia, la que queda antes del límite, el pico y la pestaña), que el SDK guarda en
//    disco y adjunta al próximo cierre por memoria;
//  - un rastro `memory` la primera vez que la app cruza cada escalón (256 MB, 512 MB…), para ver el camino;
//  - un rastro y un evento «Aviso de memoria baja» cuando iOS lo manda, el evento como mucho uno cada 10 min;
//  - un rastro y la etiqueta `screen` con la pestaña elegida.
//
//  Solo arranca si arrancó Sentry (`ErrorReportingService.start`). La lógica de qué y cuándo vive en
//  `MemoryDiagnosticsLogic`; aquí solo se mide y se llama al SDK.
//

import Foundation
import Sentry
import UIKit

@MainActor
final class MemoryDiagnostics {

    static let shared = MemoryDiagnostics()

    private var isStarted = false
    private var peakMB = 0
    private var lastPublishedMB: Int?
    private var screen: String?
    private var lastLowMemoryEventAt: Date?
    private var samplingTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { MemoryDiagnostics.shared.handleLowMemoryWarning() }
        })
        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { MemoryDiagnostics.shared.resumeSampling() }
        })
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { MemoryDiagnostics.shared.pauseSampling() }
        })
        // La pestaña de partida: el `didSet` solo avisa de los cambios, y quien se queda en el Panel llegaría sin ella.
        if let tab = SceneRegistry.shared.routingNavigation?.selectedMainTab { noteTab(tab) }
        sample()
        if UIApplication.shared.applicationState == .active { resumeSampling() }
    }

    /// La pestaña elegida (`SceneNavigation.selectedMainTab`) de la última ventana que cambió: con varias ventanas o una
    /// pantalla encima (bienvenida, hojas) no es necesariamente la que se ve. Con Sentry apagado no hace nada.
    func noteTab(_ tab: AppTab) {
        guard isStarted else { return }
        let name = MemoryDiagnosticsLogic.tabName(tab)
        guard name != screen else { return }
        screen = name
        let crumb = Breadcrumb(level: .info, category: MemoryDiagnosticsLogic.tabCategory)
        crumb.type = "navigation"
        crumb.setData(value: name, key: "tab")
        SentrySDK.addBreadcrumb(crumb)
        SentrySDK.configureScope { $0.setTag(value: name, key: MemoryDiagnosticsLogic.screenTag) }
        sample(screenChanged: true)
    }

    // MARK: - Medida

    private func resumeSampling() {
        sample()
        guard samplingTask == nil else { return }
        samplingTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: MemoryDiagnosticsLogic.samplingInterval)
                } catch {
                    return
                }
                MemoryDiagnostics.shared.sample()
            }
        }
    }

    private func pauseSampling() {
        sample()
        samplingTask?.cancel()
        samplingTask = nil
    }

    @discardableResult
    private func sample(screenChanged: Bool = false, force: Bool = false) -> (footprintMB: Int, availableMB: Int?)? {
        guard let reading = MemoryFootprint.current() else { return nil }
        let footprintMB = MemoryDiagnosticsLogic.megabytes(reading.footprintBytes)
        let availableMB = reading.availableBytes.map(MemoryDiagnosticsLogic.megabytes)
        if let step = MemoryDiagnosticsLogic.newlyCrossedStep(previousPeakMB: peakMB, currentMB: footprintMB) {
            let crumb = Breadcrumb(level: .info, category: MemoryDiagnosticsLogic.memoryCategory)
            crumb.message = "Escalón de memoria"
            for (key, value) in MemoryDiagnosticsLogic.breadcrumbData(
                footprintMB: footprintMB, availableMB: availableMB, stepMB: step
            ) {
                crumb.setData(value: value, key: key)
            }
            SentrySDK.addBreadcrumb(crumb)
        }
        peakMB = max(peakMB, footprintMB)
        if force || MemoryDiagnosticsLogic.shouldRepublish(
            lastPublishedMB: lastPublishedMB, currentMB: footprintMB, screenChanged: screenChanged
        ) {
            lastPublishedMB = footprintMB
            let context = MemoryDiagnosticsLogic.context(
                footprintMB: footprintMB, availableMB: availableMB, peakMB: peakMB, screen: screen
            )
            SentrySDK.configureScope { $0.setContext(value: context, key: MemoryDiagnosticsLogic.contextKey) }
        }
        return (footprintMB, availableMB)
    }

    private func handleLowMemoryWarning() {
        let reading = sample(force: true)
        let crumb = Breadcrumb(level: .warning, category: MemoryDiagnosticsLogic.memoryCategory)
        crumb.message = MemoryDiagnosticsLogic.lowMemoryMessage
        if let reading {
            for (key, value) in MemoryDiagnosticsLogic.breadcrumbData(
                footprintMB: reading.footprintMB, availableMB: reading.availableMB
            ) {
                crumb.setData(value: value, key: key)
            }
        }
        SentrySDK.addBreadcrumb(crumb)
        let now = Date()
        guard MemoryDiagnosticsLogic.shouldSendLowMemoryEvent(lastSentAt: lastLowMemoryEventAt, now: now) else { return }
        lastLowMemoryEventAt = now
        SentrySDK.capture(message: MemoryDiagnosticsLogic.lowMemoryMessage) { scope in
            scope.setLevel(.warning)
        }
    }
}
