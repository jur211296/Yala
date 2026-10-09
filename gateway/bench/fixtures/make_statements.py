#!/usr/bin/env python3
"""
Extractos bancarios FICTICIOS de varias páginas para el banco de `photo.read` (ticket
`pdf-statement-reads-only-the-first-page`, 2026-10-08).

La app lee un PDF página a página: renderiza cada página a 2× (A4 = 595×842 pt → 1190×1684 px) y manda cada una
como una foto más. Aquí se renderiza cada página igual y cada página es UN caso del banco (`stmt-*`), con la verdad
de esa página sola: los movimientos reales. Lo que un extracto trae y NO es un movimiento —saldo anterior, saldo que
pasa / viene de la página anterior, «suma y sigue», subtotales, totales de cargos y abonos, saldo al corte, la página
de resumen de la cuenta y la de condiciones— se espera que NO salga (`transactions: []` en las páginas sin
movimientos). Si sale, cuenta como movimiento de más y el caso falla.

Cuatro extractos:
- `stmt-pe` — cuenta de ahorros es-PE en S/, 3 páginas de movimientos (40 filas) + 1 de condiciones con tasas y
  comisiones en el texto.
- `stmt-us` — checking en-US en $, página de resumen (solo saldos y totales) + 2 de detalle con «Balance forward».
- `stmt-es` — cuenta es-ES en €, coma decimal, 2 páginas con «Suma y sigue» / «Suma anterior».
- `stmt-tc` — tarjeta de crédito es-PE en S/, 2 páginas con UNA sola columna de importes: el saldo anterior, el que pasa,
  el subtotal, la deuda total y el pago mínimo van en la MISMA columna que los consumos (la trampa más dura).

Todo es ficticio: banco, titular, comercios y números. Escribe las imágenes en `bench/cases/photo/` y sustituye los
casos `stmt-*` de `bench/cases/photo.read.json` (la verdad sale de los mismos datos que pintan la página).

Uso:  python3 bench/fixtures/make_statements.py        (necesita Google Chrome y Pillow, como make_photos.py)
"""
import json
import os
import random

from make_photos import OUT, render

HERE = os.path.dirname(os.path.abspath(__file__))
CASES_FILE = os.path.normpath(os.path.join(HERE, "..", "cases", "photo.read.json"))
TODAY = "2026-10-08"

A4 = dict(width=595, height=842, scale=2)  # una página de PDF a 2×, como `PDFStatementPages` en la app

PAGE_CSS = "font-family:'Helvetica Neue',Arial,sans-serif;color:#1a1a1a;padding:34px 34px 24px;font-size:9.5px;line-height:1.35;background:#fff;min-height:842px;position:relative"


def money_pe(v):
    return f"{v:,.2f}"


def money_us(v):
    return f"{v:,.2f}"


def money_es(v):
    s = f"{v:,.2f}"
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


def header(bank, lines, right):
    return f"""<div style="display:flex;justify-content:space-between;border-bottom:2px solid #1f3a5f;padding-bottom:8px;margin-bottom:10px">
<div><div style="font-size:15px;font-weight:700;color:#1f3a5f">{bank}</div>{''.join(f'<div>{l}</div>' for l in lines)}</div>
<div style="text-align:right">{''.join(f'<div>{l}</div>' for l in right)}</div></div>"""


def table(head, rows, aligns):
    th = "".join(f"<th style='text-align:{a};padding:4px 4px;border-bottom:1px solid #1f3a5f;font-size:8.5px;text-transform:uppercase'>{h}</th>" for h, a in zip(head, aligns))
    trs = ""
    for r in rows:
        style = r.get("style", "")
        trs += "<tr>" + "".join(
            f"<td style='text-align:{a};padding:3.4px 4px;border-bottom:1px solid #e3e6ea;white-space:nowrap;{style}'>{c}</td>"
            for c, a in zip(r["cells"], aligns)) + "</tr>"
    return f"<table style='width:100%;border-collapse:collapse'><thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>"


def footer(text):
    return f"<div style='position:absolute;bottom:22px;left:34px;right:34px;border-top:1px solid #ccc;padding-top:6px;font-size:8px;color:#666;display:flex;justify-content:space-between'>{text}</div>"


