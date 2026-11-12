#!/usr/bin/env python3
"""Cortes de un idioma a partir de los de otro, anclados en las marcas de las tomas.

    python3 video/cortes_desde_marcas.py <idioma base> <tomas base> <idioma nuevo>

Los tramos de video/cortes/<base>.json se midieron a ojo sobre las tomas de la base. Las esperas cambian de una
grabación a otra, pero cada toma deja sus marcas (<escena>.marcas.json: toques y marcas, en el mismo orden en todos los
idiomas). Cada frontera de tramo y cada toque se traslada con la marca anterior más cercana: t_nuevo = t + (m_nuevo -
m_base), y la velocidad del tramo se escala para que dure lo mismo en el vídeo. Escribe video/cortes/<nuevo>.json. NO sustituye la revisión: mira una tira de fotogramas de cada escena antes de
renderizar (README, «Medir los cortes del vídeo»).
"""
import json
import pathlib
import sys

MOLDE = pathlib.Path(__file__).resolve().parent.parent


def main() -> None:
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    base, tomas_base, nuevo = sys.argv[1], pathlib.Path(sys.argv[2]).expanduser(), sys.argv[3]
    sys.path.insert(0, str(MOLDE / "video"))
    salida = json.loads((MOLDE / "video/cortes" / f"{base}.json").read_text())
    import os
    raiz = pathlib.Path(os.environ.get("YALA_FICHA_SALIDA", pathlib.Path.home() / "Claude/propuestas/ficha-app-store-2.2"))
    tomas_nuevo = raiz / nuevo / "video" / "tomas"
    for escena, c in salida["escenas"].items():
        mb = json.loads((tomas_base / f"{escena}.marcas.json").read_text())
        mn = json.loads((tomas_nuevo / f"{escena}.marcas.json").read_text())
        assert [m["que"] for m in mb] == [m["que"] for m in mn], (escena, mb, mn)
        anclas = [(0.0, 0.0)] + [(a["t"], b["t"]) for a, b in zip(mb, mn)]

        def mover(t: float) -> float:
            # La marca anterior (con medio segundo de margen: los cortes se ponen justo antes del toque).
            previas = [a for a in anclas if a[0] <= t + 0.5]
            a = previas[-1]
            return round(t + (a[1] - a[0]), 2)

        # Cada tramo dura en el vídeo lo mismo que el medido: si la toma nueva tarda más entre dos marcas (las esperas
        # de la 2.2 son más largas), el tramo se acelera en la misma proporción.
        nuevos = []
        for d, h, v in c["tramos"]:
            nd, nh = mover(d), mover(h)
            vel = v * (nh - nd) / (h - d) if h > d and nh > nd else v
            nuevos.append([nd, nh, round(vel, 2)])
        c["tramos"] = nuevos
        for toque in c.get("toques", []):
            toque["t"] = mover(toque["t"])
    salida["_que"] = (f"Trasladados de cortes/{base}.json con las marcas de las tomas de {nuevo} "
                      f"(video/cortes_desde_marcas.py, 4-nov-2026) y revisados con una tira de fotogramas.")
    (MOLDE / "video/cortes" / f"{nuevo}.json").write_text(json.dumps(salida, ensure_ascii=False, indent=2) + "\n")
    print(f"✓ video/cortes/{nuevo}.json")


if __name__ == "__main__":
    main()
