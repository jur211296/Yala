//
//  CurrencyUtils.swift
//  Yala
//
//  Utilidades para normalizar códigos de moneda y convertir montos.
//  IMPORTANTE: Para agregar una nueva divisa, solo edita el enum CurrencyCode.
//

import Foundation

// MARK: - Continent Enum

/// Enum de continentes para agrupar divisas en la UI.
enum Continent: String, CaseIterable, Identifiable {
    case latinAmerica
    case europe
    case asia
    case oceania
    case middleEast
    case africa
    case northAmerica

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .latinAmerica: return L10n.Continent.latinAmerica
        case .europe: return L10n.Continent.europe
        case .asia: return L10n.Continent.asia
        case .oceania: return L10n.Continent.oceania
        case .middleEast: return L10n.Continent.middleEast
        case .africa: return L10n.Continent.africa
        case .northAmerica: return L10n.Continent.northAmerica
        }
    }

    /// Orden de visualización en la UI
    var displayOrder: Int {
        switch self {
        case .latinAmerica: return 0
        case .northAmerica: return 1
        case .europe: return 2
        case .asia: return 3
        case .oceania: return 4
        case .middleEast: return 5
        case .africa: return 6
        }
    }
}

// MARK: - Currency Code Enum (Single Source of Truth)

/// Enum centralizado de divisas soportadas.
/// **Para agregar una nueva divisa:**
/// 1. Añade el case al enum (ej: `case ars = "ARS"`)
/// 2. Implementa las propiedades computadas (flag, symbol, aliases, etc.)
/// 3. Añade la key de localización en L10n.Currency
/// 4. Opcionalmente, añade mapeo de región en `regionMappings`
enum CurrencyCode: String, CaseIterable, Identifiable, Hashable, Equatable {
    // Latinoamérica
    case pen = "PEN"
    case usd = "USD"
    case mxn = "MXN"
    case cop = "COP"
    case brl = "BRL"
    case ars = "ARS"
    case clp = "CLP"
    case uyu = "UYU"
    case bob = "BOB"
    case pyg = "PYG"
    case crc = "CRC"
    case gtq = "GTQ"
    case hnl = "HNL"
    case nio = "NIO"
    case pab = "PAB"
    case dop = "DOP"

    // Europa
    case eur = "EUR"
    case gbp = "GBP"
    case chf = "CHF"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"
    case pln = "PLN"
    case czk = "CZK"
    case huf = "HUF"
    case ron = "RON"
    case rub = "RUB"
    case uah = "UAH"
    case `try` = "TRY"

    // Asia
    case jpy = "JPY"
    case cny = "CNY"
    case krw = "KRW"
    case inr = "INR"
    case idr = "IDR"
    case php = "PHP"
    case thb = "THB"
    case myr = "MYR"
    case sgd = "SGD"
    case hkd = "HKD"
    case twd = "TWD"
    case vnd = "VND"

    // Oceanía
    case aud = "AUD"
    case nzd = "NZD"

    // Medio Oriente
    case aed = "AED"
    case sar = "SAR"
    case ils = "ILS"
    case qar = "QAR"
    case kwd = "KWD"

    // África
    case zar = "ZAR"
    case egp = "EGP"
    case ngn = "NGN"
    case kes = "KES"
    case mad = "MAD"

    // Norteamérica
    case cad = "CAD"

    var id: String { rawValue }

    // MARK: - Display Properties

