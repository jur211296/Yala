"""Los cinco Yalittos en SVG propio: cuerpos, caras, detalles y estados animados.

Todo sale de aquí: láminas, maquetas, storyboard y prototipos. Cada SVG lleva un `uid`
propio porque todos conviven en una sola página HTML y los degradados se nombran por id.

Sistema de piezas (igual en las cinco direcciones, para que se puedan comparar):
  g.y-all   → todo el personaje (saltos, inclinaciones) · origen abajo al centro
  g.y-body  → el cuerpo (respirar, aplastarse)
  g.f-<expr>→ una cara por expresión; la animación enciende y apaga caras
  g.eyes    → dentro de cada cara, para el parpadeo
"""
import math

INK = "#17151f"


# ---------------------------------------------------------------- utilidades

def _f(x):
    s = f"{x:.1f}"
    return s[:-2] if s.endswith(".0") else s


def smooth_closed(pts, k=1.0):
    """Curva cerrada suave que pasa por los puntos (Catmull-Rom → Bézier)."""
    n = len(pts)
    d = f"M{_f(pts[0][0])} {_f(pts[0][1])}"
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6 * k, p1[1] + (p2[1] - p0[1]) / 6 * k)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6 * k, p2[1] - (p3[1] - p1[1]) / 6 * k)
        d += f" C{_f(c1[0])} {_f(c1[1])} {_f(c2[0])} {_f(c2[1])} {_f(p2[0])} {_f(p2[1])}"
    return d + "Z"


def radial_blob(radii, cx=100, cy=114, floor=178):
    n = len(radii)
    pts = []
    for i, r in enumerate(radii):
        a = -math.pi / 2 + 2 * math.pi * i / n
        pts.append((cx + r * math.cos(a), min(cy + r * math.sin(a), floor)))
    return smooth_closed(pts)


