//
//  BankNoticeRules.swift
//  Yala
//
//  La tabla de reglas del atajo del banco (2.3, B1, opción L2: reglas primero, el modelo del iPhone de respaldo).
//
//  ## Cómo se suma un formato
//
//  Un aviso real nuevo es una fila más en `all` y un caso en `YalaTests/AtajoBanco/BankNoticeParserTests.swift` con el
//  texto tal cual (los cuatro dígitos tapados si hace falta). La regla de un banco va antes que las genéricas.
//
//  ## De dónde salen los formatos (medido el 2026-11-14)
//
//  Ningún banco publica el texto de sus avisos. Lo que hay:
//  - BCP: el ejemplo de la definición del atajo (`docs/ux/atajo-banco-y-suscripciones/`), «Realizaste un consumo de
//    S/ 45.90 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES.». Sin aviso real todavía.
//  - Yape, pago recibido: «Yape! NOMBRE te envió un pago por S/ 10.00», de un proyecto público que lee esos avisos
//    (github.com/yassppy/app-yape-monitoreo). «te yapeó» aparece como frase clave en otro (github.com/Adrian474747/AvisoYape).
//  - Plin, Interbank, BBVA, Scotiabank y los pagos que haces con Yape: sin texto público. Los cubren las reglas genéricas
//    (verbo en pasado + importe) y, si no, el modelo del iPhone. Cuando Jürgen mande avisos reales, cada uno gana su fila.
//

import Foundation

nonisolated struct BankNoticeRule: Equatable {
    /// Identidad estable de la regla (`banco.formato`). Viaja en la lectura para saber qué regla leyó cada aviso.
    let id: String
    /// El banco de la regla; `nil` = genérica.
    let bank: BankNoticeBank?
    let isExpense: Bool
    /// Expresión con los grupos `cur` y `amt` (el importe) y, si los sabe, `who` (comercio o persona) y `last4`.
    let pattern: String
    /// Si `who` no sale del patrón, buscar el comercio en «… en COMERCIO» después del importe.
    let merchantAfterEn: Bool
}

nonisolated enum BankNoticeRules {

    /// El importe con su moneda delante. Grupos `cur` y `amt`.
    static let money = #"(?<cur>S/\.?|S\./|PEN|US\$|USD|\$)\s?(?<amt>\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)"#

    /// Un nombre de persona (letras, espacios, punto, apóstrofo, guion).
    private static let person = #"(?<who>[\p{L}][\p{L} .'\-]{1,59}?)"#

    static let all: [BankNoticeRule] = [
        // BCP · consumo con tarjeta (ejemplo de la definición del atajo).
        BankNoticeRule(id: "bcp.consumo", bank: .bcp, isExpense: true,
                       pattern: #"consumo (?:de|por) "# + money, merchantAfterEn: true),
        // Yape · pago recibido (proyecto público app-yape-monitoreo).
        BankNoticeRule(id: "yape.recibido", bank: .yape, isExpense: false,
                       pattern: person + #" te envió un pago por "# + money, merchantAfterEn: false),
        // Yape · «te yapeó» (frase clave de AvisoYape; la forma completa, sin verificar).
        BankNoticeRule(id: "yape.teYapeo", bank: .yape, isExpense: false,
                       pattern: person + #" te yapeó "# + money, merchantAfterEn: false),
        // Yape · pago que haces (sin texto público; forma por confirmar con un aviso real).
        BankNoticeRule(id: "yape.yapeaste", bank: .yape, isExpense: true,
                       pattern: #"yapeaste "# + money + #"(?: a (?<who>[^.\n]+?))?(?:\.|$)"#, merchantAfterEn: false),
        // Plin · pago recibido (sin texto público).
        BankNoticeRule(id: "plin.recibido", bank: .plin, isExpense: false,
                       pattern: person + #" te (?:plineó|envió) "# + money, merchantAfterEn: false),
        // Plin · pago que haces (sin texto público).
        BankNoticeRule(id: "plin.plineaste", bank: .plin, isExpense: true,
                       pattern: #"plineaste "# + money + #"(?: a (?<who>[^.\n]+?))?(?:\.|$)"#, merchantAfterEn: false),
        // Genérica · compra o consumo con tarjeta: «Compra por S/ 30.00 en …», «Consumo de US$ 12.00 en …».
        BankNoticeRule(id: "generic.compra", bank: nil, isExpense: true,
                       pattern: #"(?:compra|consumo|pago|cargo)(?: aprobad[oa]| realizad[oa]| exitos[oa])? (?:de|por) "# + money,
                       merchantAfterEn: true),
        // Genérica · «Pagaste S/ 20.00 en …», «Realizaste un pago de S/ 20.00 a …».
        BankNoticeRule(id: "generic.pagaste", bank: nil, isExpense: true,
                       pattern: #"(?:pagaste|compraste|realizaste un pago de|realizaste una compra de) "# + money,
                       merchantAfterEn: true),
        // Genérica · dinero que entra: «Recibiste S/ 50.00 de …», «Te transfirieron S/ 50.00».
        BankNoticeRule(id: "generic.recibiste", bank: nil, isExpense: false,
                       pattern: #"(?:recibiste|te enviaron|te transfirieron|te depositaron|abono de) "# + money
                       + #"(?: de (?<who>[^.\n]+?))?(?:\.|$| el | en )"#,
                       merchantAfterEn: false),
    ]

    /// Una compra rechazada no es un movimiento.
    static let declinedPattern = #"rechazad[oa]|denegad[oa]|declinad[oa]|no (?:fue |ha sido )?aprobad[oa]|no se pudo|no pudimos procesar"#

    /// Una anulación o devolución mueve dinero, pero en qué sentido no lo dice una regla: lo completa la persona.
    static let reversalPattern = #"anulad[oa]|anulación|extorno|devoluci[oó]n|reembolso|reversi[oó]n"#

    /// Publicidad: aunque traiga un importe, no es un movimiento.
    static let promotionPattern = #"promoci[oó]n|\boferta|descuento|\bgana\b|sorteo|participa|cuotas sin intereses|cashback|aprovecha"#

    /// Seguridad, cuenta o saldo: no es un movimiento. Se mira DESPUÉS de las reglas, porque un pago recibido por Yape
    /// trae un código de seguridad de tres dígitos.
    static let notAMovementPattern = #"c[oó]digo|clave|contraseña|token|\botp\b|saldo|no compartas|inicio de sesi[oó]n|iniciaste sesi[oó]n|nuevo dispositivo|afiliaste|activaste|bloquead[oa]"#
}
