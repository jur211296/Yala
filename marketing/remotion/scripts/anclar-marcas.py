#!/usr/bin/env python3
"""Pasa las marcas del test (reloj del Mac) a segundos del vídeo de simctl.

    anclar-marcas.py <crudo.mp4> <marcas.tsv> <carpeta-capturas> <salida.tsv>

Por qué existe: la marca la imprime el test cuando su `waitForExistence` ve el
estado, y eso llega entre 0,4 y 2,3 s DESPUÉS de que el estado se vea en pantalla
(medido el 2026-10-13 con DemoIAPizza). Para montar, lo que vale es el primer
fotograma en que se ve, no cuándo lo notó el test.

Ojo con ffmpeg: el H.264 de simctl trae DTS que no casan con los PTS y ffmpeg 8.1
los usa para reordenar, así que sin `-fflags +igndts` los fotogramas salen hasta
4 s antes de su sitio. ffprobe lee bien los PTS; aquí se decodifica con igndts.

Cómo ancla: cada marca tiene su captura (simctl screenshot, sacada al leer la
línea). Si el estado de esa marca se queda quieto en pantalla (la marca siguiente
llega ≥ 1,5 s después y la captura casa con ≥ 0,8 s seguidos de vídeo), su
segundo es el PRIMER fotograma que casa con la captura. Las demás marcas —las
de transición, como «escribiendo» o «enviado», y la última— se ponen a partir
del ancla más cercana sumando la diferencia de reloj, que en tramos cortos sí vale.

Salida: TSV `marca  seg_video  origen` (origen = ancla | reloj).
Necesita numpy y ffmpeg/ffprobe. Sin numpy, sale con código 3 y el script
llamante se queda con las marcas por reloj.
"""
import subprocess
import sys

try:
    import numpy as np
except ImportError:
    sys.stderr.write("anclar-marcas: sin numpy, no se ancla\n")
    sys.exit(3)

W, H = 60, 130          # miniatura en gris: basta para distinguir pantallas
HUECO_MIN = 1.5         # s hasta la marca siguiente para considerar el estado quieto
QUIETO_MIN = 0.8        # s seguidos de vídeo que deben casar con la captura


def gris(args):
    out = subprocess.run(
        ["ffmpeg", "-v", "error"] + args
        + ["-vf", f"scale={W}:{H},format=gray", "-fps_mode", "passthrough", "-f", "rawvideo", "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(out, dtype=np.uint8).reshape(-1, H, W).astype(np.int16)


def main():
    crudo, tsv, capturas, salida = sys.argv[1:5]
    pts = [
        float(x.split(",")[0])
        for x in subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "frame=pts_time",
             "-of", "csv=p=0", crudo],
            capture_output=True, text=True, check=True,
        ).stdout.split()
        if x.split(",")[0] not in ("", "N/A")
    ]
    fotogramas = gris(["-fflags", "+igndts", "-i", crudo])
    n = min(len(pts), len(fotogramas))
    pts, fotogramas = np.array(pts[:n]), fotogramas[:n]

    marcas = [linea.rstrip("\n").split("\t") for linea in open(tsv) if linea.strip()]
    marcas = [(m, float(s)) for m, s in marcas]

    anclas = {}
    desde = 0
    for i, (marca, reloj) in enumerate(marcas):
        hueco = marcas[i + 1][1] - reloj if i + 1 < len(marcas) else 0
        if hueco < HUECO_MIN:
            continue
        try:
            ref = gris(["-i", f"{capturas}/{marca}.png"])[0]
        except subprocess.CalledProcessError:
            continue
        dif = np.abs(fotogramas[desde:] - ref).mean(axis=(1, 2))
        umbral = dif.min() * 1.5 + 1.0
        candidatos = np.nonzero(dif <= umbral)[0]
        if len(candidatos) == 0:
            continue
        primero = candidatos[0]
        ultimo = primero
        while ultimo + 1 < len(dif) and dif[ultimo + 1] <= umbral:
            ultimo += 1
        fin_tramo = pts[desde + ultimo + 1] if desde + ultimo + 1 < n else pts[-1]
        if fin_tramo - pts[desde + primero] < QUIETO_MIN:
            continue
        anclas[marca] = float(pts[desde + primero])
        desde += primero

    with open(salida, "w") as f:
        for marca, reloj in marcas:
            if marca in anclas:
                f.write(f"{marca}\t{anclas[marca]:.3f}\tancla\n")
                continue
            if not anclas:
                f.write(f"{marca}\t{reloj:.3f}\treloj\n")
                continue
            cercana = min(anclas, key=lambda a: abs(dict(marcas)[a] - reloj))
            seg = anclas[cercana] + (reloj - dict(marcas)[cercana])
            f.write(f"{marca}\t{max(0.0, seg):.3f}\treloj\n")


if __name__ == "__main__":
    main()
