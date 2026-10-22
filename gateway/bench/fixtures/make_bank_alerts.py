#!/usr/bin/env python3
"""
Alertas y constancias de banco FICTICIAS para medir la NOTA de `photo.read` (ticket
`image-note-uses-bank-template-instead-of-merchant`, 2026-10-10).

El reporte real: la nota salió «GROK XAI - Consumo con tarjeta de crédito BCP» y debía ser «Grok (xAI)». Las alertas de
los bancos peruanos y sus billeteras traen la frase de plantilla («Consumo con tarjeta de crédito BCP», «Yapeaste»,
«Purchase approved»), el número de operación y la tarjeta enmascarada al lado del comercio. Cada imagen es un caso
`bank-*` de `bench/cases/photo.read.json` con su comercio esperado; la métrica de nota (`gradePhoto`) exige que la nota
final lo nombre y no traiga plantilla, banco ni códigos.

Los nombres de banco y billetera son los reales porque su plantilla es justo lo que se mide. Comercios, personas,
importes y números de operación son inventados.

Uso:  python3 bench/fixtures/make_bank_alerts.py        (necesita Google Chrome; reusa `make_photos.py`)
"""
from make_photos import STATUS, lockscreen, render


def detail_screen(app, color, title, amount, rows, foot=""):
    """Pantalla de constancia/detalle del movimiento dentro de la app del banco o la billetera."""
    trs = "".join(
        f"<div style='display:flex;justify-content:space-between;padding:12px 0;border-bottom:1px solid #e5e5ea'>"
        f"<span style='color:#6e6e73'>{k}</span><span style='font-weight:600;text-align:right;max-width:60%'>{v}</span></div>"
        for k, v in rows
    )
    return f"""<div style="min-height:852px;background:#f2f2f7;color:#111">
{STATUS.format(c='#111', time='9:41')}
<div style="background:{color};color:white;padding:18px 20px 26px;margin-top:4px">
<div style="font-size:14px;opacity:.85">{app}</div>
<div style="font-size:20px;font-weight:700;margin-top:6px">{title}</div>
<div style="font-size:38px;font-weight:700;margin-top:10px">{amount}</div></div>
<div style="background:white;margin:14px;border-radius:14px;padding:4px 16px;font-size:15px">{trs}</div>
<div style="font-size:12px;color:#6e6e73;margin:0 20px">{foot}</div></div>"""


def main():
    # B01 · el caso del reporte: alerta BCP de consumo en dólares en una suscripción
    render("b01-bcp-grok-es-PE", lockscreen([
        {"app": "BCP", "color": "#002a8d", "when": "08:48", "title": "Consumo con tarjeta de crédito BCP",
         "body": "Realizaste un consumo de US$ 105.60 con tu Tarjeta de Crédito ****5512 en GROK XAI. Nro. de operación 004512."},
    ], date="viernes, 10 de octubre", time="8:49"))

    # B02 · constancia BCP de débito con comercio y sucursal
    render("b02-bcp-detail-es-PE", detail_screen(
        "BCP", "#002a8d", "Consumo con Tarjeta de Débito BCP", "S/ 186.40",
        [("Comercio", "WONG SAN ISIDRO"), ("Fecha", "09 oct 2026, 7:22 p.m."), ("Tarjeta", "****4821"),
         ("N° de operación", "12345678"), ("Cuenta", "Ahorro Soles ****0193")]))

    # B03 · Interbank, notificación en español con código de operación
    render("b03-interbank-es-PE", lockscreen([
        {"app": "Interbank", "color": "#00a94f", "when": "hace 5 min", "title": "Consumo Tarjeta de Crédito",
         "body": "Interbank: Consumo con tu Tarjeta de Crédito Visa ****3311 por S/ 54.90 en TAMBO+ LARCOMAR. Op: 882140"},
    ], date="viernes, 10 de octubre"))

    # B04 · Interbank en inglés, descriptor de suscripción con referencia pegada
    render("b04-interbank-en", lockscreen([
        {"app": "Interbank", "color": "#00a94f", "when": "Yesterday", "title": "Credit card purchase",
         "body": "Interbank: Credit card purchase of US$ 22.99 at SPOTIFY P2A3B4C5 on 10/09. Ref 771203"},
    ], date="Friday, October 10"))

    # B05 · BBVA, detalle en español con «Has realizado una compra»
    render("b05-bbva-detail-es-PE", detail_screen(
        "BBVA", "#072146", "Has realizado una compra con tu tarjeta BBVA", "S/ 312.75",
        [("Comercio", "PLAZA VEA MIRAFLORES"), ("Fecha y hora", "08/10/2026 12:41"), ("Tarjeta", "Débito ****7712"),
         ("Código de autorización", "A55120"), ("Número de operación", "0091827364")]))

    # B06 · BBVA en inglés, descriptor de Uber con dominio
    render("b06-bbva-en", lockscreen([
        {"app": "BBVA", "color": "#072146", "when": "2h ago", "title": "Card purchase",
         "body": "BBVA: You made a purchase with your debit card ending 7712 for US$ 45.10 at UBER *TRIP HELP.UBER.COM."},
    ], date="Friday, October 10"))

    # B07 · Scotiabank, consumo aprobado con autorización
    render("b07-scotiabank-es-PE", lockscreen([
        {"app": "Scotiabank", "color": "#ec111a", "when": "hace 20 min", "title": "Consumo aprobado",
         "body": "Scotiabank: Consumo aprobado con tarjeta de crédito ****0098 por S/ 78.00 en KFC JOCKEY PLAZA. Autorización 553201"},
    ], date="viernes, 10 de octubre"))

    # B08 · Scotiabank en inglés, descriptor de Amazon con referencia
    render("b08-scotiabank-en", detail_screen(
        "Scotiabank", "#ec111a", "Purchase approved", "US$ 129.90",
        [("Merchant", "AMZN Mktp US*2K4X91LQ"), ("Date", "Oct 7, 2026"), ("Card", "Credit ****0098"),
         ("Transaction ID", "TX-88120431")]))

    # B09 · constancia de Yape a una persona
    render("b09-yape-es-PE", detail_screen(
        "Yape", "#742384", "¡Yapeaste!", "S/ 25",
        [("Para", "Juan Pérez Quispe"), ("Fecha", "10 oct. 2026 - 01:14 pm"), ("Nro. de operación", "03154827"),
         ("Destino", "Yape")]))

    # B10 · Yape en inglés, dinero recibido (ingreso)
    render("b10-yape-en", lockscreen([
        {"app": "Yape", "color": "#742384", "when": "now", "title": "You received a Yape",
         "body": "MARIA LOPEZ sent you S/ 40.00. Operation 77120938."},
    ], date="Friday, October 10"))

    # B11 · Plin desde Interbank a una bodega
    render("b11-plin-es-PE", lockscreen([
        {"app": "Interbank", "color": "#00a94f", "when": "hace 1 h", "title": "Pago con Plin",
         "body": "Pagaste S/ 18.50 a BODEGA SANTA ROSA con Plin desde tu cuenta Interbank. Operación 445120"},
    ], date="viernes, 10 de octubre"))

    # B12 · Plin en inglés, envío a una persona
    render("b12-plin-en", detail_screen(
        "Plin", "#00b2e3", "Plin transfer sent", "S/ 60.00",
        [("To", "CARLOS RAMIREZ"), ("Date", "Oct 9, 2026 18:05"), ("From", "BBVA account ****2201"),
         ("Transaction", "991204")]))


if __name__ == "__main__":
    main()
