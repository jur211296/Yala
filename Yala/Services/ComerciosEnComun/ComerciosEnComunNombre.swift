//
//  ComerciosEnComunNombre.swift
//  Yala
//
//  «Comercios en común» (2.3, 2026-11-22): cómo se escribe un comercio antes de salir del teléfono y para buscarlo en la
//  lista común. Variante B de la propuesta: la limpieza de siempre (`MerchantCanonicalizer`) y, además, fuera números,
//  sucursal, calle, ciudad y razón social; si casa con una marca del banco de 666 (`MerchantCatalog`), esa marca.
//
//  «DP*STARBUCKS COFFEE MIRAFLORES 123» → «STARBUCKS» · «IZI*TAMBO+ AV LARCO 1153 LIMA» → «TAMBO»
//  «INVERSIONES LA LUCHA S.A.C.» → «INVERSIONES LA LUCHA» · «BOTICA SAN JOSE 2 SUC 14» → «BOTICA SAN JOSE»
//
//  La misma función limpia lo que se aporta y lo que se busca: si fueran dos, un comercio aportado no se encontraría.
//

import Foundation

enum ComerciosEnComunNombre {

    /// Lo más largo que viaja. El servidor rechaza lo que pase de 40.
    static let maxLength = 40

    /// Palabras que abren una dirección o una sucursal: desde ahí, todo fuera.
    static let addressMarkers: Set<String> = [
        "AV", "AVDA", "AVENIDA", "JR", "JIRON", "JIRÓN", "CALLE", "CAL", "CA", "PSJE", "PASAJE", "MZ", "MZA", "LT", "LOTE",
        "SUC", "SUCURSAL", "KM", "URB", "NRO", "NUM", "Nº", "CC", "TDA", "LOCAL", "STAND", "PISO",
    ]

    /// Razón social al final del nombre («S.A.C.» llega como «SAC» tras la limpieza de símbolos).
    static let legalSuffixes: Set<String> = ["SAC", "SAA", "SA", "SRL", "EIRL", "LTDA", "INC", "LLC", "CORP", "SL", "SAS"]

    /// Ciudades y distritos (empieza con Perú, como dice la propuesta), solo AL FINAL del nombre.
    static let trailingPlaces: [[String]] = [
        ["SAN", "JUAN", "DE", "LURIGANCHO"], ["SAN", "JUAN", "DE", "MIRAFLORES"], ["SANTIAGO", "DE", "SURCO"],
        ["SAN", "MARTIN", "DE", "PORRES"], ["VILLA", "EL", "SALVADOR"], ["VILLA", "MARIA", "DEL", "TRIUNFO"],
        ["SAN", "ISIDRO"], ["SAN", "BORJA"], ["SAN", "MIGUEL"], ["SAN", "LUIS"], ["JESUS", "MARIA"], ["LA", "MOLINA"],
        ["LA", "VICTORIA"], ["PUEBLO", "LIBRE"], ["LOS", "OLIVOS"], ["SANTA", "ANITA"], ["LA", "PERLA"],
        ["MAGDALENA", "DEL", "MAR"], ["CERCADO", "DE", "LIMA"], ["PUENTE", "PIEDRA"], ["ATE", "VITARTE"],
        ["MIRAFLORES"], ["SURCO"], ["BARRANCO"], ["LINCE"], ["BREÑA"], ["BRENA"], ["SURQUILLO"], ["CHORRILLOS"],
        ["MAGDALENA"], ["RIMAC"], ["RÍMAC"], ["COMAS"], ["INDEPENDENCIA"], ["CALLAO"], ["ATE"], ["CARABAYLLO"],
        ["LIMA"], ["AREQUIPA"], ["CUSCO"], ["TRUJILLO"], ["PIURA"], ["CHICLAYO"], ["IQUITOS"], ["HUANCAYO"], ["TACNA"],
        ["ICA"], ["PUNO"], ["CAJAMARCA"], ["PERU"], ["PERÚ"], ["PE"],
    ]

    /// El nombre limpio, o `nil` si no queda nada que valga (sin letras, una sola letra).
    static func clean(_ raw: String) -> String? {
        // El prefijo del procesador («DP*», «IZI*») fuera antes de buscar la marca: con él no casa.
        let canonical = MerchantCanonicalizer.canonicalize(raw)
        if let brand = MerchantCatalog.match(name: canonical) {
            return bounded(MerchantCanonicalizer.canonicalize(brand.name))
        }
        var tokens = canonical.split(separator: " ").map(String.init)

        if let cut = tokens.firstIndex(where: { addressMarkers.contains($0) }), cut > 0 {
            tokens = Array(tokens[..<cut])
        }
        tokens.removeAll { $0.contains(where: \.isNumber) }

        var changed = true
        while changed, tokens.count > 1 {
            changed = false
            if let last = tokens.last, legalSuffixes.contains(last) {
                tokens.removeLast()
                changed = true
                continue
            }
            for place in trailingPlaces where tokens.count > place.count && Array(tokens.suffix(place.count)) == place {
                tokens.removeLast(place.count)
                changed = true
                break
            }
        }
        return bounded(tokens.joined(separator: " "))
    }

    private static func bounded(_ text: String) -> String? {
        var value = text.trimmingCharacters(in: .whitespaces)
        if value.count > maxLength {
            value = String(value.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        }
        guard value.count >= 2, value.contains(where: \.isLetter) else { return nil }
        return value
    }
}
