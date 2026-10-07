#!/usr/bin/env python3
"""
Genera las imágenes sintéticas del banco de `photo.read` (bench/cases/photo/*.png).

Por qué sintéticas: una captura de pantalla ES un render, así que renderizar una notificación o un
extracto con datos ficticios produce lo mismo que la captura de un usuario, sin datos personales. Los
recibos «fotografiados» se renderizan y después se les aplica perspectiva, giro, sombra, desenfoque y
ruido, para que el modelo lea papel y no píxeles limpios.

Todo es ficticio: comercios, bancos, nombres y números. Los nombres de banco son genéricos a propósito.

Uso:  python3 bench/fixtures/make_photos.py        (necesita Google Chrome y Pillow)
La verdad de cada imagen está en bench/cases/photo.read.json; si cambias un importe aquí, cámbialo allí.
"""
import os
import random
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "cases", "photo"))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BASE_CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, 'SF Pro Text', 'Helvetica Neue', 'Hiragino Sans', 'PingFang SC', sans-serif; }
"""


def render(name, html, width=393, height=852, scale=3, page_bg="#ffffff"):
    """HTML → PNG con Chrome headless, a @3x como un iPhone. La escala va por `zoom` de CSS: con
    `--force-device-scale-factor` el headless nuevo maqueta más ancho de lo que captura y corta la derecha."""
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
        f.write(f"<!doctype html><html style='zoom:{scale};background:{page_bg}'><head><meta charset='utf-8'><style>{BASE_CSS} body{{width:{width}px}}</style></head><body>{html}</body></html>")
        path = f.name
    out = os.path.join(OUT, f"{name}.png")
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
         f"--window-size={int(width * scale)},{int(height * scale)}", f"--screenshot={out}", f"file://{path}"],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    os.unlink(path)
    return out


def photograph(src, name, angle=2.5, seed=1, blur=0.8, noise=10, bg=(120, 92, 66), shadow=True, dim=1.0):
    """Convierte un render de papel en una «foto»: fondo, giro, perspectiva leve, sombra, ruido."""
    rnd = random.Random(seed)
    paper = Image.open(src).convert("RGB")
    # Solo el papel: lo más claro del render (el fondo de la plantilla es oscuro).
    bbox = paper.convert("L").point(lambda v: 255 if v > 200 else 0).getbbox()
    if bbox:
        paper = paper.crop(bbox)
    w, h = paper.size
    canvas = Image.new("RGB", (int(w * 1.35), int(h * 1.12)), bg)
    # textura de mesa
    d = ImageDraw.Draw(canvas)
    for _ in range(400):
        x = rnd.randint(0, canvas.width)
        c = tuple(max(0, min(255, v + rnd.randint(-18, 18))) for v in bg)
        d.line([(x, 0), (x + rnd.randint(-40, 40), canvas.height)], fill=c, width=rnd.randint(1, 4))
    paper = paper.rotate(angle, resample=Image.BICUBIC, expand=True, fillcolor=bg)
    ox, oy = (canvas.width - paper.width) // 2, (canvas.height - paper.height) // 2
    if shadow:
        sh = Image.new("L", paper.size, 0)
        ImageDraw.Draw(sh).rectangle([10, 10, paper.width - 1, paper.height - 1], fill=110)
        sh = sh.filter(ImageFilter.GaussianBlur(25))
        canvas.paste((30, 25, 20), (ox + 18, oy + 22), sh)
    mask = Image.new("L", paper.size, 0)
    ImageDraw.Draw(mask).rectangle([0, 0, paper.width, paper.height], fill=255)
    mask = paper.convert("L").point(lambda v: 255 if v > 3 else 0)
    canvas.paste(paper, (ox, oy), mask)
    # perspectiva leve (cámara no cenital)
    cw, ch = canvas.size
    k = 0.035
    coeffs = _perspective_coeffs(
        [(0, 0), (cw, 0), (cw, ch), (0, ch)],
        [(cw * k, ch * k * 0.4), (cw * (1 - k * 0.3), 0), (cw, ch), (0, ch * (1 - k * 0.2))],
    )
    canvas = canvas.transform(canvas.size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    # luz: viñeta y brillo
    vign = Image.radial_gradient("L").resize(canvas.size).point(lambda v: int(v * 0.55))
    canvas = Image.composite(Image.new("RGB", canvas.size, (0, 0, 0)), canvas, vign)
    canvas = ImageEnhance.Brightness(canvas).enhance(dim)
    canvas = canvas.filter(ImageFilter.GaussianBlur(blur))
    if noise:
        px = canvas.load()
        for _ in range(canvas.width * canvas.height // 12):
            x, y = rnd.randrange(canvas.width), rnd.randrange(canvas.height)
            r, g, b = px[x, y]
            n = rnd.randint(-noise, noise)
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    out = os.path.join(OUT, f"{name}.jpg")
    canvas.save(out, "JPEG", quality=88)
    os.unlink(src)
    return out


def _perspective_coeffs(src, dst):
    import numpy as np  # noqa: PLC0415

    a = []
    for (x, y), (u, v) in zip(dst, src):
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        a.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    A = np.array(a, dtype=float)
    B = np.array([c for p in src for c in p], dtype=float)
    return np.linalg.solve(A, B).tolist()


# ---------------------------------------------------------------- plantillas

STATUS = """<div style="display:flex;justify-content:space-between;padding:14px 28px 6px;font-weight:600;font-size:16px;color:{c}">
<span>{time}</span><span>●●● 5G ▮</span></div>"""


def lockscreen(notifs, time="9:41", date="miércoles, 7 de octubre", dark_bg="#2b3a55"):
    cards = "".join(
        f"""<div style="background:rgba(245,245,247,.82);border-radius:20px;padding:12px 14px;margin:8px 10px;color:#111">