    /// Emoji de bandera para mostrar en UI
    var flag: String {
        switch self {
        // Latinoamérica
        case .pen: return "🇵🇪"
        case .usd: return "🇺🇸"
        case .mxn: return "🇲🇽"
        case .cop: return "🇨🇴"
        case .brl: return "🇧🇷"
        case .ars: return "🇦🇷"
        case .clp: return "🇨🇱"
        case .uyu: return "🇺🇾"
        case .bob: return "🇧🇴"
        case .pyg: return "🇵🇾"
        case .crc: return "🇨🇷"
        case .gtq: return "🇬🇹"
        case .hnl: return "🇭🇳"
        case .nio: return "🇳🇮"
        case .pab: return "🇵🇦"
        case .dop: return "🇩🇴"
        // Europa
        case .eur: return "🇪🇺"
        case .gbp: return "🇬🇧"
        case .chf: return "🇨🇭"
        case .sek: return "🇸🇪"
        case .nok: return "🇳🇴"
        case .dkk: return "🇩🇰"
        case .pln: return "🇵🇱"
        case .czk: return "🇨🇿"
        case .huf: return "🇭🇺"
        case .ron: return "🇷🇴"
        case .rub: return "🇷🇺"
        case .uah: return "🇺🇦"
        case .try: return "🇹🇷"
        // Asia
        case .jpy: return "🇯🇵"
        case .cny: return "🇨🇳"
        case .krw: return "🇰🇷"
        case .inr: return "🇮🇳"
        case .idr: return "🇮🇩"
        case .php: return "🇵🇭"
        case .thb: return "🇹🇭"
        case .myr: return "🇲🇾"
        case .sgd: return "🇸🇬"
        case .hkd: return "🇭🇰"
        case .twd: return "🇹🇼"
        case .vnd: return "🇻🇳"
        // Oceanía
        case .aud: return "🇦🇺"
        case .nzd: return "🇳🇿"
        // Medio Oriente
        case .aed: return "🇦🇪"
        case .sar: return "🇸🇦"
        case .ils: return "🇮🇱"
        case .qar: return "🇶🇦"
        case .kwd: return "🇰🇼"
        // África
        case .zar: return "🇿🇦"
        case .egp: return "🇪🇬"
        case .ngn: return "🇳🇬"
        case .kes: return "🇰🇪"
        case .mad: return "🇲🇦"
        // Norteamérica
        case .cad: return "🇨🇦"
        }
    }

    /// Símbolo corto de la moneda (para mostrar en cantidades)
    var symbol: String {
        switch self {
        // Latinoamérica
        case .pen: return "S/"
        case .usd: return "$"
        case .mxn: return "$"
        case .cop: return "$"
        case .brl: return "R$"
        case .ars: return "$"
        case .clp: return "$"
        case .uyu: return "$"
        case .bob: return "Bs"
        case .pyg: return "₲"
        case .crc: return "₡"
        case .gtq: return "Q"
        case .hnl: return "L"
        case .nio: return "C$"
        case .pab: return "B/."
        case .dop: return "RD$"
        // Europa
        case .eur: return "€"
        case .gbp: return "£"
        case .chf: return "Fr."
        case .sek: return "kr"
        case .nok: return "kr"
        case .dkk: return "kr"
        case .pln: return "zł"
        case .czk: return "Kč"
        case .huf: return "Ft"
        case .ron: return "lei"
        case .rub: return "₽"
        case .uah: return "₴"
        case .try: return "₺"
        // Asia
        case .jpy: return "¥"
        case .cny: return "¥"
        case .krw: return "₩"
        case .inr: return "₹"
        case .idr: return "Rp"
        case .php: return "₱"
        case .thb: return "฿"
        case .myr: return "RM"
        case .sgd: return "S$"
        case .hkd: return "HK$"
        case .twd: return "NT$"
        case .vnd: return "₫"
        // Oceanía
        case .aud: return "A$"
        case .nzd: return "NZ$"
        // Medio Oriente
        case .aed: return "د.إ"
        case .sar: return "﷼"
        case .ils: return "₪"
        case .qar: return "﷼"
        case .kwd: return "د.ك"
        // África
        case .zar: return "R"
        case .egp: return "E£"
        case .ngn: return "₦"
        case .kes: return "KSh"
        case .mad: return "د.م."
        // Norteamérica
        case .cad: return "C$"
        }
    }

