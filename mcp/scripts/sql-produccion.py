#!/usr/bin/env python3
"""Genera los SQL del hook del conector para PRODUCCIÓN a partir de los de staging (qa/cloud/mcp0_0*.sql).

Por qué no basta con cambiar el id a mano. Cada migración lleva una guarda que solo la deja aplicarse sobre el cuerpo
anterior, identificado por el md5 de `prosrc`. Cambiar el id del cliente cambia ese md5, así que `mcp0_03` abortaría
en producción («el hook no es el de mcp0_02»). Este script cambia el id Y recalcula cada md5 que dependía de él.

El md5 se calcula como Postgres: sobre el texto exacto entre `as $$` y `$$;`. Comprobado contra los md5 medidos en
staging (ab0f2476…, 0a03fb94…): `--verificar` lo repite.

Uso:
    python3 mcp/scripts/sql-produccion.py <id-del-cliente-de-produccion> <carpeta-de-salida>
    python3 mcp/scripts/sql-produccion.py --verificar

No toca ninguna base. La salida no se commitea: se aplica por el runbook (mcp/RUNBOOK-produccion.md, paso 5).
"""
import hashlib
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CLOUD = ROOT / "qa" / "cloud"
STAGING_CLIENT = "65fb5767-59a5-4f50-b77c-7970e67589c5"
FILES = [
    "mcp0_01_readonly_role.sql",
    "mcp0_01_rollback.sql",
    "mcp0_02_oauth_client_allowlist.sql",
    "mcp0_02_rollback.sql",
    "mcp0_03_hook_keys_on_session.sql",
    "mcp0_03_rollback.sql",
]
# Los md5 que se midieron en staging (docs/RUNBOOK-staging-ddl.md): mcp0_01, mcp0_02 y mcp0_03.
MEASURED = {
    "mcp0_01_readonly_role.sql": "5a048417a612be4ceea44ee89ce969f6",
    "mcp0_02_oauth_client_allowlist.sql": "ab0f247643cc82fa54a18079579f733a",
    "mcp0_03_hook_keys_on_session.sql": "0a03fb943169e9fcee294fca49710398",
}
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
BODY_RE = re.compile(r"\nas \$\$(.*?)\$\$;", re.S)


def body_md5(sql: str) -> str | None:
    """md5(prosrc) de la función que crea el fichero, o None si no crea ninguna."""
    m = BODY_RE.search(sql)
    return hashlib.md5(m.group(1).encode()).hexdigest() if m else None


def verify() -> int:
    bad = 0
    for name, expected in MEASURED.items():
        got = body_md5((CLOUD / name).read_text())
        ok = got == expected
        bad += not ok
        print(f"{'OK ' if ok else 'MAL'} {name}: {got} (medido en staging: {expected})")
    return 1 if bad else 0


def generate(client_id: str, out: pathlib.Path) -> int:
    if not UUID_RE.match(client_id):
        print(f"El id del cliente tiene que ser un uuid en minúsculas: {client_id!r}", file=sys.stderr)
        return 2
    if client_id == STAGING_CLIENT:
        print("Ese es el id del cliente de STAGING.", file=sys.stderr)
        return 2
    if verify():
        print("Los ficheros de staging ya no dan los md5 medidos: no se genera nada.", file=sys.stderr)
        return 1
    sources = {name: (CLOUD / name).read_text() for name in FILES}
    # 1. El id, en todos. 2. Cada md5 de un cuerpo que cambió, en todas las guardas que lo citaban.
    swapped = {name: sql.replace(STAGING_CLIENT, client_id) for name, sql in sources.items()}
    md5_map = {}
    for name in FILES:
        old, new = body_md5(sources[name]), body_md5(swapped[name])
        if old and new and old != new:
            md5_map[old] = new
    out.mkdir(parents=True, exist_ok=True)
    header = f"-- GENERADO por mcp/scripts/sql-produccion.py para PRODUCCIÓN, cliente {client_id}. No editar: regenerar.\n"
    for name in FILES:
        sql = swapped[name]
        for old, new in md5_map.items():
            sql = sql.replace(old, new)
        if STAGING_CLIENT in sql:
            print(f"{name}: sigue nombrando el cliente de staging", file=sys.stderr)
            return 1
        (out / name).write_text(header + sql)
    for old, new in md5_map.items():
        print(f"md5 {old} → {new}")
    print(f"md5 esperado del hook tras mcp0_03 en producción: {body_md5((out / FILES[4]).read_text())}")
    print(f"Escritos {len(FILES)} ficheros en {out}")
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--verificar"]:
        sys.exit(verify())
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(generate(sys.argv[1], pathlib.Path(sys.argv[2])))