<div style="display:flex;justify-content:space-between;font-size:13px;color:#555;margin-bottom:3px">
<span style="display:flex;align-items:center;gap:6px"><span style="display:inline-block;width:20px;height:20px;border-radius:5px;background:{n['color']}"></span><b style="color:#333">{n['app']}</b></span><span>{n['when']}</span></div>
<div style="font-weight:600;font-size:15px">{n['title']}</div><div style="font-size:15px;line-height:1.3">{n['body']}</div></div>"""
        for n in notifs
    )
    return f"""<div style="height:852px;background:linear-gradient(160deg,{dark_bg},#0f1626);color:white">
{STATUS.format(c='white', time='')}
<div style="text-align:center;font-size:18px;font-weight:500;margin-top:24px">{date}</div>
<div style="text-align:center;font-size:84px;font-weight:300;line-height:1">{time}</div>
<div style="margin-top:60px">{cards}</div></div>"""


def table_page(title, subtitle, head, rows, foot="", dark=False, font="-apple-system"):
    bg, fg, line = ("#000", "#f2f2f7", "#2c2c2e") if dark else ("#fff", "#111", "#e5e5ea")
    trs = "".join(
        "<tr>" + "".join(f"<td style='padding:7px 4px;border-bottom:1px solid {line};{('text-align:right;white-space:nowrap' if i >= len(r) - 2 else '')}'>{c}</td>" for i, c in enumerate(r)) + "</tr>"
        for r in rows
    )
    ths = "".join(f"<th style='text-align:{'right' if i >= len(head) - 2 else 'left'};padding:6px 4px;border-bottom:2px solid {fg};font-size:11px'>{h}</th>" for i, h in enumerate(head))
    return f"""<div style="background:{bg};color:{fg};min-height:100vh;padding:18px 14px;font-family:{font}">