def page(html):
    return f"<div style=\"{PAGE_CSS}\">{html}</div>"


# ------------------------------------------------------------------ es-PE

PE_DESCS = [
    ("COMPRA SUPERMERCADO LA ECONOMIA", -1), ("COMPRA GRIFO NORTE SAC", -1), ("PAGO SERV. LUZ DEL SUR", -1),
    ("COMPRA FARMACIA SALUD TOTAL", -1), ("RETIRO CAJERO AG. MIRAFLORES", -1), ("TRANSF. RECIBIDA M. QUISPE", 1),
    ("COMPRA RESTAURANTE EL BUEN SABOR", -1), ("PAGO TARJETA CREDITO", -1), ("COMPRA PANADERIA SAN JORGE", -1),
    ("PAGO MOVIL TELCO ANDINA", -1), ("COMPRA CINE ESTRELLA", -1), ("TRANSF. A L. RAMIREZ", -1),
    ("DEPOSITO EFECTIVO", 1), ("COMPRA LIBRERIA CENTRAL", -1), ("COMPRA TAXI APP", -1), ("PAGO AGUA SEDAPAL", -1),
    ("ABONO HABERES EMPRESA SAC", 1), ("COMPRA MERCADO SURQUILLO", -1), ("ITF", -1), ("COMPRA GIMNASIO FORMA", -1),
]
PE_MONTHS = "ENE FEB MAR ABR MAY JUN JUL AGO SET OCT NOV DIC".split()


