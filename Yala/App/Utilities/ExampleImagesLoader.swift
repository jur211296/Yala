//
//  ExampleImagesLoader.swift
//  Yala
//
//  Loader compartido para las 3 example images bundled del setup trial de imagen
//  (recibo, alerta bancaria, lista de transacciones). Disponibilidad por locale:
//  de, en, es, fr, it, pt — el resto cae a "en".
//

import UIKit

enum ExampleImagesLoader {
    private static let supportedLangs: Set<String> = ["de", "en", "es", "fr", "it", "pt"]

    static func load() -> [UIImage]? {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        let suffix = supportedLangs.contains(lang) ? lang : "en"
        let names = [
            "ExampleImages/example-receipt-\(suffix)",
            "ExampleImages/example-bank-alert-\(suffix)",
            "ExampleImages/example-transaction-list-\(suffix)"
        ]
        let loaded = names.compactMap { UIImage(named: $0) }
        return loaded.isEmpty ? nil : loaded
    }
}