def mix(hex1, hex2, t):
    a = [int(hex1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(hex2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(a, b))


# ---------------------------------------------------------------- caras

# expresión → (ojos, boca, cejas)
EXPR = {
    "reposo":   ("open", "small", None),
    "feliz":    ("happy", "smile", None),
    "curioso":  ("wide", "o", "curioso"),
    "pensando": ("lookup", "side", "pensando"),
    "mira":     ("lookright", "small", None),
    "uy":       ("open", "wavy", "uy"),
    "sereno":   ("calm", "flat", "sereno"),
    "dormido":  ("closed", "small", None),
}
EXPR_NOMBRE = {
    "reposo": "Reposo", "feliz": "Contento", "curioso": "Curioso", "pensando": "Pensando",
    "mira": "Atento", "uy": "«Uy»", "sereno": "Sereno", "dormido": "En pausa",
}


def _eye(kind, x, y, w, h, style, col):
    sw = 5.4 if style == "line" else 4.2
    if kind == "happy":
        return (f'<path d="M{_f(x - w * .62)} {_f(y + 3)} Q{_f(x)} {_f(y - h * .62)} {_f(x + w * .62)} {_f(y + 3)}" '
                f'fill="none" stroke="{col}" stroke-width="{sw}" stroke-linecap="round"/>')
    if kind == "closed":
        return (f'<path d="M{_f(x - w * .6)} {_f(y)} Q{_f(x)} {_f(y + h * .38)} {_f(x + w * .6)} {_f(y)}" '
                f'fill="none" stroke="{col}" stroke-width="{sw}" stroke-linecap="round"/>')
    dx = dy = 0
    if kind == "lookup":
        dx, dy = -2.5, -3
    if kind == "lookright":
        dx, dy = 3.5, 1.5
    hh = h * (1.14 if kind == "wide" else .72 if kind == "calm" else 1.0)
    if style == "line":
        top, bot = y - hh * .42 + dy, y + hh * .42 + dy
        if kind == "half":
            top = y - hh * .02
        return (f'<path d="M{_f(x + dx)} {_f(top)} L{_f(x + dx)} {_f(bot)}" stroke="{col}" '
                f'stroke-width="{sw + 1}" stroke-linecap="round"/>')
    if style == "led":
        rh = hh if kind != "half" else hh * .45
        yy = y + dy + (hh * .25 if kind == "half" else 0)
        return (f'<rect x="{_f(x + dx - w / 2)}" y="{_f(yy - rh / 2)}" width="{_f(w)}" height="{_f(rh)}" '
                f'rx="{_f(min(w, rh) / 2)}" fill="{col}"/>')
    if kind == "half":
        return (f'<path d="M{_f(x - w / 2)} {_f(y)} A{_f(w / 2)} {_f(hh / 2)} 0 0 0 {_f(x + w / 2)} {_f(y)} Z" fill="{col}"/>'
                f'<path d="M{_f(x - w * .66)} {_f(y - .5)} L{_f(x + w * .66)} {_f(y - .5)}" stroke="{col}" stroke-width="3.2" stroke-linecap="round"/>')
    hl = f'<circle cx="{_f(x + dx - w * .14)}" cy="{_f(y + dy - hh * .2)}" r="{_f(max(1.6, w * .17))}" fill="#fff" opacity=".9"/>'
    if style == "pill":
        return (f'<rect x="{_f(x + dx - w / 2)}" y="{_f(y + dy - hh / 2)}" width="{_f(w)}" height="{_f(hh)}" rx="{_f(w / 2)}" fill="{col}"/>' + hl)
    return f'<ellipse cx="{_f(x + dx)}" cy="{_f(y + dy)}" rx="{_f(w / 2)}" ry="{_f(hh / 2)}" fill="{col}"/>' + hl


def _mouth(kind, x, y, s, col, style):
    sw = 5 if style == "line" else 3.6
    p = {
        "small": f"M{_f(-6 * s)} 0 Q0 {_f(5 * s)} {_f(6 * s)} 0",
        "smile": f"M{_f(-10 * s)} -1 Q0 {_f(10 * s)} {_f(10 * s)} -1",
        "flat": f"M{_f(-6 * s)} 1 L{_f(6 * s)} 1",
        "wavy": f"M{_f(-9 * s)} 2 Q{_f(-4.5 * s)} {_f(-2 * s)} 0 2 Q{_f(4.5 * s)} {_f(6 * s)} {_f(9 * s)} 2",
        "side": f"M{_f(-3 * s)} 2 Q{_f(3 * s)} {_f(4 * s)} {_f(8 * s)} -1",
    }
    if kind == "o":
        return f'<ellipse cx="{_f(x)}" cy="{_f(y + 2)}" rx="{_f(3.4 * s)}" ry="{_f(4.2 * s)}" fill="{col}"/>'
    return (f'<path transform="translate({_f(x)} {_f(y)})" d="{p[kind]}" fill="none" stroke="{col}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>')


def _brows(kind, cx, y, gap, col):
    if not kind:
        return ""
    l, r = cx - gap / 2, cx + gap / 2
    segs = {
        "curioso": [(l - 6, y + 1, l + 5, y), (r - 5, y - 5, r + 6, y - 8)],
        "pensando": [(l - 6, y - 4, l + 5, y - 2), (r - 5, y + 1, r + 6, y + 1)],
        "uy": [(l - 6, y + 2, l + 5, y - 3), (r - 5, y - 3, r + 6, y + 2)],
        "sereno": [(l - 6, y + 1, l + 5, y + 1), (r - 5, y + 1, r + 6, y + 1)],
    }[kind]
    return "".join(f'<path d="M{_f(a)} {_f(b)} L{_f(c)} {_f(d)}" stroke="{col}" stroke-width="3.4" stroke-linecap="round"/>'
                   for a, b, c, d in segs)


def face(expr, cx, cy, gap, w, h, style, col, mouth_dy=24, ms=1.0, brow_dy=22, show=False):
    eyes, mouth, brows = EXPR[expr]
    e = _eye(eyes, cx - gap / 2, cy, w, h, style, col) + _eye(eyes, cx + gap / 2, cy, w, h, style, col)
    cls = f"f f-{expr}" + (" main" if show else "")
    return (f'<g class="{cls}"><g class="eyes">{e}</g>{_brows(brows, cx, cy - brow_dy, gap, col)}'
            f'{_mouth(mouth, cx, cy + mouth_dy, ms, col, style)}</g>')


# ---------------------------------------------------------------- detalles

DETALLES = ["ninguno", "antena", "gorro", "auriculares", "brillo"]


def accessory(kind, top, col, cx=100, width=60):
    if kind == "antena":
        return (f'<path d="M{cx} {top + 4} Q{cx + 4} {top - 12} {cx + 10} {top - 20}" fill="none" stroke="{col}" stroke-width="4" stroke-linecap="round"/>'
                f'<circle cx="{cx + 11}" cy="{top - 22}" r="6" fill="{col}"/>')
    if kind == "gorro":
        w = width
        return (f'<path d="M{cx - w / 2} {top + 16} Q{cx - w / 2 + 4} {top - 20} {cx} {top - 22} Q{cx + w / 2 - 4} {top - 20} {cx + w / 2} {top + 16} Z" fill="{col}"/>'
                f'<rect x="{cx - w / 2 - 4}" y="{top + 8}" width="{w + 8}" height="12" rx="6" fill="{mix(col, "#000000", .25)}"/>'
                f'<circle cx="{cx}" cy="{top - 24}" r="7" fill="{mix(col, "#ffffff", .35)}"/>')
    if kind == "auriculares":
        w = width + 34
        return (f'<path d="M{cx - w / 2} {top + 34} Q{cx - w / 2} {top - 14} {cx} {top - 14} Q{cx + w / 2} {top - 14} {cx + w / 2} {top + 34}" fill="none" stroke="{col}" stroke-width="6" stroke-linecap="round"/>'
                f'<rect x="{cx - w / 2 - 9}" y="{top + 24}" width="16" height="28" rx="8" fill="{col}"/>'
                f'<rect x="{cx + w / 2 - 7}" y="{top + 24}" width="16" height="28" rx="8" fill="{col}"/>')
    if kind == "brillo":
        return f'<path d="M{cx + 40} {top - 4} l3 8 8 3 -8 3 -3 8 -3 -8 -8 -3 8 -3z" fill="{col}"/>'
    return ""


# ---------------------------------------------------------------- las cinco direcciones

PALETAS = {
    # acentos de Yala (Yala/App/Views/Shared/UIHelpers.swift) y tonos de apoyo; la cara oscura contrasta con todos
    "indigo": "#6063F1", "rosa": "#FF4FA8", "turquesa": "#00C2CB", "ambar": "#F59E0B",
    "coral": "#FB7185", "lima": "#9BD35A", "lila": "#B39DFA", "grafito": "#8A8FA3",
}
PAPEL = {"crema": "#F4EBD9", "menta": "#D7F2E4", "lila": "#E6E0FB", "celeste": "#D9ECFB", "rosa": "#FBE1EC"}

GOTA_MOLDES = {
    "gota":     [72, 60, 60, 64, 64, 64, 64, 64, 60, 60],
    "burbuja":  [62] * 10,
    "piedra":   [54, 60, 68, 66, 62, 64, 70, 62, 58, 54],
    "nube":     [58, 68, 56, 68, 58, 64, 58, 68, 56, 68],
    "estrella": [70, 50, 68, 52, 64, 54, 64, 52, 68, 50],
}
FORMAS = {
    "gota": list(GOTA_MOLDES),
    "ficha": ["cuadrada", "alta", "circulo", "hexagono"],
    "trazo": ["lazo", "onda", "rizo", "barra"],
    "boleta": ["boleta", "sobre", "ticket", "doblada"],
    "bit": ["capsula", "domo", "cubo"],
}
COLORES = {
    "gota": ["indigo", "rosa", "turquesa", "ambar", "coral", "lima", "lila", "grafito"],
    "ficha": ["indigo", "rosa", "turquesa", "ambar", "coral", "lima", "lila", "grafito"],
    "trazo": ["turquesa", "indigo", "rosa", "ambar", "lima", "lila"],
    "boleta": list(PAPEL),
    "bit": ["indigo", "rosa", "turquesa", "ambar", "lima", "lila"],
}
DIRECCIONES = [
    ("gota", "A · Gota", "Una gota blanda que cambia de molde"),
    ("ficha", "B · Ficha", "Una ficha de vidrio: un icono con cara"),
    ("trazo", "C · Trazo", "Una sola línea que dibuja una cara y se vuelve gráfica"),
    ("boleta", "D · Boleta", "Un papelito que se dobla en lo que hace falta"),
    ("bit", "E · Bit", "Un pequeño bot con visor, como los de las apps de IA"),
]
DEFAULT_COLOR = {"gota": "indigo", "ficha": "indigo", "trazo": "turquesa", "boleta": "crema", "bit": "indigo"}


def body_gota(uid, color, forma="gota"):
    c = PALETAS.get(color, color)
    defs = (f'<radialGradient id="g{uid}" cx="38%" cy="30%" r="80%">'
            f'<stop offset="0" stop-color="{mix(c, "#ffffff", .4)}"/><stop offset=".55" stop-color="{c}"/>'
            f'<stop offset="1" stop-color="{mix(c, "#000000", .28)}"/></radialGradient>')
    radii = GOTA_MOLDES[forma]
    body = (f'<path d="{radial_blob(radii)}" fill="url(#g{uid})"/>'
            f'<ellipse cx="76" cy="80" rx="13" ry="8" fill="#fff" opacity=".42" transform="rotate(-28 76 80)"/>')
    return defs, body, dict(cx=100, cy=112, gap=36, w=15, h=21, style="solid", col=INK, top=114 - radii[0])


def body_ficha(uid, color, forma="cuadrada"):
    c = PALETAS.get(color, color)
    defs = (f'<linearGradient id="g{uid}" x1="0" y1="0" x2=".9" y2="1">'
            f'<stop offset="0" stop-color="{mix(c, "#ffffff", .45)}"/><stop offset=".5" stop-color="{c}"/>'
            f'<stop offset="1" stop-color="{mix(c, "#000000", .3)}"/></linearGradient>')
    rim = 'fill="none" stroke="#fff" stroke-opacity=".55" stroke-width="2.5"'
    if forma == "alta":
        geo, top = 'x="58" y="34" width="84" height="144" rx="34"', 34
        body = f'<rect {geo} fill="url(#g{uid})"/><rect {geo} {rim}/>'
    elif forma == "circulo":
        body, top = f'<circle cx="100" cy="112" r="66" fill="url(#g{uid})"/><circle cx="100" cy="112" r="66" {rim}/>', 46
    elif forma == "hexagono":
        body, top = (f'<polygon points="100,54 150,83 150,145 100,174 50,145 50,83" fill="url(#g{uid})" stroke="url(#g{uid})" '
                     f'stroke-width="22" stroke-linejoin="round"/>'), 44
    else:
        geo, top = 'x="40" y="50" width="120" height="128" rx="38"', 50
        body = f'<rect {geo} fill="url(#g{uid})"/><rect {geo} {rim}/>'
    body += f'<path d="M62 {top + 22} Q70 {top + 10} 88 {top + 8}" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="5" stroke-linecap="round"/>'
    return defs, body, dict(cx=100, cy=110, gap=40, w=14, h=26, style="pill", col=INK, top=top)


TRAZO_PATHS = {
    "lazo": "M70 168 C34 146 34 70 92 56 C146 44 172 104 148 142 C130 172 84 176 64 150 C58 140 60 128 68 122",
    "onda": "M44 160 L44 86 C44 62 62 50 86 50 L114 50 C138 50 156 62 156 86 L156 150 C146 140 136 140 126 152 C116 164 106 164 98 152 C88 140 78 140 70 152 C62 164 52 166 44 160",
    "rizo": "M54 118 C54 76 82 52 112 54 C146 56 164 88 156 122 C148 156 112 174 84 164 C64 156 62 132 80 124 C96 118 108 132 100 142",
    "barra": "M36 168 L36 120 C36 76 66 54 100 54 C134 54 164 76 164 120 L164 140 L186 116",
}


def body_trazo(uid, color, forma="lazo"):
    c = PALETAS.get(color, color)
    body = (f'<path d="{TRAZO_PATHS[forma]}" fill="{c}" fill-opacity=".1" stroke="{c}" stroke-width="9" '
            f'stroke-linecap="round" stroke-linejoin="round"/>')
    return "", body, dict(cx=100, cy=104, gap=34, w=10, h=24, style="line", col=c, top=52)


def body_boleta(uid, color="crema", forma="boleta"):
    c = PAPEL.get(color, color)
    edge, line = mix(c, "#000000", .16), mix(c, "#000000", .22)
    if forma == "sobre":
        body = (f'<rect x="34" y="64" width="132" height="104" rx="12" fill="{c}" stroke="{edge}" stroke-width="2"/>'
                f'<path d="M37 70 L100 112 L163 70" fill="none" stroke="{edge}" stroke-width="3" stroke-linejoin="round"/>')
        return "", body, dict(cx=100, cy=134, gap=34, w=12, h=16, style="solid", col=INK, top=64, mouth_dy=17, brow_dy=16)
    if forma == "ticket":
        body = (f'<path d="M30 70 H170 V96 A12 12 0 0 0 170 120 V150 H30 V120 A12 12 0 0 0 30 96 Z" fill="{c}" stroke="{edge}" stroke-width="2"/>'
                f'<path d="M136 76 V144" stroke="{line}" stroke-width="2.5" stroke-dasharray="5 6"/>')
        return "", body, dict(cx=86, cy=102, gap=32, w=12, h=16, style="solid", col=INK, top=70, mouth_dy=18, brow_dy=16)
    if forma == "doblada":
        body = (f'<path d="M54 40 L150 52 L146 176 L50 166 Z" fill="{c}" stroke="{edge}" stroke-width="2" stroke-linejoin="round"/>'
                f'<path d="M54 104 L150 114 L146 176 L50 166 Z" fill="#000" opacity=".05"/>'
                f'<path d="M52 104 L148 114" stroke="{edge}" stroke-width="2.5"/>')
        return "", body, dict(cx=100, cy=78, gap=34, w=12, h=16, style="solid", col=INK, top=42, mouth_dy=17, brow_dy=16)
    zig = "".join(f" L{_f(144 - 5.5 * (i + 1))} {176 if i % 2 == 0 else 168}" for i in range(15))
    body = (f'<path d="M56 34 H132 L144 46 V168{zig} L56 168 Z" fill="{c}" stroke="{edge}" stroke-width="2" stroke-linejoin="round"/>'
            f'<path d="M132 34 V46 H144" fill="{mix(c, "#000000", .08)}" stroke="{edge}" stroke-width="2" stroke-linejoin="round"/>'
            + "".join(f'<path d="M70 {y} H{w}" stroke="{line}" stroke-width="3" stroke-linecap="round"/>' for y, w in ((126, 130), (138, 116), (150, 124))))
    return "", body, dict(cx=100, cy=80, gap=34, w=12, h=16, style="solid", col=INK, top=34, mouth_dy=18, brow_dy=16)


def body_bit(uid, color="indigo", forma="capsula"):
    c = PALETAS.get(color, color)
    defs = (f'<linearGradient id="g{uid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/>'
            f'<stop offset="1" stop-color="#CDD2E0"/></linearGradient>')
    if forma == "domo":
        sh, top = f'<path d="M40 176 L40 112 C40 70 66 46 100 46 C134 46 160 70 160 112 L160 176 Z" fill="url(#g{uid})"/>', 46
    elif forma == "cubo":
        sh, top = f'<rect x="42" y="52" width="116" height="124" rx="24" fill="url(#g{uid})"/>', 52
    else:
        sh, top = f'<rect x="48" y="40" width="104" height="138" rx="50" fill="url(#g{uid})"/>', 40
    ears = (f'<rect x="35" y="92" width="11" height="26" rx="5.5" fill="{c}"/>'
            f'<rect x="154" y="92" width="11" height="26" rx="5.5" fill="{c}"/>')
    visor = '<rect x="58" y="72" width="84" height="58" rx="26" fill="#14142A"/>'
    chest = f'<circle cx="100" cy="154" r="5" fill="{c}"/>'
    return defs, ears + sh + visor + chest, dict(cx=100, cy=98, gap=30, w=12, h=16, style="led",
                                                  col=mix(c, "#ffffff", .4), top=top, mouth_dy=17, ms=.8, brow_dy=15)


BODIES = {"gota": body_gota, "ficha": body_ficha, "trazo": body_trazo, "boleta": body_boleta, "bit": body_bit}

_uid = [0]


def nuevo_uid():
    _uid[0] += 1
    return _uid[0]


def yalitto(direccion, expr="reposo", color=None, forma=None, detalle=None, faces=None,
            size=None, state=None, extra="", label=None, cls="", pose=None):
    """Un Yalitto en SVG. `faces` = expresiones incluidas; la primera es la visible sin animación."""
    uid = nuevo_uid()
    color = color or DEFAULT_COLOR[direccion]
    forma = forma or FORMAS[direccion][0]
    defs, body, fp = BODIES[direccion](uid, color, forma)
    faces = faces or [expr]
    fhtml = "".join(face(e, fp["cx"], fp["cy"], fp["gap"], fp["w"], fp["h"], fp["style"], fp["col"],
                         mouth_dy=fp.get("mouth_dy", 24), ms=fp.get("ms", 1.0), brow_dy=fp.get("brow_dy", 22),
                         show=(i == 0)) for i, e in enumerate(faces))
    if direccion == "bit":
        defs += (f'<filter id="glow{uid}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2" result="b"/>'
                 f'<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')
        fhtml = f'<g filter="url(#glow{uid})">{fhtml}</g>'
    if direccion in ("trazo", "bit"):
        acc_col = PALETAS.get(color, "#6063F1")
    elif direccion == "boleta":
        acc_col = "#6063F1"
    else:
        acc_col = mix(PALETAS.get(color, color), "#000000", .35)
    acc = accessory(detalle, fp["top"], acc_col) if detalle and detalle != "ninguno" else ""
    shadow = '<ellipse class="y-shadow" cx="100" cy="186" rx="46" ry="6" fill="#000" opacity=".14"/>'
    aria = f'role="img" aria-label="{label}"' if label else 'aria-hidden="true"'
    st = f" st-{state}" if state else ""
    sz = f' width="{size}" height="{size}"' if size else ""
    return (f'<svg class="yl yl-{direccion}{st} {cls}" viewBox="0 0 200 200"{sz} {aria} xmlns="http://www.w3.org/2000/svg">'
            f'<defs>{defs}</defs>{shadow}<g class="y-all"{pose_attr(pose)}><g class="y-body">{body}</g>{acc}<g class="y-face">{fhtml}</g></g>{extra}</svg>')


def pose_attr(pose):
    """Pose fija para los fotogramas del storyboard: (dy, sx, sy, grados), con origen abajo al centro."""
    if not pose:
        return ""
    dy, sx, sy, deg = pose
    return (f' transform="translate(0 {dy}) translate(100 180) rotate({deg}) scale({sx} {sy}) translate(-100 -180)"')


# ---------------------------------------------------------------- estados (prototipos)

ESTADOS = [
    # id, nombre, caras (la primera queda si no hay movimiento), cuándo, qué dice, duración
    ("reposo", "Reposo", ["reposo"], "Está a la vista y no pasa nada.",
     "Nada. Respira y parpadea; tras dos ciclos se queda quieto.", "Dos ciclos y quieto"),
    ("saludo", "Saludo", ["feliz", "reposo"], "La primera vez que aparece, o al volver tras varios días sin abrir.",
     "«Hola. Cuando registres algo, te ayudo a ordenarlo.»", "Una vez, poco más de un segundo"),
    ("util", "Primera utilidad", ["feliz", "reposo"], "Al guardar el primer registro. Esta animación sale una sola vez.",
     "«Listo, tu primer gasto quedó registrado.»", "Una vez, un segundo"),
    ("ayuda", "Ayuda", ["curioso", "reposo"], "La persona toca «?» o llega a un estado vacío.",
     "«¿Te explico qué cuenta este número?»", "Entra y espera"),
    ("pensando", "Pensando", ["pensando", "reposo"], "Yala IA prepara una respuesta.",
     "Nada: los tres puntos ya dicen que está trabajando.", "Mientras dure la espera"),
    ("error", "Error sin culpar", ["uy", "reposo"], "Falla algo que no depende de la persona: conexión o servidor.",
     "«No pudimos conectar. Reintentamos cuando vuelva la conexión.»", "Una vez, menos de un segundo"),
    ("cerca", "Presupuesto cerca", ["mira", "reposo"], "Un presupuesto llega al 90 %.",
     "«Llevas el 90 % de Comer fuera y faltan 8 días.»", "Una vez, un segundo"),
    ("pasado", "Presupuesto pasado", ["sereno", "reposo"], "Un presupuesto pasa del 100 %.",
     "«Pasaste Comer fuera por S/ 45. ¿Lo ajustamos o lo dejamos así este mes?»", "Una vez, menos de un segundo"),
]


def estado_extra(state):
    """Lo que acompaña al estado, dibujado fuera del personaje."""
    if state == "util":
        return ('<g class="x-pop"><circle cx="166" cy="42" r="19" fill="#0f7a4b"/>'
                '<path class="x-draw" d="M157 42 l6 7 12 -13" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/></g>')
    if state == "ayuda":
        return ('<g class="x-pop"><rect x="144" y="20" width="42" height="40" rx="14" fill="#fff" stroke="#d9d5ea" stroke-width="2"/>'
                '<text x="165" y="49" text-anchor="middle" font-size="24" font-weight="700" fill="#4338ca" font-family="Helvetica,Arial,sans-serif">?</text></g>')
    if state == "pensando":
        return '<g class="x-dots">' + "".join(f'<circle class="d{i}" cx="{150 + i * 13}" cy="36" r="5" fill="#8a87a8"/>' for i in range(3)) + '</g>'
    if state == "error":
        return ('<g class="x-pop"><circle cx="166" cy="40" r="20" fill="#fff" stroke="#d9d5ea" stroke-width="2"/>'
                '<path d="M155 45 q0 -9 9 -9 q3 -7 10 -4 q7 1 6 9 q5 1 4 6 z" fill="none" stroke="#56536a" stroke-width="2.6" stroke-linejoin="round"/>'
                '<path d="M152 54 L180 26" stroke="#56536a" stroke-width="2.6" stroke-linecap="round"/></g>')
    if state in ("cerca", "pasado"):
        pct = 90 if state == "cerca" else 100
        h = 120
        y = 60 + h * (1 - pct / 100)
        over = '' if state == "cerca" else '<rect class="x-over" x="178" y="44" width="12" height="18" rx="6" fill="#F59E0B"/>'
        return (f'<g class="x-bar"><rect x="178" y="60" width="12" height="{h}" rx="6" fill="#e3dfd6"/>'
                f'<rect class="x-fill" x="178" y="{_f(y)}" width="12" height="{_f(h * pct / 100)}" rx="6" fill="#6063F1"/>{over}</g>')
    if state == "saludo":
        return '<g class="x-pop"><path d="M160 30 l4 10 10 4 -10 4 -4 10 -4 -10 -10 -4 10 -4z" fill="#F59E0B"/></g>'
    return ""


def demo(direccion, state, size=None, color=None, forma=None, detalle=None, cls=""):
    faces = next(e[2] for e in ESTADOS if e[0] == state)
    return yalitto(direccion, faces=faces, state=state, color=color, forma=forma, detalle=detalle,
                   extra=estado_extra(state), size=size, cls=cls)
