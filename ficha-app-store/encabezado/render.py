#!/usr/bin/env python3
"""Encabezado en vídeo de la ficha (iOS 27): 21:9 para la página de producto y 3:2 para los resultados de búsqueda.

Uso: python3 encabezado/render.py <idioma>

Una sola idea: le dices un gasto a Yala IA y queda anotado. Sin texto encima: el logo y un iPhone que corre la toma
real `ia` del molde (<salida>/<idioma>/video/tomas/ia.mp4, de video/grabar.sh). El tramo sale de las marcas de esa
toma: desde poco antes del toque en enviar hasta que la tarjeta del registro lleva unos segundos en pantalla.

El loop no tiene corte: el fondo es quieto y la pantalla se funde de la tarjeta a la bienvenida en 0,8 s, usando el
principio del tramo. El archivo empieza con la tarjeta ya puesta, que es su portada, y su último fotograma es el
anterior al primero.

Deja en <salida>/<idioma>/encabezado/:
  yala-encabezado-21x9-3840x1646.mp4   página de producto · 30 fps · H.264 · sin audio
  yala-encabezado-3x2-3840x2560.mp4    resultados de búsqueda · ídem
  _revision/  el fotograma de portada de cada uno, y una copia con la zona segura de Apple marcada (no se suben)
"""
import json, os, pathlib, subprocess, sys, tempfile
from PIL import Image, ImageDraw

MOLDE = pathlib.Path(__file__).resolve().parent.parent
IDIOMA = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)
BASE = pathlib.Path(os.environ.get("YALA_FICHA_SALIDA", pathlib.Path.home() / "Claude/propuestas/ficha-app-store-2.2")) / IDIOMA
TOMA = BASE / "video/tomas/ia.mp4"
OUT = BASE / "encabezado"
REV = OUT / "_revision"
REV.mkdir(parents=True, exist_ok=True)
# Chrome del sistema o, si no está (la Mini el 4-nov-2026), el Chrome for Testing de Playwright. YALA_FICHA_CHROME manda.
CHROME = next((c for c in [os.environ.get("YALA_FICHA_CHROME"), "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
               *sorted(pathlib.Path.home().glob("Library/Caches/ms-playwright/chromium-*/chrome-mac-arm64/"
                       "Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"), reverse=True)]
               if c and pathlib.Path(c).exists()), None) or sys.exit("✗ no encuentro Chrome: pon YALA_FICHA_CHROME")

ANTES, DESPUES, FUNDIDO, FPS = 1.6, 7.6, 0.8, 30   # segundos alrededor del envío; el vídeo dura 8,4 s
K = ANTES + 2.4   # segundo del tramo en que la tarjeta ya está quieta: ahí empieza el archivo

# Zonas seguras: capa «Art Safe Area» de las plantillas oficiales de Apple (medidas el 13-oct-2026, ver la ficha 2.1).
# tel = alto del teléfono entero; logo = ancho; hueco = entre el logo y el teléfono.
FORMATOS = {
    "21x9": {"W": 3840, "H": 1646, "seguro": (1097, 493, 1646, 661), "tel": 2000, "logo": 540, "hueco": 150},
    "3x2":  {"W": 3840, "H": 2560, "seguro": (836, 765, 2168, 1030), "tel": 2700, "logo": 760, "hueco": 230},
}
# La burbuja y la tarjeta viven entre el 22 % y el 54 % del alto de la pantalla (medido en la toma en): ese tramo se
# centra en la zona segura.
FOCO = 0.38


def run(*a, **k):
    return subprocess.run(a, check=True, **k)


def ffmpeg(*a):
    run("ffmpeg", "-v", "error", "-y", *a)


def envio_visible(marca):
    """Segundo en que la bienvenida deja paso a la burbuja. La marca chat_send de grabar.sh no basta: llega hasta 0,6 s
    después del cambio (medido el 4-nov-2026 en es) y con ella la bienvenida casi no se veía. Se busca el primer
    fotograma que se aparta mucho del de 2,5 s antes de la marca."""
    import numpy as np
    desde, w, h = marca - 2.5, 40, 87
    crudo = run("ffmpeg", "-v", "error", "-ss", str(desde), "-t", "3.5", "-i", str(TOMA), "-vf",
                f"fps={FPS},scale={w}:{h},format=gray", "-f", "rawvideo", "-", capture_output=True).stdout
    f = np.frombuffer(crudo, np.uint8).reshape(-1, h, w).astype(float)
    dif = np.abs(f - f[0]).mean(axis=(1, 2))
    i = next((i for i, d in enumerate(dif) if d > 12), None)
    return marca if i is None else round(desde + i / FPS, 3)


def tramo():
    """[desde, hasta] de la toma: alrededor del envío del mensaje."""
    if not TOMA.exists():
        sys.exit(f"✗ falta {TOMA} (video/grabar.sh {IDIOMA} ia)")
    marcas = json.loads(TOMA.with_suffix(".marcas.json").read_text())
    marca = next(m["t"] for m in marcas if m.get("que") == "chat_send")
    envio = envio_visible(marca)
    print(f"· envío: marca {marca:.2f} s, visible {envio:.2f} s")
    dur = float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(TOMA),
                    capture_output=True, text=True).stdout)
    a, b = envio - ANTES, envio + DESPUES
    if b > dur:
        sys.exit(f"✗ la toma acaba en {dur:.1f} s y el tramo pide hasta {b:.1f} s")
    return round(a, 3), round(b, 3)


