"""Lector de exports XML de xctrace: resuelve id/ref y devuelve filas como dicts {mnemonic: (valor, fmt)}."""
import sys
import xml.etree.ElementTree as ET


def filas(path):
    cache = {}
    cols = []
    for ev, el in ET.iterparse(path, events=("end",)):
        if el.tag == "mnemonic":
            cols.append(el.text)
        elif el.tag == "row":
            out = {}
            for i, c in enumerate(list(el)):
                v = resolve(c, cache)
                if i < len(cols):
                    out[cols[i]] = v
            yield out
            el.clear()


def resolve(el, cache):
    ref = el.get("ref")
    if ref is not None:
        return cache.get(ref, (None, None, None))
    # valor: texto directo, o hijos (backtrace, process...)
    txt = el.text
    fmt = el.get("fmt")
    kids = list(el)
    sub = [resolve(k, cache) for k in kids] if kids else None
    val = (txt, fmt, sub)
    if el.get("id") is not None:
        cache[el.get("id")] = val
    # registrar ids de los hijos también
    return val


if __name__ == "__main__":
    for i, r in enumerate(filas(sys.argv[1])):
        print({k: (v[1] or v[0]) for k, v in r.items()})
        if i > 5:
            break
