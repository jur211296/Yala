//
//  WidgetRenderApp.swift
//  WidgetRender
//
//  Arranca, carga la foto del App Group que se le pasa, fija el reloj a la hora de esa foto, pinta el catálogo en
//  `Documents/out/` y deja `done.txt`. `render.sh` lo lanza y recoge los PNG.
//
//  Argumentos: `-snapshot <plist>` (obligatorio: el plist del App Group exportado del simulador),
//  `-clock <segundos desde 1970>` (opcional: por defecto, `lastUpdated` de la foto), `-only <slug>` (opcional).
//

import SwiftUI
import WidgetKit

@main
struct WidgetRenderApp: App {
    @State private var status = "Pintando…"

    var body: some Scene {
        WindowGroup {
            Text(status)
                .padding()
                .task { status = await RenderRun.run() }
        }
    }
}

@MainActor
enum RenderRun {
    static func run() async -> String {
        let defaults = UserDefaults.standard
        guard let snapshotPath = defaults.string(forKey: "snapshot") else {
            return "Falta -snapshot <plist>"
        }
        guard let values = NSDictionary(contentsOfFile: snapshotPath) as? [String: Any] else {
            return "No pude leer \(snapshotPath)"
        }
        let suiteName = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String ?? "widgetrender.shared"
        guard let suite = UserDefaults(suiteName: suiteName) else { return "Sin suite \(suiteName)" }
        for (key, value) in values { suite.set(value, forKey: key) }

        if let clock = defaults.object(forKey: "clock") as? Double ?? Double(defaults.string(forKey: "clock") ?? "") {
            RenderClock.fixed = Date(timeIntervalSince1970: clock)
        } else {
            RenderClock.fixed = WidgetDataService.loadSnapshot()?.lastUpdated
        }

        let only = defaults.string(forKey: "only")
        let outDir = URL.documentsDirectory.appending(path: "out")
        do {
            if FileManager.default.fileExists(atPath: outDir.path) {
                try FileManager.default.removeItem(at: outDir)
            }
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        } catch {
            return "WidgetRender: Error: \(error)"
        }

        var count = 0
        for item in Catalog.items() where only == nil || item.slug == only {
            for mode in item.modes {
                // StandBy solo enseña widgets pequeños.
                if mode == .standby && item.spec.family != .systemSmall { continue }
                let frame = RenderFrame(spec: item.spec, background: item.background, mode: mode) { item.view() }
                let size = CGSize(
                    width: item.spec.size.width + RenderFrame<EmptyView>.canvasPadding * 2,
                    height: item.spec.size.height + RenderFrame<EmptyView>.canvasPadding * 2)
                let name = "\(item.slug)-\(item.spec.code)-\(mode.rawValue).png"
                Renderer.png(frame, size: size, to: outDir.appending(path: name))
                count += 1
                await Task.yield()
            }
        }
        let summary = "Pintadas \(count) capturas (reloj \(RenderClock.now))"
        do {
            try summary.write(to: outDir.appending(path: "done.txt"), atomically: true, encoding: .utf8)
        } catch {
            #if DEBUG
            print("WidgetRender: Error: \(error)")
            #endif
        }
        return summary
    }
}
