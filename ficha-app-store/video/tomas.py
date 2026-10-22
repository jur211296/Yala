#!/usr/bin/env python3
"""Monta la pista de pantalla del vídeo de un idioma y escribe su config.js.

Uso: python3 video/tomas.py <idioma>

Cada escena (IA → foto → voz → Grupos) es un tramo continuo de una grabación real del simulador
(<salida>/<idioma>/video/tomas/<escena>.mp4, de video/grabar.sh), acelerado solo en las esperas, sin cortes dentro de
la escena. Los tramos [desde, hasta, velocidad] de cada idioma están en video/cortes/<idioma>.json: se miden sobre la
grabación de ese idioma, porque cada una tiene sus esperas. Los toques que se pintan encima salen de las marcas que
grabar.sh apunta al tocar (<escena>.marcas.json), o de "toques" en los cortes si se midieron a mano, pasados al tiempo
del vídeo; los que caen fuera de los tramos no salen.

Deja en <salida>/<idioma>/video/_build/: assets/pantalla.mp4 (una sola pista, con fundidos de 0,4 s, que es lo que
HyperFrames renderiza bien) y config.js (las frases de textos/<idioma>.js → VIDEO, las escenas y los toques).
"""
import json, os, pathlib, subprocess, sys

MOLDE = pathlib.Path(__file__).resolve().parent.parent
IDIOMA = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)
SALIDA = pathlib.Path(os.environ.get("YALA_FICHA_SALIDA", pathlib.Path.home() / "Claude/propuestas/ficha-app-store-2.1")) / IDIOMA / "video"
TOMAS = SALIDA / "tomas"
BUILD = SALIDA / "_build"
A = BUILD / "assets"
A.mkdir(parents=True, exist_ok=True)

CORTES = json.loads((MOLDE / "video/cortes" / f"{IDIOMA}.json").read_text())
ESCENAS = ["ia", "foto", "voz", "grupos"]
FUNDIDO, COLA = 0.4, 1.0          # fundido entre escenas y cola congelada al final de cada una
PANTALLA_PT = CORTES.get("pantallaPuntos", [402, 874])   # iPhone 17 Pro, para pasar los toques a %


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def tramos_de(escena):
    return CORTES["escenas"][escena]["tramos"]


# 1 · Cada escena: sus tramos encadenados, a 30 fps, con un segundo de cola congelada para el fundido.
duraciones = {}
for k in ESCENAS:
    tr = tramos_de(k)
    src = TOMAS / f"{k}.mp4"
    if not src.exists():
        sys.exit(f"✗ falta la toma {src} (video/grabar.sh {IDIOMA} {k})")
    f = "".join(f"[0:v]trim={a}:{b},setpts=(PTS-STARTPTS)/{v}[s{i}];" for i, (a, b, v) in enumerate(tr))
    f += "".join(f"[s{i}]" for i in range(len(tr))) + \
        f"concat=n={len(tr)}:v=1:a=0,fps=30,tpad=stop_mode=clone:stop_duration={COLA}[o]"
    ffmpeg("-i", str(src), "-filter_complex", f, "-map", "[o]", "-c:v", "libx264", "-crf", "14", "-g", "30",
           "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(A / f"{k}.mp4"))
    duraciones[k] = sum((b - a) / v for a, b, v in tr)
    print(f"✓ {k}: {duraciones[k]:.2f} s (+{COLA:.0f} s de cola)")

# 2 · Dónde empieza cada escena: el fundido a la siguiente arranca 0,3 s antes de que acabe el movimiento de la anterior.
inicio, escenas = 0.0, []
for i, k in enumerate(ESCENAS):
    fin = inicio + duraciones[k] - (0.3 if i < len(ESCENAS) - 1 else 0)
    escenas.append({"id": k, "inicio": round(inicio, 3), "fin": round(fin, 3)})
    inicio = fin
fin_pantalla = escenas[-1]["fin"]

# 3 · Una sola pista: IA → foto → voz → Grupos con fundidos.
entradas = sum((["-i", str(A / f"{k}.mp4")] for k in ESCENAS), [])
cadena, previo = [], "0:v"
for i in range(1, len(ESCENAS)):
    salida = "o" if i == len(ESCENAS) - 1 else f"x{i}"
    cadena.append(f"[{previo}][{i}:v]xfade=transition=fade:duration={FUNDIDO}:offset={escenas[i]['inicio']}"
                  + (",fps=30,format=yuv420p" if salida == "o" else "") + f"[{salida}]")
    previo = salida
ffmpeg(*entradas, "-filter_complex", ";".join(cadena), "-map", "[o]", "-c:v", "libx264", "-crf", "14", "-g", "30",
       "-movflags", "+faststart", str(A / "pantalla.mp4"))
pantalla = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                 str(A / "pantalla.mp4")], capture_output=True, text=True, check=True).stdout)
print(f"✓ pantalla.mp4 ({pantalla:.2f} s): " + " → ".join(f"{e['id']} {e['inicio']:.2f}" for e in escenas))

# 4 · Toques: las marcas de grabar.sh, del reloj de la grabación al del vídeo.
toques = []
for e in escenas:
    # Los toques medidos a mano sobre la grabación (cortes) mandan sobre las marcas de grabar.sh.
    fijos = CORTES["escenas"][e["id"]].get("toques")
    marcas = TOMAS / f"{e['id']}.marcas.json"
    if fijos is None and not marcas.exists():
        continue
    lista = [dict(m, tipo="toque") for m in fijos] if fijos is not None else json.loads(marcas.read_text())
    omitir = set(CORTES["escenas"][e["id"]].get("omitirToques", []))
    for n, m in enumerate(lista):
        if m.get("tipo") != "toque" or n in omitir:
            continue
        acumulado = 0.0
        for a, b, v in tramos_de(e["id"]):
            if a <= m["t"] <= b:
                toques.append({"t": round(e["inicio"] + acumulado + (m["t"] - a) / v, 3),
                               "x": round(m["x"] / PANTALLA_PT[0] * 100, 2), "y": round(m["y"] / PANTALLA_PT[1] * 100, 2)})
                break
            acumulado += (b - a) / v
print(f"✓ {len(toques)} toques")

video = json.loads(subprocess.run(["node", "-e", f"process.stdout.write(JSON.stringify(require({json.dumps(str(MOLDE / 'textos' / (IDIOMA + '.js')))}).VIDEO))"],
                                  capture_output=True, text=True, check=True).stdout)
config = {"video": video, "escenas": escenas, "toques": toques, "pantallaDuracion": round(pantalla, 3),
          "fin": round(fin_pantalla + 2.7, 3)}
(BUILD / "config.js").write_text("window.CONFIG = " + json.dumps(config, ensure_ascii=False, indent=1) + ";\n")
print(f"✓ config.js · vídeo de {config['fin']:.2f} s")
