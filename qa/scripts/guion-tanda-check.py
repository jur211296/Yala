#!/usr/bin/env python3
"""guion-tanda-check.py — cruza `tickets/qa/*.md` con `qa/guion-tanda.md` y dice qué se queda fuera.

    python3 -I qa/scripts/guion-tanda-check.py              # informe; exit 1 si hay desfase
    python3 -I qa/scripts/guion-tanda-check.py --escribir   # además lo deja escrito en el guion
    python3 -I qa/scripts/guion-tanda-check.py --guion docs/qa/tanda-qa-jurgen-2.2-*.md --tablero
    python3 -I qa/scripts/guion-tanda-check.py --raiz DIR   # otro repo (lo usa el banco)

`--guion F` (repetible) cambia el guion: por defecto `qa/guion-tanda.md`, que dejó de escribirse el
2026-10-04; desde entonces el guion vivo son las tandas `docs/qa/tanda-qa-jurgen-<versión>*.md` de
`/barrido-qa`. Con varios, un ticket cuenta como nombrado si sale en cualquiera, y `--escribir`
escribe el aviso en el PRIMERO. `--tablero` suma a lo que espera prueba las cards de Yala en «in qa»
(sin las de Lola), que es donde vive la cola desde octubre; las tandas las nombran por el sufijo
de cuatro letras. `--tablero-json F` lee esa lista de un fichero (el banco, o sin red).

**Por qué existe.** El guion agrupa por montaje los tickets que esperan prueba en el iPhone, y su
valor es que quien hace la tanda no tenga que mirar `tickets/qa/`. Pero se mantenía a mano («al mover
algo a `qa/`, actualiza este guion») y se descolgó tres veces: 17 fuera el 2026-09-06, 24 el
2026-10-08 y, el 2026-11-05, los 17 de `qa/` fuera y los 36 que nombraba ya en `done`. Un ticket sin
montaje no se distingue de uno verificado: se pierde sin que nada avise. Ticket:
`qa-guion-tanda-no-cubre-17-tickets`.

**Qué mide.** Un ticket está «en el guion» si su id aparece entre comillas invertidas FUERA del
bloque de aviso que escribe este script. Dos listas:

- **fuera**: está en `tickets/qa/` y el guion no lo nombra. Es el fallo que importa.
- **sobran**: el guion nombra un ticket que ya no está en `tickets/qa/` (vive en otra carpeta de
  `tickets/`). Es información, no fallo: una tanda nombra también lo que el barrido cerró.

**`--escribir`** reescribe solo el bloque entre `<!-- guion-check:inicio -->` y
`<!-- guion-check:fin -->`, debajo del título; si no existe, lo crea ahí. Así el propio guion avisa
de lo que deja fuera a quien lo abre, aunque nadie corra el script. Repartir lo de «fuera» en
montajes sigue siendo trabajo de `/barrido-qa`.

**No va en el CI contra el guion real**: cada PR que mueve un ticket a `qa/` saldría rojo. En el CI
va su banco, `qa/scripts/guion-tanda-check-test.sh`.

Exit: 0 = nada fuera · 1 = hay tickets o cards fuera · 2 = error de uso o de entorno.
"""
import json
import os
import re
import subprocess
import sys
import time

INICIO = "<!-- guion-check:inicio -->"
FIN = "<!-- guion-check:fin -->"


def muere(msg):
    print("guion-tanda-check: " + msg, file=sys.stderr)
    sys.exit(2)


def args():
    raiz = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    escribir = False
    guiones = []
    tablero = None          # None = no se mira · "vivo" = CLI `tablero` · ruta = fichero JSON
    resto = sys.argv[1:]
    while resto:
        a = resto.pop(0)
        if a == "--escribir":
            escribir = True
        elif a == "--guion":
            if not resto:
                muere("--guion necesita un fichero")
            guiones.append(resto.pop(0))
        elif a == "--tablero":
            tablero = "vivo"
        elif a == "--tablero-json":
            if not resto:
                muere("--tablero-json necesita un fichero")
            tablero = os.path.abspath(resto.pop(0))
        elif a == "--raiz":
            if not resto:
                muere("--raiz necesita un directorio")
            raiz = os.path.abspath(resto.pop(0))
        else:
            muere("argumento desconocido: " + a)
    if not guiones:
        guiones = [os.path.join(raiz, "qa", "guion-tanda.md")]
    guiones = [g if os.path.isabs(g) else os.path.join(raiz, g) for g in guiones]
    return raiz, escribir, guiones, tablero