def build_pe():
    rnd = random.Random(2026_09)
    rows = []
    day = 1
    for i in range(40):
        desc, sign = PE_DESCS[rnd.randrange(len(PE_DESCS))]
        if desc == "ITF":
            amount = round(rnd.uniform(0.05, 0.40), 2)
        elif desc.startswith("ABONO HABERES"):
            amount = 4850.00
        elif sign > 0:
            amount = round(rnd.choice([150, 200, 350.5, 80, 420.75]) * 1.0, 2)
        else:
            amount = round(rnd.uniform(6, 160), 2)
        if i == 15:  # el sueldo, a mitad de mes: una cuenta de ahorros no queda en negativo
            desc, sign, amount = "ABONO HABERES EMPRESA SAC", 1, 4850.00
        day = min(30, day + (1 if rnd.random() < 0.7 else 0))
        rows.append({"date": f"2026-09-{day:02d}", "desc": desc, "amount": round(sign * amount, 2)})
    pages = [rows[:14], rows[14:28], rows[28:]]
    balance = 3250.40
    out = []
    for n, chunk in enumerate(pages, start=1):
        body = header("BANCO ANDINO DEL PACÍFICO", ["ESTADO DE CUENTA — CUENTA DE AHORROS SOLES", "Titular: ANA LUCÍA TORRES VEGA (ficticio)", "Cuenta: 191-00000000-0-41"],
                      ["Periodo: 01/09/2026 al 30/09/2026", "Moneda: SOLES (S/)", f"Página {n} de 4"])
        trs = []
        opening = balance
        label = "SALDO ANTERIOR" if n == 1 else "SALDO QUE VIENE DE LA PÁGINA ANTERIOR"
        trs.append({"cells": ["", label, "", "", money_pe(opening)], "style": "font-weight:700;background:#f2f5f9"})
        cargos = abonos = 0.0
        for r in chunk:
            balance = round(balance + r["amount"], 2)
            d = r["date"]
            fecha = f"{d[8:10]}{PE_MONTHS[int(d[5:7]) - 1]}"
            if r["amount"] < 0:
                cargos += -r["amount"]
                trs.append({"cells": [fecha, r["desc"], money_pe(-r["amount"]), "", money_pe(balance)]})
            else:
                abonos += r["amount"]
                trs.append({"cells": [fecha, r["desc"], "", money_pe(r["amount"]), money_pe(balance)]})
        trs.append({"cells": ["", "SUBTOTAL PÁGINA", money_pe(cargos), money_pe(abonos), ""], "style": "font-weight:700;border-top:1px solid #1f3a5f"})
        if n < 3:
            trs.append({"cells": ["", "SALDO QUE PASA A LA SIGUIENTE PÁGINA", "", "", money_pe(balance)], "style": "font-weight:700;background:#f2f5f9"})
        else:
            tot_c = -sum(r["amount"] for r in rows if r["amount"] < 0)
            tot_a = sum(r["amount"] for r in rows if r["amount"] > 0)
            trs.append({"cells": ["", "TOTAL CARGOS DEL PERIODO", money_pe(tot_c), "", ""], "style": "font-weight:700"})
            trs.append({"cells": ["", "TOTAL ABONOS DEL PERIODO", "", money_pe(tot_a), ""], "style": "font-weight:700"})
            trs.append({"cells": ["", "SALDO AL CORTE 30/09/2026", "", "", money_pe(balance)], "style": "font-weight:700;background:#f2f5f9"})
        body += table(["Fecha", "Descripción", "Cargos S/", "Abonos S/", "Saldo S/"], trs, ["left", "left", "right", "right", "right"])
        body += footer(f"<span>Banco Andino del Pacífico S.A. — documento ficticio</span><span>Página {n} de 4</span>")
        out.append((f"stmt-pe-p{n}", page(body), [
            {"amount": r["amount"], "date": r["date"], "currency": "PEN", "merchant": r["desc"].split()[1] if r["desc"].split()[0] in ("COMPRA", "PAGO") else r["desc"]}
            for r in chunk], "list"))
    # Página 4: condiciones. Tiene cifras (tasas, comisiones) y ningún movimiento.
    body = header("BANCO ANDINO DEL PACÍFICO", ["ESTADO DE CUENTA — CUENTA DE AHORROS SOLES", "Titular: ANA LUCÍA TORRES VEGA (ficticio)"], ["Periodo: 01/09/2026 al 30/09/2026", "Página 4 de 4"])
    body += "<div style='font-size:12px;font-weight:700;margin:10px 0 6px'>INFORMACIÓN IMPORTANTE</div>"
    paras = [
        "Tasa de rendimiento efectiva anual (TREA): 0.25 %. Tasa efectiva anual (TEA): 0.25 % para saldos desde S/ 0.01.",
        "Comisión por mantenimiento de cuenta: S/ 0.00 si el saldo promedio mensual es mayor a S/ 1,000.00; en otro caso, S/ 8.00 mensuales.",
        "Retiros en cajeros de otras redes: S/ 7.50 por operación. Impuesto a las Transacciones Financieras (ITF): 0.005 %.",
        "Los depósitos están protegidos por el Fondo de Seguro de Depósitos hasta S/ 125,603.00 (monto ficticio de ejemplo).",
        "Si no está conforme con algún movimiento, tiene 30 días desde la fecha de corte para presentar su reclamo en cualquiera de nuestras agencias o en la banca por internet.",
        "Saldo promedio del periodo: S/ 3,912.18. Intereses ganados en el periodo: S/ 0.81 (se abonarán el próximo mes).",
    ]
    body += "".join(f"<p style='margin:0 0 9px;font-size:10px;line-height:1.5'>{p}</p>" for p in paras)
    body += footer("<span>Banco Andino del Pacífico S.A. — documento ficticio</span><span>Página 4 de 4</span>")
    out.append(("stmt-pe-p4", page(body), [], "unknown"))
    # La misma cuenta en UNA página densa: las 40 filas a letra de 7 pt, como apiñan su PDF muchos bancos. Es el «uno
    # de 40, no medido» del ticket: a 2× la página mide 1684 px de alto y la app la reduce a 1536.
    dense = header("BANCO ANDINO DEL PACÍFICO", ["ESTADO DE CUENTA — CUENTA DE AHORROS SOLES", "Titular: ANA LUCÍA TORRES VEGA (ficticio)"],
                   ["Periodo: 01/09/2026 al 30/09/2026", "Moneda: SOLES (S/)", "Página 1 de 1"])
    bal = 3250.40
    trs = [{"cells": ["", "SALDO ANTERIOR", "", "", money_pe(bal)], "style": "font-weight:700;background:#f2f5f9;padding:2px 4px"}]
    for r in rows:
        bal = round(bal + r["amount"], 2)
        d = r["date"]
        fecha = f"{d[8:10]}{PE_MONTHS[int(d[5:7]) - 1]}"
        c, a = (money_pe(-r["amount"]), "") if r["amount"] < 0 else ("", money_pe(r["amount"]))
        trs.append({"cells": [fecha, r["desc"], c, a, money_pe(bal)], "style": "padding:2px 4px"})
    trs.append({"cells": ["", "TOTAL CARGOS / ABONOS", money_pe(-sum(r["amount"] for r in rows if r["amount"] < 0)), money_pe(sum(r["amount"] for r in rows if r["amount"] > 0)), ""], "style": "font-weight:700;padding:2px 4px"})
    trs.append({"cells": ["", "SALDO AL CORTE 30/09/2026", "", "", money_pe(bal)], "style": "font-weight:700;background:#f2f5f9;padding:2px 4px"})
    dense += f"<div style='font-size:7px'>{table(['Fecha', 'Descripción', 'Cargos S/', 'Abonos S/', 'Saldo S/'], trs, ['left', 'left', 'right', 'right', 'right'])}</div>"
    dense += footer("<span>Banco Andino del Pacífico S.A. — documento ficticio</span><span>Página 1 de 1</span>")
    out.append(("stmt-pe-dense", page(dense), [
        {"amount": r["amount"], "date": r["date"], "currency": "PEN", "merchant": r["desc"].split()[1] if r["desc"].split()[0] in ("COMPRA", "PAGO") else r["desc"]}
        for r in rows], "list"))
    return out