    /// Nombre localizado de la moneda
    var localizedName: String {
        switch self {
        // Latinoamérica
        case .pen: return L10n.Currency.pen
        case .usd: return L10n.Currency.usd
        case .mxn: return L10n.Currency.mxn
        case .cop: return L10n.Currency.cop
        case .brl: return L10n.Currency.brl
        case .ars: return L10n.Currency.ars
        case .clp: return L10n.Currency.clp
        case .uyu: return L10n.Currency.uyu
        case .bob: return L10n.Currency.bob
        case .pyg: return L10n.Currency.pyg
        case .crc: return L10n.Currency.crc
        case .gtq: return L10n.Currency.gtq
        case .hnl: return L10n.Currency.hnl
        case .nio: return L10n.Currency.nio
        case .pab: return L10n.Currency.pab
        case .dop: return L10n.Currency.dop
        // Europa
        case .eur: return L10n.Currency.eur
        case .gbp: return L10n.Currency.gbp
        case .chf: return L10n.Currency.chf
        case .sek: return L10n.Currency.sek
        case .nok: return L10n.Currency.nok
        case .dkk: return L10n.Currency.dkk
        case .pln: return L10n.Currency.pln
        case .czk: return L10n.Currency.czk
        case .huf: return L10n.Currency.huf
        case .ron: return L10n.Currency.ron
        case .rub: return L10n.Currency.rub
        case .uah: return L10n.Currency.uah
        case .try: return L10n.Currency.try
        // Asia
        case .jpy: return L10n.Currency.jpy
        case .cny: return L10n.Currency.cny
        case .krw: return L10n.Currency.krw
        case .inr: return L10n.Currency.inr
        case .idr: return L10n.Currency.idr
        case .php: return L10n.Currency.php
        case .thb: return L10n.Currency.thb
        case .myr: return L10n.Currency.myr
        case .sgd: return L10n.Currency.sgd
        case .hkd: return L10n.Currency.hkd
        case .twd: return L10n.Currency.twd
        case .vnd: return L10n.Currency.vnd
        // Oceanía
        case .aud: return L10n.Currency.aud
        case .nzd: return L10n.Currency.nzd
        // Medio Oriente
        case .aed: return L10n.Currency.aed
        case .sar: return L10n.Currency.sar
        case .ils: return L10n.Currency.ils
        case .qar: return L10n.Currency.qar
        case .kwd: return L10n.Currency.kwd
        // África
        case .zar: return L10n.Currency.zar
        case .egp: return L10n.Currency.egp
        case .ngn: return L10n.Currency.ngn
        case .kes: return L10n.Currency.kes
        case .mad: return L10n.Currency.mad
        // Norteamérica
        case .cad: return L10n.Currency.cad
        }
    }

    // MARK: - Normalization Aliases

