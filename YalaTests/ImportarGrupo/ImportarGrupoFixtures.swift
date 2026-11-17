//
//  ImportarGrupoFixtures.swift
//  YalaTests
//
//  Exports de prueba con la forma de los reales. El de Splitwise sigue el «Export as spreadsheet» de un grupo (cabecera
//  `Date,Description,Category,Cost,Currency,<una columna por persona>`, una fila por gasto o pago con lo que cada uno
//  puso menos lo que le tocaba, y la fila «Total balance» al final). Los de Tricount cubren las variantes conocidas: no
//  hay un formato oficial publicado (Paso 0 del ticket `groups-import-splitwise-tricount`).
//
//  Los saldos esperados están calculados a mano en cada fixture, no con el código que se prueba.
//

import Foundation

enum ImportarGrupoFixtures {

    /// Viaje a Cusco: 4 personas, soles, reparto desigual (el hotel no lo paga Luis), un pago entre ellos y la fila del
    /// total. Esperado: Jürgen +110.00, Ana -20.00, Luis 0 (al día), Pia -90.00.
    static let splitwiseCusco = """
    Date,Description,Category,Cost,Currency,Jürgen,Ana,Luis,Pia
    2026-03-01,Hotel en Cusco,Hotel,300.00,PEN,200.00,-100.00,0.00,-100.00
    2026-03-02,"Cena, pisco y postre",Dining out,120.00,PEN,-30.00,90.00,-30.00,-30.00
    2026-03-03,Taxi al aeropuerto,Taxi,40.00,PEN,-10.00,-10.00,30.00,-10.00
    2026-03-04,Pia paid Jürgen,Payment,50.00,PEN,-50.00,0.00,0.00,50.00

    2026-03-05,Total balance, , ,PEN,110.00,-20.00,0.00,-90.00
    """

    /// Mismo grupo con dos monedas (soles y dólares) y una descripción con salto de línea dentro de comillas.
    /// Esperado PEN: Jürgen +60.00, Ana -30.00, Luis -30.00. USD: Jürgen -15.00, Ana +30.00, Luis -15.00.
    static let splitwiseTwoCurrencies = """
    Date,Description,Category,Cost,Currency,Jürgen,Ana,Luis
    2026-04-10,"Entradas a
    Machu Picchu",Entertainment,90.00,PEN,60.00,-30.00,-30.00
    2026-04-11,Tour en dólares,General,45.00,USD,-15.00,30.00,-15.00
    ,Total balance,,,PEN,60.00,-30.00,-30.00
    ,Total balance,,,USD,-15.00,30.00,-15.00
    """

    /// Export desde una configuración europea: `;` y coma decimal, con un miembro sin movimientos.
    /// Esperado EUR: Marta +12.50, Joan -12.50, Pau 0.
    static let splitwiseSemicolonComma = """
    Date;Description;Category;Cost;Currency;Marta;Joan;Pau
    2026-05-01;Bocadillos;Food;25,00;EUR;12,50;-12,50;0,00
    ;Total balance;;;EUR;12,50;-12,50;0,00
    """

    /// Tricount con una columna por persona («Paid for X»), un reembolso y un ingreso.
    /// Filas: Clara paga cena 90 (Clara 30, Tomás 30, Inés 30) → Clara +60, Tomás -30, Inés -30.
    ///        Tomás paga taxi 20 solo a Inés (desigual) → Tomás +20, Inés -20.
    ///        Inés reembolsa 25 a Clara (transferencia) → Inés +25, Clara -25.
    ///        Clara recibe 30 de una devolución para los tres (ingreso) → Clara -30, Tomás +10, Inés +10, Clara +10.
    /// Esperado EUR: Clara +15, Tomás 0, Inés -15.
    static let tricountPerPerson = """
    Title,Amount,Currency,Exchange rate,Amount in EUR,Paid by,Paid for Clara,Paid for Tomás,Paid for Inés,Date & time,Transaction type
    Cena,90.00,EUR,1,90.00,Clara,30.00,30.00,30.00,2026-06-01 21:30,Normal
    Taxi,20.00,EUR,1,20.00,Tomás,0.00,0.00,20.00,2026-06-02 08:00,Normal
    Reembolso,25.00,EUR,1,25.00,Inés,25.00,0.00,0.00,2026-06-03 10:00,Money transfer
    Devolución del hotel,30.00,EUR,1,30.00,Clara,10.00,10.00,10.00,2026-06-04 12:00,Income
    """

    /// Tricount con el reparto en una sola columna de nombres, a partes iguales (10 entre 3 → 3.34, 3.33, 3.33).
    /// Filas: Ana paga 10.00 para Ana, Bea, Caro → Ana +6.66, Bea -3.33, Caro -3.33.
    ///        Bea paga 6.00 para Ana y Caro → Bea +6.00, Ana -3.00, Caro -3.00.
    /// Esperado USD: Ana +3.66, Bea +2.67, Caro -6.33.
    static let tricountList = """
    Paid by;Date;Title;Amount;Currency;Impacted to
    Ana;2026-07-01;Super;10,00;USD;Ana, Bea, Caro
    Bea;2026-07-02;Helados;6,00;USD;Ana, Caro
    """

    /// La variante con el importe en la moneda del tricount y las partes también en esa moneda («Share X»).
    /// Fila: Dan paga 100 USD = 90 EUR, partes en EUR (Dan 30, Eva 60) → EUR: Dan +60, Eva -60.
    static let tricountShareInDefaultCurrency = """
    Title,Amount,Currency,Amount in EUR,Paid by,Share Dan,Share Eva,Date
    Cena de despedida,100.00,USD,90.00,Dan,30.00,60.00,2026-08-01
    """

    /// La fila del total como la escriben los exports reales (con fecha y coste en blanco) y en otro idioma: no puede
    /// contarse como un gasto. Esperado: los mismos saldos que la fila de gasto, no el doble.
    static let splitwiseTotalWithDateInGerman = """
    Datum,Beschreibung,Kategorie,Kosten,Währung,Lena,Max
    2026-02-01,Pizza,Essen,30.00,EUR,15.00,-15.00
    2026-02-02,Gesamtbilanz, , ,EUR,15.00,-15.00
    """

    /// Dos personas que se llaman igual: son dos. Esperado: Carlos +10, Carlos (2) −10.
    static let splitwiseSameName = """
    Date,Description,Category,Cost,Currency,Carlos,Carlos
    2026-02-01,Taxi,Taxi,20.00,USD,10.00,-10.00
    """

    /// Tricount con un reparto que redondea (10 entre tres: 3.33 cada uno) y una fila a cero.
    /// Esperado USD: Ana +6.66, Bea −3.33, Caro −3.33, exactos y sin restos.
    static let tricountRounding = """
    Title,Amount,Currency,Paid by,Paid for Ana,Paid for Bea,Paid for Caro,Date
    Super,10.00,USD,Ana,3.33,3.33,3.33,2026-07-01
    Anulado,0.00,USD,Bea,0.00,0.00,0.00,2026-07-02
    """

    static let notAnExport = """
    Fecha,Comercio,Monto
    2026-01-01,Wong,25.00
    """

    static let unknownCurrency = """
    Date,Description,Category,Cost,Currency,A,B
    2026-01-01,Algo,General,10.00,XYZ,5.00,-5.00
    """

    static let rowDoesNotAddUp = """
    Date,Description,Category,Cost,Currency,A,B
    2026-01-01,Algo,General,10.00,USD,5.00,-4.00
    """

    static let onlyHeaderAndTotal = """
    Date,Description,Category,Cost,Currency,A,B
    ,Total balance,,,USD,0.00,0.00
    """
}
