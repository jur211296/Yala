//
//  SharedImageBatch.swift
//  YalaWidgets
//
//  Las fotos compartidas a Yala de una vez viajan juntas por `PendingImages/` (ticket
//  tablero-yala-no-aparece-al-compartir-varias-capt-3ut5, 2026-10-11). La tanda va en el NOMBRE de cada fichero, no en
//  el router: la app sigue llevando una URL (`.presentSharedImage(url)`) y la hoja de lectura la expande a su tanda.
//  Así la recuperación del arranque, el aplazamiento y el buffer en disco siguen igual que con una foto.
//
//  Membership: Yala main + YalaShare (vía exception sets en pbxproj, como `WidgetURLHelper`). La extensión escribe con
//  `fileName`; la app lee con `member(fromFileName:)` y `batch(containing:among:)`.
//

import Foundation

nonisolated enum SharedImageBatch {
    /// Fotos que se leen por vez: el mismo tope que el selector de Fotos y los PDF (`PDFPageImport.maxPagesPerBatch`;
    /// un test lo ata).
    nonisolated static let maxImages = 10

    /// Hasta cuántas fotos aparece Yala en el menú de compartir: `NSExtensionActivationSupportsImageWithMaxCount` de
    /// `YalaShare/Info.plist` (un test lo ata). Por encima de `maxImages` Yala aparece igual, lee las primeras y avisa
    /// de las demás: con el tope en la activación desaparecería del menú sin decir nada.
    nonisolated static let maxSharedImages = 100

    /// Sufijo de una foto a medio escribir. `pendingImageURLs` filtra por extensión, así que la recuperación no ve una
    /// tanda hasta que la extensión las renombra todas.
    nonisolated static let partialSuffix = ".part"

    private nonisolated static let prefix = "batch"
    private nonisolated static let separator: Character = "_"

    /// Una foto de una tanda: a qué tanda pertenece, su posición y cuántas fotos se compartieron en total (también las
    /// que no entraron por el tope).
    nonisolated struct Member: Equatable {
        let batchID: String
        let index: Int
        let sharedCount: Int
    }

    /// Un identificador de tanda sin separadores dentro.
    nonisolated static func newBatchID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    /// `batch_<tanda>_<posición>_<compartidas>.jpg`. La posición va con dos cifras para que el orden alfabético sea el
    /// de la tanda.
    nonisolated static func fileName(batchID: String, index: Int, sharedCount: Int) -> String {
        "\(prefix)\(separator)\(batchID)\(separator)\(String(format: "%02d", index))\(separator)\(sharedCount).jpg"
    }

    /// `nil` para un fichero que no es de una tanda: los de antes (`<UUID>.jpg`) y los recibos soltados en el iPad.
    nonisolated static func member(fromFileName name: String) -> Member? {
        let stem = (name as NSString).deletingPathExtension
        let parts = stem.split(separator: separator, omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == Substring(prefix), !parts[1].isEmpty,
              let index = Int(parts[2]), let shared = Int(parts[3]),
              index >= 0, shared > index
        else { return nil }
        return Member(batchID: String(parts[1]), index: index, sharedCount: shared)
    }

    /// Las fotos de la tanda de `url`, en su orden. Un fichero sin tanda es una tanda de uno.
    nonisolated static func batch(containing url: URL, among candidates: [URL]) -> [URL] {
        guard let anchor = member(fromFileName: url.lastPathComponent) else { return [url] }
        var members: [(url: URL, index: Int)] = []
        for candidate in candidates {
            guard let found = member(fromFileName: candidate.lastPathComponent),
                  found.batchID == anchor.batchID else { continue }
            members.append((candidate, found.index))
        }
        if !members.contains(where: { $0.url.lastPathComponent == url.lastPathComponent }) {
            members.append((url, anchor.index))
        }
        return members.sorted { $0.index < $1.index }.map(\.url)
    }

    /// Cuántas fotos de la tanda de `url` no entraron por el tope. Sale de lo COMPARTIDO, no de lo encontrado: una foto
    /// que la extensión no pudo cargar no es una que el tope dejó fuera.
    nonisolated static func leftOutCount(for url: URL) -> Int {
        guard let anchor = member(fromFileName: url.lastPathComponent) else { return 0 }
        return max(0, anchor.sharedCount - maxImages)
    }
}