    /// Aliases que se normalizan a este código de moneda.
    /// Usado por `normalizeCurrencyCode()` para reconocer variantes.
    var aliases: [String] {
        switch self {
        // Latinoamérica
        case .pen:
            return ["PEN", "SOL", "SOLES", "S/", "S/.", "S/. "]
        case .usd:
            return ["USD", "US$", "US DOLLAR", "$", "$USD", "USD$", "DOLLAR", "DOLAR"]
        case .mxn:
            return ["MXN", "MX$", "PESO MEXICANO", "PESOS MEXICANOS"]
        case .cop:
            return ["COP", "CO$", "PESO COLOMBIANO", "PESOS COLOMBIANOS"]
        case .brl:
            return ["BRL", "R$", "REAL", "REAIS", "REALES"]
        case .ars:
            return ["ARS", "AR$", "PESO ARGENTINO", "PESOS ARGENTINOS"]
        case .clp:
            return ["CLP", "CL$", "PESO CHILENO", "PESOS CHILENOS"]
        case .uyu:
            return ["UYU", "UY$", "PESO URUGUAYO", "PESOS URUGUAYOS"]
        case .bob:
            return ["BOB", "BS", "BS.", "BOLIVIANO", "BOLIVIANOS"]
        case .pyg:
            return ["PYG", "₲", "GUARANI", "GUARANIES"]
        case .crc:
            return ["CRC", "₡", "COLON", "COLONES", "COLON COSTARRICENSE"]
        case .gtq:
            return ["GTQ", "Q", "QUETZAL", "QUETZALES"]
        case .hnl:
            return ["HNL", "L", "LEMPIRA", "LEMPIRAS"]
        case .nio:
            return ["NIO", "C$", "CORDOBA", "CORDOBAS"]
        case .pab:
            return ["PAB", "B/.", "BALBOA", "BALBOAS"]
        case .dop:
            return ["DOP", "RD$", "PESO DOMINICANO", "PESOS DOMINICANOS"]
        // Europa
        case .eur:
            return ["EUR", "€", "EURO", "EUROS"]
        case .gbp:
            return ["GBP", "£", "POUND", "POUNDS", "LIBRA", "LIBRAS"]
        case .chf:
            return ["CHF", "FR.", "FRANC", "FRANCS", "FRANCO SUIZO"]
        case .sek:
            return ["SEK", "KR", "KRONA", "KRONOR", "CORONA SUECA"]
        case .nok:
            return ["NOK", "KRONE", "KRONER", "CORONA NORUEGA"]
        case .dkk:
            return ["DKK", "KRONE", "KRONER", "CORONA DANESA"]
        case .pln:
            return ["PLN", "ZŁ", "ZLOTY", "ZLOTYS", "ZLOTY POLACO"]
        case .czk:
            return ["CZK", "KČ", "KORUNA", "KORUNY", "CORONA CHECA"]
        case .huf:
            return ["HUF", "FT", "FORINT", "FORINTS", "FLORIN HUNGARO"]
        case .ron:
            return ["RON", "LEI", "LEU", "LEU RUMANO"]
        case .rub:
            return ["RUB", "₽", "RUBLE", "RUBLES", "RUBLO", "RUBLOS"]
        case .uah:
            return ["UAH", "₴", "HRYVNIA", "HRYVNIAS", "GRIVNA"]
        case .try:
            return ["TRY", "₺", "LIRA", "LIRAS", "LIRA TURCA"]
        // Asia
        case .jpy:
            return ["JPY", "¥", "YEN", "YENES"]
        case .cny:
            return ["CNY", "¥", "YUAN", "RENMINBI", "RMB"]
        case .krw:
            return ["KRW", "₩", "WON", "WONES"]
        case .inr:
            return ["INR", "₹", "RUPEE", "RUPEES", "RUPIA", "RUPIAS"]
        case .idr:
            return ["IDR", "RP", "RUPIAH", "RUPIA INDONESIA"]
        case .php:
            return ["PHP", "₱", "PESO FILIPINO", "PESOS FILIPINOS"]
        case .thb:
            return ["THB", "฿", "BAHT", "BAHTS"]
        case .myr:
            return ["MYR", "RM", "RINGGIT", "RINGGITS"]
        case .sgd:
            return ["SGD", "S$", "DOLAR SINGAPUR"]
        case .hkd:
            return ["HKD", "HK$", "DOLAR HONG KONG"]
        case .twd:
            return ["TWD", "NT$", "NUEVO DOLAR TAIWANES"]
        case .vnd:
            return ["VND", "₫", "DONG", "DONGS"]
        // Oceanía
        case .aud:
            return ["AUD", "A$", "DOLAR AUSTRALIANO"]
        case .nzd:
            return ["NZD", "NZ$", "DOLAR NEOZELANDES"]
        // Medio Oriente
        case .aed:
            return ["AED", "د.إ", "DIRHAM", "DIRHAMS", "DIRHAM EMIRATOS"]
        case .sar:
            return ["SAR", "﷼", "RIYAL", "RIYALS", "RIYAL SAUDI"]
        case .ils:
            return ["ILS", "₪", "SHEKEL", "SHEKELS", "SHEQUEL"]
        case .qar:
            return ["QAR", "RIYAL QATARI"]
        case .kwd:
            return ["KWD", "د.ك", "DINAR", "DINARS", "DINAR KUWAITI"]
        // África
        case .zar:
            return ["ZAR", "R", "RAND", "RANDS"]
        case .egp:
            return ["EGP", "E£", "LIBRA EGIPCIA", "LIBRAS EGIPCIAS"]
        case .ngn:
            return ["NGN", "₦", "NAIRA", "NAIRAS"]
        case .kes:
            return ["KES", "KSH", "SHILLING", "SHILLINGS", "CHELIN KENIANO"]
        case .mad:
            return ["MAD", "د.م.", "DIRHAM MARROQUI", "DIRHAMS MARROQUIES"]
        // Norteamérica
        case .cad:
            return ["CAD", "C$", "DOLAR CANADIENSE", "DOLARES CANADIENSES"]
        }
    }

    // MARK: - Exchange Rate Properties

