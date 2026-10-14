//
//  String+Capitalization.swift
//  Yala
//
//  Mayúscula inicial para textos que el sistema da en minúscula (meses, días).
//

import Foundation

extension String {
    /// La primera letra en mayúscula y el resto como viene. `capitalized` pone mayúscula en CADA palabra, y un mes con
    /// año en español sale «Octubre De 2026» en vez de «Octubre de 2026» (auditoría UX 2.2, lote 8).
    func capitalizingFirstLetter(locale: Locale) -> String {
        guard let first else { return self }
        return String(first).uppercased(with: locale) + dropFirst()
    }
}