# ------------------------------------------------------------------ en-US

US_ROWS_P2 = [
    ("09/02", "DEBIT CARD PURCHASE GREEN GROCER #12", -64.18), ("09/03", "ONLINE TRANSFER FROM SAVINGS", 500.00),
    ("09/04", "DEBIT CARD PURCHASE CITY FUEL 3381", -41.07), ("09/05", "ACH DEBIT RIVERSIDE ELECTRIC", -98.40),
    ("09/08", "DEBIT CARD PURCHASE CORNER CAFE", -7.25), ("09/09", "ATM WITHDRAWAL 5TH AVE", -120.00),
    ("09/10", "DEBIT CARD PURCHASE BOOK NOOK", -23.99), ("09/12", "ACH DEBIT METRO RENTALS LLC", -1450.00),
    ("09/15", "PAYROLL DEPOSIT ACME WIDGETS", 2600.00), ("09/16", "DEBIT CARD PURCHASE PHARMA PLUS", -18.62),
    ("09/17", "ZELLE PAYMENT TO J SMITH", -45.00), ("09/18", "DEBIT CARD PURCHASE HOME & HARDWARE", -76.34),
]
US_ROWS_P3 = [
    ("09/20", "DEBIT CARD PURCHASE GREEN GROCER #12", -88.51), ("09/22", "ACH DEBIT CITYNET INTERNET", -59.99),
    ("09/23", "DEBIT CARD PURCHASE TACO STAND", -12.40), ("09/24", "CHECK #1042", -200.00),
    ("09/26", "DEBIT CARD PURCHASE STREAMFLIX", -15.49), ("09/27", "MOBILE DEPOSIT", 145.00),
    ("09/29", "DEBIT CARD PURCHASE CITY FUEL 3381", -38.66), ("09/30", "MONTHLY SERVICE FEE", -12.00),
]