    /// Tasa de cambio de fallback relativa a USD.
    /// IMPORTANTE: Solo se usa cuando no hay datos de API disponibles.
    /// Valores aproximados de enero 2025.
    var fallbackRateToUSD: Double {
        switch self {
        // Latinoamérica
        case .usd: return 1.0
        case .pen: return 3.72      // 1 USD = 3.72 PEN
        case .mxn: return 17.2      // 1 USD = 17.2 MXN
        case .cop: return 4380.0    // 1 USD = 4380 COP
        case .brl: return 6.05      // 1 USD = 6.05 BRL
        case .ars: return 1050.0    // 1 USD = 1050 ARS
        case .clp: return 980.0     // 1 USD = 980 CLP
        case .uyu: return 42.0      // 1 USD = 42 UYU
        case .bob: return 6.91      // 1 USD = 6.91 BOB
        case .pyg: return 7750.0    // 1 USD = 7750 PYG
        case .crc: return 510.0     // 1 USD = 510 CRC
        case .gtq: return 7.75      // 1 USD = 7.75 GTQ
        case .hnl: return 25.0      // 1 USD = 25 HNL
        case .nio: return 37.0      // 1 USD = 37 NIO
        case .pab: return 1.0       // 1 USD = 1 PAB (paridad)
        case .dop: return 60.0      // 1 USD = 60 DOP
        // Europa
        case .eur: return 0.92      // 1 USD = 0.92 EUR
        case .gbp: return 0.79      // 1 USD = 0.79 GBP
        case .chf: return 0.88      // 1 USD = 0.88 CHF
        case .sek: return 10.5      // 1 USD = 10.5 SEK
        case .nok: return 10.8      // 1 USD = 10.8 NOK
        case .dkk: return 6.9       // 1 USD = 6.9 DKK
        case .pln: return 4.0       // 1 USD = 4.0 PLN
        case .czk: return 23.5      // 1 USD = 23.5 CZK
        case .huf: return 380.0     // 1 USD = 380 HUF
        case .ron: return 4.6       // 1 USD = 4.6 RON
        case .rub: return 95.0      // 1 USD = 95 RUB
        case .uah: return 41.0      // 1 USD = 41 UAH
        case .try: return 32.0      // 1 USD = 32 TRY
        // Asia
        case .jpy: return 150.0     // 1 USD = 150 JPY
        case .cny: return 7.25      // 1 USD = 7.25 CNY
        case .krw: return 1380.0    // 1 USD = 1380 KRW
        case .inr: return 83.0      // 1 USD = 83 INR
        case .idr: return 15800.0   // 1 USD = 15800 IDR
        case .php: return 56.0      // 1 USD = 56 PHP
        case .thb: return 35.0      // 1 USD = 35 THB
        case .myr: return 4.7       // 1 USD = 4.7 MYR
        case .sgd: return 1.35      // 1 USD = 1.35 SGD
        case .hkd: return 7.8       // 1 USD = 7.8 HKD
        case .twd: return 32.0      // 1 USD = 32 TWD
        case .vnd: return 24500.0   // 1 USD = 24500 VND
        // Oceanía
        case .aud: return 1.55      // 1 USD = 1.55 AUD
        case .nzd: return 1.68      // 1 USD = 1.68 NZD
        // Medio Oriente
        case .aed: return 3.67      // 1 USD = 3.67 AED (fixed peg)
        case .sar: return 3.75      // 1 USD = 3.75 SAR (fixed peg)
        case .ils: return 3.65      // 1 USD = 3.65 ILS
        case .qar: return 3.64      // 1 USD = 3.64 QAR (fixed peg)
        case .kwd: return 0.31      // 1 USD = 0.31 KWD
        // África
        case .zar: return 18.5      // 1 USD = 18.5 ZAR
        case .egp: return 50.0      // 1 USD = 50 EGP
        case .ngn: return 1550.0    // 1 USD = 1550 NGN
        case .kes: return 155.0     // 1 USD = 155 KES
        case .mad: return 10.0      // 1 USD = 10 MAD
        // Norteamérica
        case .cad: return 1.36      // 1 USD = 1.36 CAD
        }
    }

    /// Tasa de cambio de fallback a PEN (para retrocompatibilidad).
    var fallbackRateToPEN: Decimal {
        // Calcula: 1 [esta moneda] = X PEN
        // Fórmula: (PEN/USD) / (esta/USD)
        let penRate = CurrencyCode.pen.fallbackRateToUSD
        let thisRate = self.fallbackRateToUSD
        return Decimal(penRate / thisRate)
    }

    // MARK: - Region Mapping

