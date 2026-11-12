//
//  AppVersionInfo.swift
//  Yala
//
//  El pie de Ajustes («Versión 2.1 (Build 16)») sale del bundle, no de un texto fijo.
//  Hasta el lote 16 de la auditoría UX 2.2 decía «Versión 1.0.0 (Build 1)» en cualquier versión,
//  y quien mandaba una captura a soporte daba una versión falsa.
//

import Foundation

enum AppVersionInfo {
    /// Versión de marketing y build del diccionario `Info.plist` dado. Sin valor, «?» (como el formulario de soporte).
    static func versionAndBuild(from info: [String: Any]?) -> (version: String, build: String) {
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        return (nonEmpty(version) ?? "?", nonEmpty(build) ?? "?")
    }

    /// Texto del pie de Ajustes con la versión real de la app.
    static func footer(info: [String: Any]? = Bundle.main.infoDictionary) -> String {
        let parts = versionAndBuild(from: info)
        return L10n.Settings.versionInfo(version: parts.version, build: parts.build)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