def build_us():
    begin = 4210.55
    allrows = US_ROWS_P2 + US_ROWS_P3
    dep = sum(a for _, _, a in allrows if a > 0)
    wd = -sum(a for _, _, a in allrows if a < 0)
    end = round(begin + dep - wd, 2)
    head = lambda n: header("FIRST HARBOR BANK", ["Everyday Checking Statement", "JORDAN A. MILLER (fictitious)", "Account number: ****7720"],
                           ["Statement period: Sep 1, 2026 – Sep 30, 2026", f"Page {n} of 3"])
    out = []
    # Página 1: resumen. Solo saldos y totales.
    body = head(1)
    body += "<div style='font-size:13px;font-weight:700;margin:14px 0 8px'>Account summary</div>"
    summ = [("Beginning balance on Sep 1", begin), ("Deposits and other additions", dep), ("Withdrawals and other subtractions", -wd),
            ("Ending balance on Sep 30", end)]
    body += table(["", "Amount"], [{"cells": [k, ("-$" if v < 0 else "$") + money_us(abs(v))], "style": "font-size:11px;padding:6px 4px"} for k, v in summ], ["left", "right"])
    body += "<div style='margin-top:18px;font-size:10px;line-height:1.5'>Average ledger balance: $4,689.02 · Annual percentage yield earned: 0.01% · Interest paid this period: $0.04 · Interest paid year-to-date: $0.31.<br>Avoid the $12.00 monthly service fee by keeping a minimum daily balance of $1,500 or receiving direct deposits of $500 or more.</div>"
    body += footer("<span>First Harbor Bank, N.A. — fictitious document. Member FDIC (example).</span><span>Page 1 of 3</span>")
    out.append(("stmt-us-p1", page(body), [], "unknown"))
    bal = begin
    for n, rows in ((2, US_ROWS_P2), (3, US_ROWS_P3)):
        body = head(n)
        body += "<div style='font-size:12px;font-weight:700;margin:10px 0 6px'>Transaction details</div>"
        trs = [{"cells": ["", "Beginning balance" if n == 2 else "Balance forward", "", money_us(bal)], "style": "font-weight:700;background:#f2f5f9"}]
        for d, desc, a in rows:
            bal = round(bal + a, 2)
            trs.append({"cells": [d, desc, ("-" if a < 0 else "") + money_us(abs(a)), money_us(bal)]})
        if n == 2:
            trs.append({"cells": ["", "Balance carried forward to next page", "", money_us(bal)], "style": "font-weight:700;background:#f2f5f9"})
        else:
            trs.append({"cells": ["", "Total deposits and additions", money_us(dep), ""], "style": "font-weight:700;border-top:1px solid #1f3a5f"})
            trs.append({"cells": ["", "Total withdrawals and subtractions", "-" + money_us(wd), ""], "style": "font-weight:700"})
            trs.append({"cells": ["", "Ending balance", "", money_us(bal)], "style": "font-weight:700;background:#f2f5f9"})
        body += table(["Date", "Description", "Amount", "Balance"], trs, ["left", "left", "right", "right"])
        body += footer(f"<span>First Harbor Bank, N.A. — fictitious document</span><span>Page {n} of 3</span>")
        out.append((f"stmt-us-p{n}", page(body), [
            # La página de detalle no escribe «$» en ninguna parte (solo el resumen de la página 1): leída sola, `null`
            # es la respuesta que pide el prompt («If no currency indicator found → null»).
            {"amount": a, "date": f"2026-{d[:2]}-{d[3:]}", "currency": "USD", "currencyAlt": [None],
             "merchant": desc.replace("DEBIT CARD PURCHASE ", "").replace("ACH DEBIT ", "").split(" #")[0]}
            for d, desc, a in rows], "list"))
    assert abs(bal - end) < 0.001
    return out


# ------------------------------------------------------------------ es-ES

ES_P1 = [
    ("01/09", "COMPRA TARJ. SUPERMERCADOS DEL BARRIO", -42.37), ("02/09", "RECIBO LUZ ENERGÍA COSTA", -61.20),
    ("03/09", "BIZUM DE MARTA G.", 25.00), ("04/09", "COMPRA TARJ. GASOLINERA RUTA 9", -55.10),
    ("05/09", "COMPRA TARJ. FARMACIA PLAZA", -12.85), ("08/09", "TRANSFERENCIA ALQUILER SEPTIEMBRE", -780.00),
    ("09/09", "COMPRA TARJ. LIBRERÍA EL FARO", -18.90), ("10/09", "RECIBO TELÉFONO MÓVIL", -29.99),
    ("11/09", "COMPRA TARJ. CAFETERÍA SOL", -4.60), ("12/09", "REINTEGRO CAJERO", -100.00),
]
ES_P2 = [
    ("15/09", "COMPRA TARJ. SUPERMERCADOS DEL BARRIO", -67.14), ("18/09", "COMPRA TARJ. RESTAURANTE LA HUERTA", -38.50),
    ("22/09", "RECIBO GIMNASIO VITAL", -34.90), ("25/09", "COMPRA TARJ. ZAPATERÍA PASOS", -59.95),
    ("26/09", "COMPRA TARJ. CINE ALAMEDA", -16.80), ("28/09", "NÓMINA EMPRESA EJEMPLO S.L.", 2140.00),
    ("29/09", "COMPRA TARJ. FERRETERÍA CENTRO", -9.75), ("30/09", "COMISIÓN MANTENIMIENTO", -6.00),
]