    /// Códigos de región ISO que usan esta moneda.
    /// Usado para auto-detectar la moneda preferida del usuario.
    var regionCodes: [String] {
        switch self {
        // Latinoamérica
        case .pen: return ["PE"]
        case .usd: return ["US", "EC", "SV", "PA"]  // Ecuador, El Salvador, Panamá usan USD
        case .mxn: return ["MX"]
        case .cop: return ["CO"]
        case .brl: return ["BR"]
        case .ars: return ["AR"]
        case .clp: return ["CL"]
        case .uyu: return ["UY"]
        case .bob: return ["BO"]
        case .pyg: return ["PY"]
        case .crc: return ["CR"]
        case .gtq: return ["GT"]
        case .hnl: return ["HN"]
        case .nio: return ["NI"]
        case .pab: return ["PA"]  // Panamá también usa Balboa (paridad con USD)
        case .dop: return ["DO"]
        // Europa
        case .eur: return ["ES", "DE", "FR", "IT", "PT", "NL", "BE", "AT", "IE", "FI", "GR",
                          "SK", "SI", "EE", "LV", "LT", "CY", "MT", "LU"]
        case .gbp: return ["GB"]
        case .chf: return ["CH", "LI"]  // Suiza y Liechtenstein
        case .sek: return ["SE"]
        case .nok: return ["NO"]
        case .dkk: return ["DK"]
        case .pln: return ["PL"]
        case .czk: return ["CZ"]
        case .huf: return ["HU"]
        case .ron: return ["RO"]
        case .rub: return ["RU"]
        case .uah: return ["UA"]
        case .try: return ["TR"]
        // Asia
        case .jpy: return ["JP"]
        case .cny: return ["CN"]
        case .krw: return ["KR"]
        case .inr: return ["IN"]
        case .idr: return ["ID"]
        case .php: return ["PH"]
        case .thb: return ["TH"]
        case .myr: return ["MY"]
        case .sgd: return ["SG"]
        case .hkd: return ["HK"]
        case .twd: return ["TW"]
        case .vnd: return ["VN"]
        // Oceanía
        case .aud: return ["AU"]
        case .nzd: return ["NZ"]
        // Medio Oriente
        case .aed: return ["AE"]
        case .sar: return ["SA"]
        case .ils: return ["IL"]
        case .qar: return ["QA"]
        case .kwd: return ["KW"]
        // África
        case .zar: return ["ZA"]
        case .egp: return ["EG"]
        case .ngn: return ["NG"]
        case .kes: return ["KE"]
        case .mad: return ["MA"]
        // Norteamérica
        case .cad: return ["CA"]
        }
    }

    // MARK: - Continent Mapping

    /// Continente al que pertenece esta divisa
    var continent: Continent {
        switch self {
        // Latinoamérica
        case .pen, .mxn, .cop, .brl, .ars, .clp, .uyu, .bob, .pyg, .crc, .gtq, .hnl, .nio, .pab, .dop:
            return .latinAmerica
        // Norteamérica (USD y CAD)
        case .usd, .cad:
            return .northAmerica
        // Europa
        case .eur, .gbp, .chf, .sek, .nok, .dkk, .pln, .czk, .huf, .ron, .rub, .uah, .try:
            return .europe
        // Asia
        case .jpy, .cny, .krw, .inr, .idr, .php, .thb, .myr, .sgd, .hkd, .twd, .vnd:
            return .asia
        // Oceanía
        case .aud, .nzd:
            return .oceania
        // Medio Oriente
        case .aed, .sar, .ils, .qar, .kwd:
            return .middleEast
        // África
        case .zar, .egp, .ngn, .kes, .mad:
            return .africa
        }
    }

    // MARK: - Static Helpers

    /// Todos los códigos de moneda como strings (para API calls).
    static var allRawValues: [String] {
        allCases.map { $0.rawValue }
    }

    /// Diccionario de tasas de fallback relativas a USD.
    static var fallbackRates: [String: Double] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.rawValue, $0.fallbackRateToUSD) })
    }

    /// Busca una moneda por código de región.
    static func fromRegion(_ regionCode: String) -> CurrencyCode? {
        allCases.first { $0.regionCodes.contains(regionCode) }
    }

    /// Busca una moneda por cualquiera de sus aliases.
    static func fromAlias(_ alias: String) -> CurrencyCode? {
        let upper = alias.uppercased()
        return allCases.first { $0.aliases.contains(upper) }
    }

    /// Agrupa todas las divisas por continente, ordenadas alfabéticamente dentro de cada grupo.
    static var groupedByContinent: [(continent: Continent, currencies: [CurrencyCode])] {
        let grouped = Dictionary(grouping: allCases) { $0.continent }
        return Continent.allCases
            .sorted { $0.displayOrder < $1.displayOrder }
            .compactMap { continent in
                guard let currencies = grouped[continent], !currencies.isEmpty else { return nil }
                let sorted = currencies.sorted { $0.localizedName < $1.localizedName }
                return (continent: continent, currencies: sorted)
            }
    }
}