def cards_en_qa(tablero):
    """Cards de Yala en «in qa», sin las de Lola. Fail-closed: si no se pueden leer, sale 2 —
    un «nada fuera» sin haber mirado el tablero sería el silencio que este script vino a quitar."""
    try:
        if tablero == "vivo":
            r = subprocess.run(["tablero", "listar", "--proyecto", "yala", "--estado", "qa", "--json"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
            if r.returncode != 0:
                muere("`tablero listar` falló: " + r.stderr.decode("utf-8", "replace").strip()[:200])
            datos = json.loads(r.stdout.decode("utf-8"))
        else:
            with open(tablero, encoding="utf-8") as f:
                datos = json.load(f)
    except (OSError, ValueError, subprocess.SubprocessError) as e:
        muere(f"no pude leer el tablero: {e}")
    return sorted(c["id"] for c in datos
                  if c.get("column") == "in qa" and c.get("assignee") != "lola" and c.get("id"))


def card_nombrada(cid, nombrados):
    corto = cid[len("tablero-"):] if cid.startswith("tablero-") else cid
    sufijo = cid.rsplit("-", 1)[-1]
    return bool({cid, corto, sufijo} & nombrados)


def ids_en(carpeta):
    try:
        return {f[:-3] for f in os.listdir(carpeta) if f.endswith(".md")}
    except FileNotFoundError:
        return set()


def partes(texto):
    """(antes, después) del bloque de aviso, o None si no hay bloque bien formado."""
    i, j = texto.find(INICIO), texto.find(FIN)
    if i == -1 or j == -1 or j < i:
        return None
    return texto[:i], texto[j + len(FIN):]


def bloque(fuera, sobran, total_qa, fuentes):
    hoy = time.strftime("%Y-%m-%d")
    lineas = [INICIO]
    if not fuera and not sobran:
        lineas.append(f"> ✅ **Nada fuera:** los {total_qa} de {fuentes} salen en el guion · comprobado el {hoy} "
                      "con `qa/scripts/guion-tanda-check.py`.")
    else:
        lineas.append(f"> ⚠️ **Este guion NO cubre todo lo que espera prueba** ({fuentes}) · comprobado el {hoy} con "
                      "`qa/scripts/guion-tanda-check.py`. Hasta que `/barrido-qa` lo reparta, una tanda "
                      "que siga solo el guion se deja lo de abajo.")
        if fuera:
            lineas.append(">")
            lineas.append(f"> **Esperan prueba y el guion no los nombra ({len(fuera)} de {total_qa}):**")
            lineas.append("> (un ticket o card que el barrido decidió no traer al iPhone también se nombra, en la tabla «lo que se queda»)")
            lineas.extend(f"> - `{t}`" for t in fuera)
        if sobran:
            lineas.append(">")
            lineas.append(f"> **El guion los pide, pero ya no están en `tickets/qa/` ({len(sobran)}):** "
                          "sáltalos.")
            lineas.append("> " + " · ".join(f"`{t}`" for t in sobran))
    lineas.append(FIN)
    return "\n".join(lineas)


def main():
    raiz, escribir, guiones, tablero = args()
    guion = guiones[0]
    tickets = os.path.join(raiz, "tickets")
    if not os.path.isdir(tickets):
        muere(f"no encuentro {tickets}")
    textos = []
    for g in guiones:
        try:
            with open(g, encoding="utf-8") as f:
                textos.append(f.read())
        except OSError as e:
            muere(f"no puedo leer {g}: {e}")
    texto = textos[0]

    en_qa = ids_en(os.path.join(tickets, "qa"))
    otros = set()
    for c in os.listdir(tickets):
        if c != "qa" and os.path.isdir(os.path.join(tickets, c)):
            otros |= ids_en(os.path.join(tickets, c))

    p = partes(texto)
    nombrados = set()
    for i, t in enumerate(textos):
        q = partes(t)
        cuerpo = (q[0] + q[1]) if q else t
        nombrados |= set(re.findall(r"`([a-z0-9][a-z0-9-]*[a-z0-9])`", cuerpo))
    fuera = sorted(en_qa - nombrados)
    sobran = sorted((nombrados & otros) - en_qa)
    total = len(en_qa)
    fuentes = "`tickets/qa/`"
    if tablero:
        cards = cards_en_qa(tablero)
        fuera += [c for c in cards if not card_nombrada(c, nombrados)]
        total += len(cards)
        fuentes += " y las cards «in qa» del tablero"
        print(f"tablero «in qa» (Yala, sin Lola): {len(cards)}")

    print(f"tickets/qa: {len(en_qa)} · esperan prueba en total: {total} · fuera del guion: {len(fuera)}")
    if fuera:
        print(f"FUERA ({len(fuera)}) — esperan prueba y el guion no los nombra:")
        for t in fuera:
            print("  - " + t)
    if sobran:
        print(f"SOBRAN ({len(sobran)}) — el guion los pide y ya no están en tickets/qa:")
        for t in sobran:
            print("  - " + t)
    if not fuera and not sobran:
        print("OK nada de lo que espera prueba se queda fuera del guion.")

    if escribir:
        nuevo = bloque(fuera, sobran, total, fuentes)
        if p:
            texto = p[0] + nuevo + p[1]
        else:
            m = re.search(r"^# .*\n", texto, re.M)
            corte = m.end() if m else 0
            texto = texto[:corte] + "\n" + nuevo + "\n" + texto[corte:]
        with open(guion, "w", encoding="utf-8") as f:
            f.write(texto)
        print(f"(aviso escrito en {os.path.relpath(guion, raiz)})")

    sys.exit(1 if fuera else 0)


if __name__ == "__main__":
    main()
