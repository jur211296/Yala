"""Actualización del 26-nov-2026: de la guía de la 2.3 (10) a la de la 2.3 (11).

Aplica `delta_2026_11_26_build11.json` sobre `inventario.json` y lo reescribe. No se aplica dos veces: si ya hay un ítem del
delta, para.

- Pone `nuevo_guia` a false y `cambio_guia` a "" en todo lo anterior.
- Suma los ítems nuevos: los PR que cambian la app mergeados en 2.3 entre el corte de la 2.3 (10) y el de la 2.3 (11).
  Todos llegan en la 2.3 (11).
- Aplica los cambios sobre ítems existentes (con su `cambio_guia`).

Fuentes: el cuerpo de cada PR (`gh pr view`), clasificado el 26-nov. Los PR descartados (propuestas, servidor, QA)
van en `descartados` con su motivo.
"""
import json
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
RUTA = os.path.join(AQUI, "inventario.json")
items = json.load(open(RUTA))
delta = json.load(open(os.path.join(AQUI, "delta_2026_11_26_build11.json")))
ids_nuevos = {x["id"] for x in delta["nuevos"]}
if any(x["id"] in ids_nuevos for x in items):
    raise SystemExit("Ya aplicada: inventario.json tiene ítems de la build 11.")

by = {x["id"]: x for x in items}
for x in items:
    x["nuevo_guia"] = False
    x["cambio_guia"] = ""

for c in delta["cambios"]:
    x = by[c["id"]]
    x.update(c["campos"])
    x["nuevo_guia"] = True
    x["cambio_guia"] = c["cambio_guia"]

for x in delta["nuevos"]:
    x = dict(x)
    x["nuevo_guia"] = True
    x["cambio_guia"] = f"Nuevo en la guía: llegó en la 2.3 ({x['build']})."
    items.append(x)

json.dump(items, open(RUTA, "w"), ensure_ascii=False, indent=1)
print(len(items), "ítems;", sum(x["nuevo_guia"] for x in items), "nuevos o cambiados en la guía")