// MARK: - Currency Code Normalization

/// Normaliza un código de moneda "sucio" a un código estándar de 3 letras.
/// Deriva automáticamente de CurrencyCode.aliases.
/// Ejemplos:
/// - "S/", "s/.", "SOL", "soles" → "PEN"
/// - "$", "US$", "usd" → "USD"
/// - "€", "eur" → "EUR"
func normalizeCurrencyCode(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return CurrencyDefaults.fallbackCode
    }

    // Intenta encontrar por alias
    if let currency = CurrencyCode.fromAlias(trimmed) {
        return currency.rawValue
    }

    // Intento de normalización genérica: tomar solo letras y quedarnos con 3
    let upper = trimmed.uppercased()
    let letters = upper.filter { $0.isLetter }
    if letters.count == 3 {
        // Verifica si es un código válido
        if CurrencyCode(rawValue: String(letters)) != nil {
            return String(letters)
        }
    } else if letters.count > 3 {
        let start = letters.startIndex
        let end = letters.index(start, offsetBy: 3)
        let code = String(letters[start..<end])
        if CurrencyCode(rawValue: code) != nil {
            return code
        }
    }

    // Fallback a USD para códigos no reconocidos
    return CurrencyDefaults.fallbackCode
}

// MARK: - Currency Conversion (Using CurrencyConverter)

/// Convierte un monto entre dos monedas.
/// Esta función mantiene retrocompatibilidad con el código existente.
/// Usa tasas de fallback estáticas cuando no hay contexto SwiftData disponible.
/// - Para conversiones con tasas actualizadas por fecha, usar CurrencyConverter.shared directamente.
func convert(_ amount: Decimal, from rawFrom: String, to rawTo: String) -> Decimal {
    return CurrencyConverter.shared.convertWithFallback(amount, from: rawFrom, to: rawTo)
}

/// Devuelve la tasa de conversión de una moneda a PEN.
/// @deprecated Usar CurrencyConverter.shared para tasas actualizadas.
/// Esta función mantiene retrocompatibilidad con tasas aproximadas.
func rateToPEN(_ rawCode: String) -> Decimal {
    let code = normalizeCurrencyCode(rawCode)

    // Usa las tasas de fallback del enum
    if let currency = CurrencyCode(rawValue: code) {
        return currency.fallbackRateToPEN
    }
    return 1.0
}

// MARK: - Currency Defaults

/// Centralized default currency settings.
/// Use these constants instead of hardcoding currency codes throughout the codebase.
enum CurrencyDefaults {
    /// The fallback currency code when region detection fails (USD - US Dollar)
    static let fallbackCode = "USD"

    /// The default currency code when none is specified
    /// Uses region detection, falls back to USD
    static var defaultCode: String {
        detectCurrencyFromRegion().rawValue
    }

    /// UserDefaults key for storing the user's preferred currency
    static let preferredCurrencyKey = "defaultCurrencyCode"

    /// Returns the user's current preferred currency code, or the detected default if not set
    static var currentPreferred: String {
        UserDefaults.standard.string(forKey: preferredCurrencyKey) ?? defaultCode
    }

    /// Detects the recommended currency based on the user's device region.
    /// Derives automatically from CurrencyCode.regionCodes.
    static func detectCurrencyFromRegion() -> CurrencyCode {
        let regionCode = Locale.current.region?.identifier ?? ""

        // Busca en el mapeo centralizado del enum
        if let currency = CurrencyCode.fromRegion(regionCode) {
            return currency
        }

        // Default to USD for unsupported regions
        return .usd
    }
}

// MARK: - Currency Info (Backward Compatibility)

/// Returns display info for a currency.
/// Now derives from CurrencyCode properties.
func currencyInfo(for currency: CurrencyCode) -> (name: String, code: String, flag: String) {
    return (currency.localizedName, currency.rawValue, currency.flag)
}