def geometria(f):
    W, H, (sx, sy, sw, sh), th = f["W"], f["H"], f["seguro"], f["tel"]
    pw = th * 0.4773                     # ancho del teléfono entero (lamina.css: .phone)
    w = pw / 1.072                       # --w de lamina.css
    pant_x, pant_w = pw * 0.034, pw * (1 - 2 * 0.034)
    pant_y, pant_h = th * 0.016, th * (1 - 2 * 0.016)
    ty = sy + sh / 2 - pant_y - FOCO * pant_h
    grupo = f["logo"] + f["hueco"] + pw
    lx = W / 2 - grupo / 2
    tx = lx + f["logo"] + f["hueco"]
    ly = sy + sh / 2 - f["logo"] * 620 / 820 / 2
    return {"tel": (round(tx), round(ty), th), "logo": (round(lx), round(ly), f["logo"]),
            "pantalla": (round(tx + pant_x), round(ty + pant_y), round(pant_w), round(pant_h)), "radio": w * 0.135}


def fondo(f, g, destino, guia=False):
    url = (f"file://{MOLDE}/encabezado/encabezado.html?W={f['W']}&H={f['H']}&tel={','.join(map(str, g['tel']))}"
           f"&logo={','.join(map(str, g['logo']))}&seguro={','.join(map(str, f['seguro']))}" + ("&guia=1" if guia else ""))
    run(CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
        "--allow-file-access-from-files", "--virtual-time-budget=4000", f"--window-size={f['W']},{f['H']}",
        f"--screenshot={destino}", url, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    Image.open(destino).convert("RGB").save(destino)


def mascara(g, destino):
    _, _, w, h = g["pantalla"]
    im = Image.new("L", (w * 4, h * 4), 0)
    ImageDraw.Draw(im).rounded_rectangle((0, 0, w * 4 - 1, h * 4 - 1), radius=g["radio"] * 4, fill=255)
    im.resize((w, h), Image.LANCZOS).save(destino)


def main():
    a, b = tramo()
    D = b - a
    L = D - FUNDIDO
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        # Pista de pantalla en loop, que arranca con la tarjeta ya puesta (el primer fotograma es la portada que enseña
        # Apple): [tarjeta … final][fundido final→principio][principio … llegada de la tarjeta]. Dura D - FUNDIDO.
        loop = tmp / "pantalla.mp4"
        ffmpeg("-ss", str(a), "-t", str(D), "-i", str(TOMA), "-filter_complex",
               f"[0:v]fps={FPS},setpts=PTS-STARTPTS,split=3[c1][c2][c3];"
               f"[c1]trim={D - FUNDIDO}:{D},setpts=PTS-STARTPTS[cola];"
               f"[c2]trim=0:{FUNDIDO},setpts=PTS-STARTPTS[cabeza];"
               f"[c3]trim={FUNDIDO}:{D - FUNDIDO},setpts=PTS-STARTPTS,split=2[r1][r2];"
               f"[r1]trim={K - FUNDIDO}:{D - 2 * FUNDIDO},setpts=PTS-STARTPTS[tarjeta];"
               f"[r2]trim=0:{K - FUNDIDO},setpts=PTS-STARTPTS[llegada];"
               f"[cola][cabeza]xfade=transition=fade:duration={FUNDIDO}:offset=0[cosido];"
               f"[tarjeta][cosido][llegada]concat=n=3:v=1:a=0,format=yuv420p[o]",
               "-map", "[o]", "-c:v", "libx264", "-crf", "10", "-g", str(FPS), str(loop))
        for nombre, f in FORMATOS.items():
            g = geometria(f)
            fon, mas = tmp / f"fondo-{nombre}.png", tmp / f"mascara-{nombre}.png"
            fondo(f, g, fon)
            fondo(f, g, REV / f"guia-{nombre}.png", guia=True)
            mascara(g, mas)
            px, py, pw, ph = g["pantalla"]
            out = OUT / f"yala-encabezado-{nombre}-{f['W']}x{f['H']}.mp4"
            ffmpeg("-loop", "1", "-framerate", str(FPS), "-t", f"{L:.3f}", "-i", str(fon),
                   "-i", str(loop), "-loop", "1", "-framerate", str(FPS), "-t", f"{L:.3f}", "-i", str(mas),
                   "-filter_complex",
                   f"[1:v]scale={pw}:{ph}:flags=lanczos,format=yuva420p[p];[2:v]format=gray[m];"
                   f"[p][m]alphamerge[pm];[0:v][pm]overlay={px}:{py}:shortest=1,fps={FPS},format=yuv420p[o]",
                   "-map", "[o]", "-an", "-t", f"{L:.3f}", "-c:v", "libx264", "-profile:v", "high", "-level:v", "5.2",
                   "-preset", "slow", "-crf", "14", "-maxrate", "60M", "-bufsize", "120M", "-g", str(FPS),
                   "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
                   "-movflags", "+faststart", str(out))
            # El primer fotograma (la portada que enseña Apple) y el de la bienvenida, justo antes del envío.
            ffmpeg("-i", str(out), "-frames:v", "1", str(REV / f"fotograma-{nombre}-portada.png"))
            ffmpeg("-ss", f"{D - K + 0.4:.2f}", "-i", str(out), "-frames:v", "1", str(REV / f"fotograma-{nombre}-bienvenida.png"))
            info = run("ffprobe", "-v", "error", "-select_streams", "v", "-show_entries",
                       "stream=width,height,r_frame_rate,codec_name,profile", "-show_entries", "format=duration,size",
                       "-of", "csv=p=0", str(out), capture_output=True, text=True).stdout.split()
            print(f"✓ {out.name} · {' '.join(info)}")


main()
