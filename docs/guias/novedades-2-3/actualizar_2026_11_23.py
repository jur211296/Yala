"""Actualización del 23-nov-2026: de la guía de la 2.3 (2) a la de la 2.3 (7).

Aplica `delta_2026_11_23.json` sobre `inventario.json` y lo reescribe. No se aplica dos veces: si ya hay un ítem del
delta, para.

- Pone `nuevo_guia` a false y `cambio_guia` a "" en todo lo anterior.
- Suma los ítems nuevos (PR mergeados en 2.3 entre el corte de la 2.3 (2) y el de la 2.3 (7)). Su `build` es la
  primera build de TestFlight que los llevó (3 a 7), según la hora de merge frente al PR del número de cada build.
- Aplica los cambios sobre ítems existentes (rediseños, retiros, lo que pasó a producción). Estado nuevo
  `retirado`: llegó en una build anterior y otra posterior lo reemplazó o lo quitó.
- Pasa a «listo» lo que el 16-nov quedó fuera de la 2.3 (2) y ya entró en la 2.3 (3).
- Lo medido en producción el 23-nov: `/config` del gateway con `aiCloudExploreRolloutPercent` 100 y
  `appleWebSignInRolloutPercent` 0; `mcp.yala-app.pe` y `app.yala-app.pe` responden 200.

Fuentes del delta: el cuerpo y los ficheros de cada PR (`gh pr view`), clasificados el 23-nov. Los PR descartados
(solo web, tests, CI, docs, maquetas o proceso) van en `descartados` con su motivo.
"""
import json
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
RUTA = os.path.join(AQUI, "inventario.json")
items = json.load(open(RUTA))
delta = json.load(open(os.path.join(AQUI, "delta_2026_11_23.json")))
ids_nuevos = {x["id"] for x in delta["nuevos"]}
if any(x["id"] in ids_nuevos for x in items):
    raise SystemExit("Ya aplicada: inventario.json tiene ítems del 23-nov.")

by = {x["id"]: x for x in items}
for x in items:
    x["nuevo_guia"] = False
    x["cambio_guia"] = ""


def upd(id_, cambio, **kw):
    x = by[id_]
    x.update(kw)
    x["nuevo_guia"] = True
    x["cambio_guia"] = cambio


for c in delta["cambios"]:
    campos = dict(c["campos"])
    # Un ítem que llegó y después se reemplazó no está «fuera de TestFlight»: queda «retirado».
    if campos.get("estado") == "fuera" and by[c["id"]]["seccion"] != "fuera":
        campos["estado"] = "retirado"
    upd(c["id"], c["cambio_guia"], **campos)

# Lo que el 16-nov quedó fuera de la 2.3 (2) y entró en la 2.3 (3).
for id_ in ("1003-1", "999-1", "997-1"):
    upd(id_, "Ya llegó: entró en la 2.3 (3).", seccion="existente", estado="listo", build="3", activar="")

# Medido en producción el 23-nov.
upd(
    "840-2",
    "Medido de nuevo el 23-nov: sigue al 0 % en producción.",
    activar="Medido el 23-nov en la configuración remota de producción: «Otra cuenta de Apple» sigue al 0 %. "
    "Solo se ve en Yala Dev contra staging.",
)

for x in delta["nuevos"]:
    x = dict(x)
    x["nuevo_guia"] = True
    x["cambio_guia"] = f"Nuevo en la guía: llegó en la 2.3 ({x['build']})."
    items.append(x)

json.dump(items, open(RUTA, "w"), ensure_ascii=False, indent=1)
print(len(items), "ítems;", sum(x["nuevo_guia"] for x in items), "nuevos o cambiados en la guía")
