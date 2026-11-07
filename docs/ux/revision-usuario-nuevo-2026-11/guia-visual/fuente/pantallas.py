"""Pantallas que se repiten entre partes: el recorrido de hoy recreado y el Panel base.

Caso único de toda la guía (datos ficticios): Ana · «Mi dinero Soles» S/ 1,500 · primer gasto «Almuerzo» S/ 18.50
· presupuesto «Comida» S/ 600 al mes · pago «Alquiler» S/ 900 el día 5 · segunda cuenta «Tarjeta de crédito», S/ 420
por pagar.
"""
from ui import *

MQ = ("mq", "Maqueta")
NEW = ("new", "Propuesta nueva")


def selector(first_note=None, tap=True, chg=False):
    first_sub = "Empieza desde cero. Te guiamos paso a paso."
    if first_note:
        first_sub += f'<br><span class="{"chg" if chg else ""}" style="display:inline-block;margin-top:3px;color:#ffd5ea">{first_note}</span>'
    return (onb_top(back=True)
            + head(None, "¡Hola! ¿Qué quieres hacer en Yala?", "Elige tu punto de partida y seguimos desde ahí.")
            + group(opt("sparkle", "Es mi primera vez en Yala", first_sub, color="#ec4899", chev=True,
                        cls="tap" if tap else ""),
                    opt("cloud", "Ya tengo una cuenta", "Ya usé Yala antes y quiero recuperar mis datos.", color="#38bdf8", chev=True),
                    opt("users", "Dividir gastos con amigos", "Viajes, casa compartida, salidas: crea un grupo o entra al de tus amigos.", color="#f59e0b", chev=True)))


def icloud(tap=True):
    return (onb_top(back=True) + '<div style="height:120px"></div>'
            + head("cloud-off", "Este dispositivo no tiene iCloud activo",
                   "Puedes empezar igual: por ahora tus datos se quedan aquí. Si activas iCloud más adelante, te avisamos antes de mezclar nada.")
            + btn("Seguir así", cls="tap" if tap else ""))


def reabre(extra=""):
    return ('<div style="height:150px"></div>' + logo(.8)
            + head("refresh", "Un último paso: reabre Yala",
                   "Para cuidar tus datos, Yala tiene que abrirse de nuevo. Ve a la pantalla de inicio y vuelve a entrar: seguimos justo donde lo dejaste.")
            + extra)


def paso_nombre(step=1, total=7, value="Ana", tap=True, title="Empecemos a organizar tu dinero"):
    return (onb_top(step, total, back=False, close=True) + '<div style="height:62px"></div><div class="center">' + logo(.75) + '</div>'
            + head(None, title, "Solo unos pasos para personalizar Yala a tu medida.")
            + field("¿Cómo quieres que te llamemos?", value=value, ph="Tu nombre")
            + bottom(btn("Siguiente", cls="tap" if tap else "")))


def paso_saldo(step=5, total=7, value="1,500", tap=True, extra="", zero_chip=False):
    z = ""
    if zero_chip:
        z = '<div class="chips chg" style="margin-top:8px;justify-content:center"><span class="chip">0 por ahora, lo ajusto luego</span></div>'
    return (onb_top(step, total) + '<div style="height:44px"></div>'
            + head("dollar", "¿Cuánto tienes en esta cuenta?", "Un aproximado está bien. ¿No lo sabes? Escribe 0 y ajústalo después.")
            + field("Saldo inicial · Mi dinero Soles", value=value, ph="Ej. 1500", big=True, unit="S/") + z + extra
            + bottom(btn("Siguiente", cls="tap" if tap else "")))


