//
//  PhotoUploadSizing.swift
//  Yala
//
//  A qué tamaño sube la app una foto para leerla (sesión 2 del gateway de IA, paso 6). Nunca más píxeles de los que
//  el modelo elegido aprovecha: el gateway publica en `/config` el `maxEdge` de su fila `photo.read` (1536 px según el
//  banco del 2026-10-07, `docs/ai-model-bench-2026-10.md`) y la app reduce antes de subir. Menos megas por datos
//  móviles y más lejos del corte de 20 s. Puro, para probarlo sin simulador.
//

import CoreGraphics

enum PhotoUploadSizing {
    /// El valor medido por el banco. Se usa si el gateway aún no lo ha dicho (primer arranque, `/config` sin red).
    nonisolated static let defaultMaxEdge = 1536

    /// El lado mayor que se usa: el del gateway si es razonable; si no, el de por defecto. Un valor fuera de rango no
    /// puede venir del gateway sano, y subir una foto de 50 px o de 20 000 sería peor que el por defecto.
    nonisolated static func maxEdge(remote: Int?) -> Int {
        guard let remote, (512...4096).contains(remote) else { return defaultMaxEdge }
        return remote
    }

    /// Tamaño en PÍXELES al que reducir una foto de `pixelSize`, conservando la proporción. `nil` = ya cabe y se manda
    /// tal cual (nunca se amplía).
    nonisolated static func targetPixelSize(for pixelSize: CGSize, maxEdge: Int) -> CGSize? {
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > CGFloat(maxEdge), longest > 0 else { return nil }
        let factor = CGFloat(maxEdge) / longest
        return CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
    }
}