def build_es():
    begin = 1984.32
    out = []
    bal = begin
    for n, rows in ((1, ES_P1), (2, ES_P2)):
        body = header("CAJA EJEMPLO DEL NORTE", ["Extracto de cuenta corriente", "Titular: PABLO RUIZ NAVARRO (ficticio)", "IBAN: ES00 0000 0000 0000 0000 4417"],
                      ["Periodo: 01/09/2026 – 30/09/2026", "Divisa: EUR", f"Hoja {n} de 2"])
        trs = [{"cells": ["", "SALDO ANTERIOR" if n == 1 else "SUMA ANTERIOR", "", "", money_es(bal)], "style": "font-weight:700;background:#f2f5f9"}]
        debe = haber = 0.0
        for d, desc, a in rows:
            bal = round(bal + a, 2)
            if a < 0:
                debe += -a
                trs.append({"cells": [d, desc, money_es(-a), "", money_es(bal)]})
            else:
                haber += a
                trs.append({"cells": [d, desc, "", money_es(a), money_es(bal)]})
        trs.append({"cells": ["", "TOTAL HOJA", money_es(debe), money_es(haber), ""], "style": "font-weight:700;border-top:1px solid #1f3a5f"})
        if n == 1:
            trs.append({"cells": ["", "SUMA Y SIGUE", "", "", money_es(bal)], "style": "font-weight:700;background:#f2f5f9"})
        else:
            trs.append({"cells": ["", "SALDO FINAL A 30/09/2026", "", "", money_es(bal)], "style": "font-weight:700;background:#f2f5f9"})
        body += table(["F. valor", "Concepto", "Debe €", "Haber €", "Saldo €"], trs, ["left", "left", "right", "right", "right"])
        body += footer(f"<span>Caja Ejemplo del Norte — documento ficticio</span><span>Hoja {n} de 2</span>")
        out.append((f"stmt-es-p{n}", page(body), [
            {"amount": a, "date": f"2026-{d[3:]}-{d[:2]}", "currency": "EUR",
             "merchant": desc.replace("COMPRA TARJ. ", "").replace("RECIBO ", "")} for d, desc, a in rows], "list"))
    return out


# ------------------------------------------------------------------ es-PE, tarjeta de crédito

TC_P1 = [
    ("03SET", "SUPERMERCADO LA ECONOMIA", 182.40), ("04SET", "GRIFO NORTE SAC", 120.00), ("06SET", "PAGO RECIBIDO - GRACIAS", -800.00),
    ("07SET", "STREAMING PLUS", 44.90), ("09SET", "RESTAURANTE EL BUEN SABOR", 96.50), ("11SET", "TIENDA DEPORTES CUMBRE CUOTA 02/06", 83.25),
    ("12SET", "FARMACIA SALUD TOTAL", 37.80), ("14SET", "TAXI APP", 18.60), ("15SET", "LIBRERIA CENTRAL", 59.00),
]
TC_P2 = [
    ("18SET", "AEROLINEA ANDES CUOTA 01/03", 312.33), ("20SET", "SUPERMERCADO LA ECONOMIA", 141.27), ("22SET", "CINE ESTRELLA", 36.00),
    ("25SET", "DEVOLUCION TIENDA DEPORTES", -45.00), ("27SET", "INTERESES DEL PERIODO", 28.14), ("27SET", "COMISION MEMBRESIA ANUAL", 99.00),
]