def resumen7(rows=None, priv=None, btn_text="Empezar a usar Yala", tap=True, chg_priv=False, step=7, total=7):
    rows = rows or [("user", "Ana"), ("card", "Mi dinero Soles · PEN"), ("cash", "S/ 1,500.00"), ("grid", "Categorías predeterminadas")]
    priv = priv or [("phone", "Datos en tu cuenta"), ("eye", "Sin rastreo ni anuncios"), ("user", "Acceso con tu cuenta"), ("shield", "IA a través de nuestro servidor")]
    r = group(*[f'<div class="lrow">{tint(i, "#ec4899", 22)}<div class="lt"><span>{t}</span></div></div>' for i, t in rows])
    p = "".join(f'<div class="tile" style="text-align:left;align-items:flex-start">{ic(i, 15)}<span>{t}</span></div>' for i, t in priv)
    return (onb_top(step, total) + '<div style="height:40px"></div>'
            + head(None, "¡Tu plan financiero arranca ahora!", "Así queda tu Yala")
            + r + f'<div class="flab" style="margin-top:10px">Tu privacidad</div><div class="cards2{" chg" if chg_priv else ""}">{p}</div>'
            + bottom(btn(btn_text, cls="tap" if tap else "")))


# ----------------------------------------------------------------- Panel
def panel(parts, tab="Panel", fab_btn=False, shrink=False, title=None):
    """Panel con piezas en orden. parts: lista de HTML."""
    t = tabbar(tab, shrink=shrink)
    f = fab() if fab_btn else ""
    return ptop(title) + "".join(parts) + f + t


def hoy_panel_dia1(tap_new=False):
    return panel([balance(), actions(tap_new=tap_new),
                  notice("Este es tu resumen", "Aquí ves de un vistazo cuánto has gastado y cuánto te queda. Toca Nuevo registro para apuntar un gasto.",
                         foot=("Aviso 1 de 3", "Ver el siguiente ›")),
                  sec("Tus finanzas", right=f'<span class="sct">{ic("chev-d", 11)}</span>'), acc_chips(),
                  sec("Tendencias", right=f'<span class="sct">{ic("grid", 10)}</span>'),
                  widget("Saldo", chart(single=True, height=50), q=True)])


def balance_after(spent="18.50"):
    return balance(amount="−18", cents="50", note1="Gastaste S/ 18.50 este mes", note2="Te quedan S/ 1,481.50 en tus cuentas",
                   out=spent)


def registro_sheet(name="Almuerzo", amount="18.50", catname="Alimentación", account="Mi dinero Soles", extra="", tap_save=True,
                   title="Nuevo registro"):
    return (sheet_top(title, right_on=True, cls="") .replace('class="circ d on"', f'class="circ d on{" tap" if tap_save else ""}"')
            + seg(["Gasto", "Ingreso", "Transferencia"], 0)
            + f'<div class="big2">S/ {amount}</div>'
            + group(row(name, "", icon="edit", color="#a5a6ff", chev=False),
                    row("Categoría", catname, icon=CAT[catname][0], color=CAT[catname][1]),
                    row("Cuenta", account, icon="card", color="#5b5cf0"),
                    row("Fecha", "Hoy", icon="calendar", color="#64748b"))
            + extra)


def planif_tab(seg_active=0, body="", guide=True):
    g = ""
    if guide:
        g = notice("Ponle límite a tus gastos", "Un presupuesto es el máximo que quieres gastar en algo. Ejemplo: No gastar más de 500 en comida este mes.")
    return (nav_title("Planificación") + chips(["Presupuestos", "Pagos planificados"], selected=(["Presupuestos", "Pagos planificados"][seg_active],))
            + g + body + tabbar("Planificación"))


def presupuesto_hoy(step=1):
    return (sheet_top("Nuevo presupuesto") + sh_sec("Información básica")
            + group(row("Nombre del presupuesto", "", chev=False), f'<div class="lrow" style="justify-content:flex-end;font-size:20px;font-weight:600;color:rgba(255,255,255,.4)">0.00</div>')
            + sh_sec("¿Qué gastos cuenta?") + chips(["Todos mis gastos", "Elegir categorías"], selected=("Todos mis gastos",))
            + sh_sec("Período") + seg(["Semanal", "Mensual", "Anual", "Único"], 1)
            + toggle_row("Activo", True) + toggle_row("Mostrar en el widget", False, "Sale en el widget de Presupuestos del Panel")
            + sh_sec("Alertas") + toggle_row("Notificar al alcanzar límite", False))
