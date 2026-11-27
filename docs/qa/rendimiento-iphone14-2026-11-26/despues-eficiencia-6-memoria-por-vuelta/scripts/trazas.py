"""Lectores de las tablas de `xctrace export` que usa la pasada final (lote 6).

El informe de origen citaba `xtparse.py` y `perfil_lector.py`, que no llegaron al repo; esto los sustituye.
Cada tabla trae sus valores con `id` la primera vez y `ref` después: aquí se resuelven las dos.
"""
import datetime
import os
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET


def exportar(trace, schema, carpeta=None):
    """Exporta la tabla `schema` de la traza a un XML y devuelve su ruta (se reusa si ya existe)."""
    carpeta = carpeta or tempfile.mkdtemp()
    out = os.path.join(carpeta, f"{os.path.basename(trace)}.{schema}.xml")
    if not os.path.exists(out):
        with open(out, "w") as f:
            subprocess.run(["xcrun", "xctrace", "export", "--input", trace, "--xpath",
                            f'/trace-toc/run[1]/data/table[@schema="{schema}"]'],
                           stdout=f, stderr=subprocess.DEVNULL)
    return out


def inicio(trace):
    """Hora de inicio de la traza (epoch, s)."""
    toc = subprocess.run(["xcrun", "xctrace", "export", "--input", trace, "--toc"], capture_output=True, text=True).stdout
    m = re.search(r"<start-date>([^<]+)</start-date>", toc)
    return datetime.datetime.fromisoformat(m.group(1)).timestamp()


def filas(path):
    """Filas de la tabla como dicts {columna: (texto, fmt)}, con los `ref` resueltos."""
    ids = {}
    cols = None
    for ev, el in ET.iterparse(path, events=("end",)):
        if el.tag == "schema":
            cols = [c.findtext("mnemonic") for c in el.findall("col")]
            continue
        if el.tag != "row" or cols is None:
            continue
        d = {}
        for c, v in zip(cols, list(el)):
            if v.get("ref"):
                d[c] = ids.get(v.get("ref"), (None, None))
                continue
            for sub in v.iter():
                if sub.get("id") and sub is not v:
                    ids[sub.get("id")] = (sub.text, sub.get("fmt"))
            texto = v.text
            if texto is None and len(v):
                h = v[0]
                texto = ids.get(h.get("ref"), (None,))[0] if h.get("ref") else h.text
            val = (texto, v.get("fmt"))
            if v.get("id"):
                ids[v.get("id")] = val
            d[c] = val
        el.clear()
        yield d


def muestras(path, proceso="Yala"):
    """Muestras del Time Profiler del proceso: [(t_s, es_hilo_principal, [nombres de frame])].

    Cada muestra pesa 1 ms (intervalo por defecto), así que contar muestras del hilo principal por segundo da ms de CPU.
    """
    ids, frames, bts = {}, {}, {}
    out = []
    for ev, row in ET.iterparse(path, events=("end",)):
        if row.tag != "row":
            continue
        t = hilo = proc = None
        nombres = None
        for el in row:
            nodo = ids.get(el.get("ref"), el)
            if el.get("id"):
                ids[el.get("id")] = el
            if el.tag == "sample-time":
                t = int(nodo.text) / 1e9
            elif el.tag == "thread":
                # El fmt del hilo lleva el proceso: «Main Thread 0x… (Yala, pid: 3477)». Con `ref`, `nodo` es el original.
                hilo = nodo.get("fmt") or ""
                proc = hilo
                for sub in el.iter():
                    if sub.get("id") and sub is not el:
                        ids[sub.get("id")] = sub
            elif el.tag in ("backtrace", "tagged-backtrace"):
                if el.get("ref"):
                    nombres = bts.get(el.get("ref"), [])
                else:
                    nombres = []
                    for f in el.iter("frame"):
                        if f.get("ref"):
                            nombres.append(frames.get(f.get("ref"), "?"))
                        else:
                            frames[f.get("id")] = f.get("name") or "?"
                            nombres.append(frames[f.get("id")])
                    bts[el.get("id")] = nombres
        row.clear()
        if t is None:
            continue
        if proceso and proc is not None and proceso not in proc:
            continue
        out.append((t, "Main Thread" in (hilo or ""), nombres or []))
    return out