def build_tc():
    prev = 1245.60
    out = []
    bal = prev
    for n, rows in ((1, TC_P1), (2, TC_P2)):
        body = header("BANCO ANDINO DEL PACÍFICO", ["ESTADO DE CUENTA — TARJETA DE CRÉDITO VISA ORO", "Titular: ANA LUCÍA TORRES VEGA (ficticio)", "Tarjeta: 4557 **** **** 2210"],
                      ["Fecha de corte: 30/09/2026", "Último día de pago: 25/10/2026", "Moneda: SOLES", f"Página {n} de 2"])
        trs = [{"cells": ["", "SALDO ANTERIOR" if n == 1 else "SALDO QUE VIENE DE LA PÁGINA ANTERIOR", money_pe(bal)], "style": "font-weight:700;background:#f2f5f9"}]
        sub = 0.0
        for d, desc, a in rows:
            bal = round(bal + a, 2)
            sub += a
            trs.append({"cells": [d, desc, money_pe(a)]})
        trs.append({"cells": ["", "SUBTOTAL MOVIMIENTOS DE LA PÁGINA", money_pe(sub)], "style": "font-weight:700;border-top:1px solid #1f3a5f"})
        if n == 1:
            trs.append({"cells": ["", "SALDO QUE PASA A LA SIGUIENTE PÁGINA", money_pe(bal)], "style": "font-weight:700;background:#f2f5f9"})
        else:
            trs.append({"cells": ["", "DEUDA TOTAL AL CORTE", money_pe(bal)], "style": "font-weight:700;background:#f2f5f9"})
            trs.append({"cells": ["", "PAGO MÍNIMO DEL MES", money_pe(round(bal * 0.05, 2))], "style": "font-weight:700"})
        body += table(["Fecha", "Descripción", "Importe S/"], trs, ["left", "left", "right"])
        body += "<div style='margin-top:12px;font-size:9px;color:#555'>Los consumos se muestran en positivo; los pagos y devoluciones, en negativo. TEA compras: 69.90 %. Documento ficticio.</div>"
        body += footer(f"<span>Banco Andino del Pacífico S.A. — documento ficticio</span><span>Página {n} de 2</span>")
        txs = []
        for d, desc, a in rows:
            t = {"amount": round(-a, 2), "date": f"2026-09-{d[:2]}", "currency": "PEN", "merchant": desc.split(" CUOTA")[0]}
            if a < 0:  # el pago y la devolución abonan a la tarjeta; como en s03, el signo contrario también se acepta
                t["amountAlt"] = [round(a, 2)]
            txs.append(t)
        out.append((f"stmt-tc-p{n}", page(body), txs, "list"))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    built = build_pe() + build_us() + build_es() + build_tc()
    cases = []
    for cid, html, txs, image_type in built:
        name = cid
        render(name, html, **A4)
        is_pe, is_us = cid.startswith(("stmt-pe", "stmt-tc")), cid.startswith("stmt-us")
        lang = "es-PE" if is_pe else "en-US" if is_us else "es-ES"
        main_ccy = "PEN" if is_pe else "USD" if is_us else "EUR"
        kind = (f"extracto multipágina, página sin movimientos ({'condiciones' if is_pe else 'resumen de cuenta'})" if not txs
                else "extracto en una página densa: 40 movimientos a 7 pt, con saldo anterior y totales" if cid.endswith("dense") else f"extracto multipágina{' de tarjeta (saldo en la columna de importes)' if cid.startswith('stmt-tc') else ''}, {len(txs)} movimientos con saldo arrastrado y subtotales")
        cases.append({
            "id": cid, "file": f"{name}.png", "today": TODAY, "kind": kind, "lang": lang,
            "source": "sintética (fixtures/make_statements.py), página de PDF a 2×",
            "expect": {"imageType": image_type, "transactions": [
                {k: (round(v, 2) if k == "amount" else v) for k, v in t.items()} for t in txs]},
            "currencyContext": {"main": main_ccy, "accounts": [main_ccy]},
        })
    with open(CASES_FILE, encoding="utf-8") as f:
        data = json.load(f)
    data["cases"] = [c for c in data["cases"] if not c["id"].startswith("stmt-")] + cases
    with open(CASES_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"{len(cases)} páginas: " + ", ".join(f"{c['id']}={len(c['expect']['transactions'])}" for c in cases))


if __name__ == "__main__":
    main()