<div style="font-size:20px;font-weight:700">{title}</div><div style="font-size:12px;opacity:.7;margin:2px 0 12px">{subtitle}</div>
<table style="width:100%;border-collapse:collapse;font-size:11.5px">{('<thead><tr>' + ths + '</tr></thead>') if head else ''}<tbody>{trs}</tbody></table>
<div style="font-size:11px;opacity:.7;margin-top:10px">{foot}</div></div>"""


def receipt(lines, width=300, font="Menlo, 'Courier New', monospace", size=12.5):
    body = "".join(
        f"<div style='display:flex;justify-content:space-between;gap:8px'><span>{a}</span><span style='white-space:nowrap'>{b}</span></div>" if isinstance(l, tuple) and (a := l[0]) is not None and (b := l[1]) is not None
        else f"<div style='text-align:center'>{l}</div>"
        for l in lines
    )
    return f"""<div style="background:#5a4632;padding:20px;min-height:100vh"><div style="background:#fbfaf6;width:{width}px;margin:0 auto;padding:18px 16px 28px;font-family:{font};font-size:{size}px;line-height:1.35;color:#1d1d1d">{body}</div></div>"""


# ---------------------------------------------------------------- casos

def main():
    os.makedirs(OUT, exist_ok=True)

    # S1 · pantalla bloqueada con tres notificaciones de bancos peruanos (fechas relativas)
    render("s01-lockscreen-notifs-es-PE", lockscreen([
        {"app": "Banca Móvil", "color": "#0a3d91", "when": "hace 12 min", "title": "Consumo con tu tarjeta",
         "body": "Realizaste un consumo de S/ 89.90 con tu Tarjeta de Débito ****4821 en RAPPI*RESTAURANTES."},
        {"app": "Billetera", "color": "#6c1d8f", "when": "hace 2 h", "title": "Pagaste con tu billetera",
         "body": "Pagaste S/ 12.50 a BODEGA DON LUCHO."},
        {"app": "Banca Móvil", "color": "#0a3d91", "when": "Ayer, 20:14", "title": "Consumo con tu tarjeta",
         "body": "Realizaste un consumo de S/ 246.30 con tu Tarjeta de Crédito ****1907 en SUPERMERCADOS TOTTUS."},
    ]))

    # S2 · extracto de cuenta (es-ES), 20 movimientos, con columna de saldo como distractor
    movs = [
        ("01/09/2026", "RECIBO LUZ ENERGIA VERDE", "-58,34", "2.341,66"),
        ("01/09/2026", "NÓMINA ACME SERVICIOS SL", "1.950,00", "4.291,66"),
        ("02/09/2026", "COMPRA MERCADONA C/ SOL", "-43,12", "4.248,54"),
        ("03/09/2026", "BIZUM DE LAURA M.", "15,00", "4.263,54"),
        ("03/09/2026", "COMPRA FARMACIA LUNA", "-9,80", "4.253,74"),
        ("05/09/2026", "ALQUILER SEPTIEMBRE", "-850,00", "3.403,74"),
        ("06/09/2026", "COMPRA GASOLINERA REPSOL", "-62,10", "3.341,64"),
        ("07/09/2026", "RESTAURANTE EL FAROL", "-37,50", "3.304,14"),
        ("09/09/2026", "SUSCRIPCION SPOTIFY", "-10,99", "3.293,15"),
        ("10/09/2026", "COMPRA AMAZON EU", "-24,99", "3.268,16"),
        ("12/09/2026", "CAJERO RETIRADA", "-60,00", "3.208,16"),
        ("13/09/2026", "COMPRA LIDL AV. MAR", "-31,45", "3.176,71"),
        ("15/09/2026", "SEGURO HOGAR", "-21,30", "3.155,41"),
        ("16/09/2026", "DEVOLUCION AMAZON EU", "24,99", "3.180,40"),
        ("18/09/2026", "COMPRA EL CORTE INGLES", "-79,90", "3.100,50"),
        ("20/09/2026", "CINE YELMO", "-17,40", "3.083,10"),
        ("22/09/2026", "RECIBO GIMNASIO", "-34,90", "3.048,20"),
        ("24/09/2026", "COMPRA MERCADONA C/ SOL", "-52,77", "2.995,43"),
        ("27/09/2026", "TRANSFERENCIA A PEDRO G.", "-100,00", "2.895,43"),
        ("29/09/2026", "RECIBO MOVIL TELCO", "-19,99", "2.875,44"),
    ]
    render("s02-statement-es-ES", table_page("Movimientos de la cuenta", "Cuenta ****3471 · septiembre 2026 · importes en EUR",
                                              ["Fecha", "Concepto", "Importe", "Saldo"], movs,
                                              "Saldo final: 2.875,44 EUR"), height=1150)

    # S3 · extracto de tarjeta (en-US), USD, con un pago (abono)
    card = [
        ("09/02", "WHOLE FOODS MKT #102", "54.21"), ("09/03", "SHELL OIL 5741", "38.90"), ("09/04", "NETFLIX.COM", "15.49"),
        ("09/06", "UBER *TRIP", "23.75"), ("09/07", "STARBUCKS STORE 2210", "6.85"), ("09/09", "AMAZON MKTPL", "112.37"),
        ("09/11", "TARGET 00012", "47.06"), ("09/12", "PAYMENT - THANK YOU", "-500.00"), ("09/14", "CHIPOTLE 1873", "14.20"),
        ("09/16", "CVS PHARMACY", "11.48"), ("09/19", "DELTA AIR 0062", "289.40"), ("09/21", "MARRIOTT DOWNTOWN", "412.88"),
        ("09/23", "SPOTIFY USA", "11.99"), ("09/25", "TRADER JOE'S #55", "68.31"), ("09/27", "APPLE.COM/BILL", "2.99"),
        ("09/29", "COSTCO WHSE #0441", "203.57"),
    ]
    render("s03-card-statement-en-US", table_page("Card activity", "Visa ending 0092 · Statement period Sep 1 – Sep 30, 2026 · Charges are shown as positive amounts",
                                                  ["Date", "Description", "", "Amount ($)"], [(d, m, "", a) for d, m, a in card]), height=1000)

    # S4 · recibo largo de supermercado (es-PE), fotografiado
    items = [("Arroz Costeño 5kg", "24.90"), ("Aceite Primor 1L", "11.50"), ("Leche Gloria x6", "25.80"), ("Huevos x15", "13.90"),
             ("Pollo entero kg 2.3", "23.00"), ("Papa amarilla kg 2", "7.60"), ("Cebolla roja kg 1", "3.20"), ("Tomate kg 1.5", "6.75"),
             ("Limón kg 1", "4.50"), ("Pan francés x10", "4.00"), ("Mantequilla 200g", "8.90"), ("Queso fresco 500g", "12.40"),
             ("Yogurt fresa 1L", "7.90"), ("Café molido 250g", "16.90"), ("Azúcar rubia 1kg", "4.20"), ("Fideos x4", "10.40"),
             ("Atún x3", "17.70"), ("Detergente 2kg", "22.90"), ("Papel higiénico x12", "19.90"), ("Shampoo 400ml", "15.90"),
             ("Jabón x3", "8.70"), ("Galletas x6", "6.90"), ("Gaseosa 3L", "9.50"), ("Agua 2.5L x2", "7.00"),
             ("Manzana kg 1.2", "7.80"), ("Plátano kg 1", "3.50"), ("Avena 900g", "8.40"), ("Mermelada 300g", "6.30"),
             ("Bolsa reusable", "1.50")]
    total = sum(float(p) for _, p in items)
    lines = ["<b>SUPERMERCADOS LA ECONOMÍA S.A.</b>", "RUC 20123456789", "Av. Los Próceres 1450 - Lima", "BOLETA DE VENTA ELECTRÓNICA", "B021-00084512",
             ("FECHA: 04/10/2026", "HORA: 18:52"), "-" * 38] + [(n, p) for n, p in items] + ["-" * 38,
             ("OP. GRAVADA", f"{total / 1.18:.2f}"), ("IGV 18%", f"{total - total / 1.18:.2f}"), (f"<b>TOTAL S/</b>", f"<b>{total:.2f}</b>"),
             ("VISA ****5518", f"{total:.2f}"), "-" * 38, "GRACIAS POR SU COMPRA", "Representación impresa de la", "Boleta de Venta Electrónica"]
    assert f"{total:.2f}" == "321.85", total
    src = render("_s04", receipt(lines), width=380, height=1060, scale=4, page_bg="#5a4632")
    photograph(src, "s04-long-receipt-photo-es-PE", angle=-2.0, seed=4)

    # S5 · notificación pt-BR, real brasileño con coma decimal
    render("s05-notif-pt-BR", lockscreen([
        {"app": "Banco", "color": "#ec7000", "when": "agora", "title": "Compra aprovada",
         "body": "Compra aprovada no cartão final 4321: R$ 89,90 em PADARIA PAO QUENTE em 06/10 às 19:22."},
    ], date="quarta-feira, 7 de outubro", time="8:15"))

    # S6 · ticket de supermercado alemán, fotografiado con poca luz
    de_items = [("Vollmilch 1,5% 1L", "1,09"), ("Bio Bananen", "1,79"), ("Roggenbrot 750g", "2,49"), ("Butter 250g", "2,19"),
                ("Gouda Scheiben", "2,29"), ("Kaffee Bohnen 1kg", "12,99"), ("Mineralwasser 6x1,5L", "3,54"), ("Pfand", "1,50"),
                ("Tomaten 500g", "1,99"), ("Spaghetti 500g", "0,99"), ("Pesto Basilikum", "2,49"), ("Spülmittel", "1,15")]
    de_total = sum(float(p.replace(",", ".")) for _, p in de_items)
    assert f"{de_total:.2f}" == "34.50", de_total
    lines = ["<b>FRISCHMARKT GmbH</b>", "Hauptstraße 12 · 10115 Berlin", "-" * 34] + [(n, f"{p} A") for n, p in de_items] + ["-" * 34,
             ("<b>SUMME EUR</b>", "<b>34,50</b>"), ("Geg. EC-Karte EUR", "34,50"), "-" * 34, ("MwSt A 7%", "2,26"), ("Netto", "32,24"),
             ("03.10.2026", "17:41"), ("Bon-Nr. 4417", "Kasse 3"), "Vielen Dank für Ihren Einkauf!"]
    src = render("_s06", receipt(lines), width=380, height=640, scale=4, page_bg="#5a4632")
    photograph(src, "s06-receipt-photo-de-dim", angle=3.5, seed=6, dim=0.78, blur=1.1, noise=16)

    # S7 · aviso de tarjeta japonés (JPY)
    render("s07-card-notice-ja", f"""<div style="padding:20px 16px;font-family:'Hiragino Sans'">
{STATUS.format(c='#111', time='10:08')}
<div style="font-size:18px;font-weight:700;margin:14px 0">【カードご利用のお知らせ】</div>
<div style="font-size:14px;line-height:1.9">いつも当カードをご利用いただきありがとうございます。<br>下記のとおりご利用がありましたのでお知らせいたします。</div>
<div style="margin-top:18px;border:1px solid #ddd;border-radius:10px;padding:14px;font-size:15px;line-height:2">
ご利用日時：2026/10/05 13:42<br>ご利用先：ファミリーマート 渋谷駅前店<br>ご利用金額：<b>3,280円</b><br>カード番号：****-****-****-7310</div></div>""")

    # S8 · comprobante de pago chino (CNY)
    render("s08-payment-zh", f"""<div style="background:#ededed;min-height:852px;font-family:'PingFang SC'">
{STATUS.format(c='#111', time='12:33')}
<div style="text-align:center;padding-top:40px"><div style="width:64px;height:64px;border-radius:32px;background:#1aad19;margin:0 auto;color:white;font-size:40px;line-height:64px">✓</div>
<div style="font-size:18px;margin-top:14px">支付成功</div><div style="font-size:40px;font-weight:600;margin-top:10px">¥128.00</div></div>
<div style="background:white;margin:30px 14px;border-radius:10px;padding:6px 16px;font-size:15px;line-height:2.6">
<div style="display:flex;justify-content:space-between"><span style="color:#888">商户</span><span>盒马鲜生（静安店）</span></div>
<div style="display:flex;justify-content:space-between"><span style="color:#888">支付时间</span><span>2026-10-06 12:31:08</span></div>
<div style="display:flex;justify-content:space-between"><span style="color:#888">支付方式</span><span>零钱</span></div>
<div style="display:flex;justify-content:space-between"><span style="color:#888">交易单号</span><span>4200001234202610061234</span></div></div></div>""")

    # S9 · paragon polaco (PLN), fotografiado
    pl_items = [("Chleb żytni", "5,49"), ("Masło 200g", "7,99"), ("Mleko 2% 1L", "3,59"), ("Jajka L x10", "11,99"),
                ("Ser żółty 300g", "9,49"), ("Pomidory luz 0,8kg", "7,92"), ("Kawa mielona 500g", "24,99"), ("Woda 1,5L x6", "11,94")]
    pl_total = sum(float(p.replace(",", ".")) for _, p in pl_items)
    assert f"{pl_total:.2f}" == "83.40", pl_total
    lines = ["<b>SKLEP SPOŻYWCZY „POD LIPĄ”</b>", "ul. Długa 7, 31-147 Kraków", "NIP 676-000-11-22", "2026-10-02 &nbsp; 08:17", "PARAGON FISKALNY", "-" * 34] + \
            [(n, f"{p} A") for n, p in pl_items] + ["-" * 34, ("<b>SUMA PLN</b>", "<b>83,40</b>"), ("Karta płatnicza", "83,40"), "Dziękujemy!"]
    src = render("_s09", receipt(lines), width=380, height=520, scale=4, page_bg="#5a4632")
    photograph(src, "s09-receipt-photo-pl", angle=-4.0, seed=9, bg=(90, 90, 96))

    # S10 · detalle de transacción en app bancaria holandesa (EUR, coma)
    render("s10-bank-detail-nl", f"""<div style="padding:0 18px;font-family:-apple-system">
{STATUS.format(c='#111', time='14:02')}
<div style="font-size:15px;color:#0a6;margin:18px 0">‹ Terug</div>
<div style="text-align:center;margin-top:20px"><div style="font-size:15px;color:#555">Albert Heijn 1403</div>
<div style="font-size:38px;font-weight:600;margin:8px 0">-€ 34,12</div><div style="font-size:14px;color:#555">zondag 4 oktober 2026, 11:26</div></div>
<div style="margin-top:30px;font-size:15px;line-height:2.4;border-top:1px solid #eee">
<div style="display:flex;justify-content:space-between"><span style="color:#777">Rekening</span><span>NL** BANK 0123 4567 89</span></div>
<div style="display:flex;justify-content:space-between"><span style="color:#777">Type</span><span>Betaalautomaat</span></div>
<div style="display:flex;justify-content:space-between"><span style="color:#777">Categorie</span><span>Boodschappen</span></div></div></div>""")

    # S11 · notificación en modo oscuro (es-ES)
    render("s11-notif-dark-es-ES", lockscreen([
        {"app": "Mi Banco", "color": "#004481", "when": "09:12", "title": "Pago con tarjeta",
         "body": "Has pagado 12,50 € en CAFETERÍA LUNA con tu tarjeta ****1234 el 07/10/2026."},
    ], time="9:14", date="miércoles, 7 de octubre", dark_bg="#111111"))

    # S12 · captura que no es financiera (chat) → ningún movimiento
    render("s12-not-financial-chat", f"""<div style="background:#f2f2f7;min-height:852px;font-family:-apple-system">
{STATUS.format(c='#111', time='18:05')}
<div style="text-align:center;font-weight:600;padding:8px 0 14px;border-bottom:1px solid #ddd;background:#f9f9f9">Mamá</div>
<div style="padding:14px;font-size:16px;line-height:1.35">
<div style="background:#e5e5ea;border-radius:18px;padding:9px 13px;max-width:75%;margin:6px 0">¿Vienes el domingo a almorzar? Hago ají de gallina 😊</div>
<div style="background:#0a84ff;color:white;border-radius:18px;padding:9px 13px;max-width:75%;margin:6px 0 6px auto">¡Claro! Llevo el postre. ¿A las 2?</div>
<div style="background:#e5e5ea;border-radius:18px;padding:9px 13px;max-width:75%;margin:6px 0">Sí, a las 2. Dile a tu hermano que traiga las sillas.</div>
<div style="background:#0a84ff;color:white;border-radius:18px;padding:9px 13px;max-width:75%;margin:6px 0 6px auto">Le escribo ahora 👍</div></div></div>""")

    # S13 · ingreso recibido (es-PE): importe POSITIVO
    render("s13-income-notif-es-PE", lockscreen([
        {"app": "Banca Móvil", "color": "#0a3d91", "when": "ahora", "title": "Recibiste una transferencia",
         "body": "Recibiste S/ 1,250.00 de MARIA FERNANDA TORRES en tu cuenta ****0388."},
    ], time="11:02", date="martes, 6 de octubre"))

    # S14 · historial de billetera con grupos «Hoy» / «Ayer» y entradas y salidas
    hist = [("Hoy", [("Pago a Juan C.", "- S/ 25.00"), ("Recibido de Ana R.", "+ S/ 40.00"), ("Pago a Pollería El Rey", "- S/ 58.00")]),
            ("Ayer", [("Pago a Taxi Lima", "- S/ 18.00"), ("Pago a Minimarket Sofía", "- S/ 7.40")]),
            ("Dom. 4 oct.", [("Recibido de Carlos P.", "+ S/ 150.00"), ("Pago a Farmacia Salud", "- S/ 32.90"), ("Pago a Cine Star", "- S/ 26.00")])]
    blocks = "".join(
        f"<div style='font-size:13px;color:#6c1d8f;font-weight:700;margin:16px 0 4px'>{g}</div>" + "".join(
            f"<div style='display:flex;justify-content:space-between;padding:11px 0;border-bottom:1px solid #eee;font-size:15px'><span>{n}</span><b style='color:{'#0a8a3a' if a.startswith('+') else '#111'}'>{a}</b></div>"
            for n, a in items_)
        for g, items_ in hist)
    render("s14-wallet-history-es-PE", f"""<div style="padding:0 16px;font-family:-apple-system">{STATUS.format(c='#111', time='21:30')}
<div style="font-size:22px;font-weight:700;margin:10px 0">Movimientos</div>{blocks}</div>""")


if __name__ == "__main__":
    main()
