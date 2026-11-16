#!/usr/bin/env python3
"""Genera los SQL de Yala web para PRODUCCIÓN a partir de los de staging (webapp/supabase/web*.sql).

Por qué no basta con cambiar los ids a mano. El hook de token lleva dentro dos ids de cliente OAuth (el conector de
Claude y la web), y las guardas de web0_01 y de su marcha atrás comparan el md5 del cuerpo del hook. Cambiar un id cambia
ese md5, así que web0_01 abortaría en producción («el hook no es el de mcp0_03»). Este script cambia los dos ids y
recalcula cada md5 que dependía de ellos: el del hook de mcp0_03 (que genera `mcp/scripts/sql-produccion.py` con el
mismo id del conector), el de web0_01 y el de web3_02.

El md5 se calcula como Postgres: sobre el texto exacto entre `as $$` y `$$;` de la función del hook. `--verificar`
comprueba que los ficheros de staging siguen dando los md5 medidos en staging (webapp/README.md).

Uso:
    python3 webapp/supabase/sql_produccion.py --verificar
    python3 webapp/supabase/sql_produccion.py <id-cliente-conector-prod> <id-cliente-web-prod> <carpeta-de-salida>

Si el conector de Claude NO está en producción, su id es el uuid nulo 00000000-0000-0000-0000-000000000000, que ningún
cliente real tiene: el hook solo reconoce a la web. Y entonces `mcp/scripts/sql-produccion.py` se genera con ese mismo
uuid nulo, para que las guardas encadenen.

Orden de aplicación en producción (cada uno, uno a uno, comprobando el md5 del hook tras cada paso):
    mcp0_01, mcp0_02, mcp0_03 (del generador del conector) → web0_01 → web1_01 → web3_01 → web3_02.
Marcha atrás, al revés: web3_02_rollback → web3_01_rollback → web1_01_rollback → web0_01_rollback.

No toca ninguna base. La salida no se commitea.
"""
import hashlib
import pathlib
import re
import sys

DIR = pathlib.Path(__file__).resolve().parent
ROOT = DIR.parents[1]
MCP0_03 = ROOT / "qa" / "cloud" / "mcp0_03_hook_keys_on_session.sql"
STAGING_CONECTOR = "65fb5767-59a5-4f50-b77c-7970e67589c5"
STAGING_WEB = "03e0f13b-818f-4a93-8e69-701ea6343fda"
FILES = [
    "web0_01_hook_web_client.sql", "web0_01_rollback.sql",
    "web1_01_bandeja_y_sesiones.sql", "web1_01_rollback.sql",
    "web3_01_grupos_lectura.sql", "web3_01_rollback.sql",
    "web3_02_grupos_escritura.sql", "web3_02_rollback.sql",
]
# El md5 del cuerpo del hook que deja cada fichero, medido en staging (webapp/README.md, «Supabase staging»).
MEDIDO = {
    "mcp0_03": ("0a03fb943169e9fcee294fca49710398", MCP0_03),
    "web0_01": ("120f45468bc1db690a4c5655e7a7d48c", DIR / "web0_01_hook_web_client.sql"),
    "web3_02": ("54a4444f713eea227049396021d27ebd", DIR / "web3_02_grupos_escritura.sql"),
    # Las marchas atrás dejan el cuerpo del paso anterior: web3_02_rollback el de web0_01, web0_01_rollback el de mcp0_03.
    "web3_02_rollback": ("120f45468bc1db690a4c5655e7a7d48c", DIR / "web3_02_rollback.sql"),
    "web0_01_rollback": ("0a03fb943169e9fcee294fca49710398", DIR / "web0_01_rollback.sql"),
}
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
HOOK_RE = re.compile(r"function public\.yala_mcp_access_token_hook\(event jsonb\).*?\nas \$\$(.*?)\$\$;", re.S)


def hook_md5(sql: str) -> str | None:
    """md5(prosrc) del hook que crea el fichero, o None si no lo crea."""
    m = HOOK_RE.search(sql)
    return hashlib.md5(m.group(1).encode()).hexdigest() if m else None


def verificar() -> int:
    mal = 0
    for nombre, (esperado, ruta) in MEDIDO.items():
        got = hook_md5(ruta.read_text())
        ok = got == esperado
        mal += not ok
        print(f"{'OK ' if ok else 'MAL'} {nombre}: {got} (medido en staging: {esperado})")
    return 1 if mal else 0


def cambiar_ids(sql: str, conector: str, web: str) -> str:
    return sql.replace(STAGING_CONECTOR, conector).replace(STAGING_WEB, web)


def generar(conector: str, web: str, salida: pathlib.Path) -> int:
    for nombre, valor in (("conector", conector), ("web", web)):
        if not UUID_RE.match(valor):
            print(f"El id del {nombre} tiene que ser un uuid en minúsculas: {valor!r}", file=sys.stderr)
            return 2
    if conector in (STAGING_CONECTOR, STAGING_WEB) or web in (STAGING_CONECTOR, STAGING_WEB):
        print("Ese es un id de STAGING.", file=sys.stderr)
        return 2
    if conector == web:
        print("El conector y la web no pueden ser el mismo cliente.", file=sys.stderr)
        return 2
    if verificar():
        print("Los ficheros de staging ya no dan los md5 medidos: no se genera nada.", file=sys.stderr)
        return 1
    # El md5 de cada cuerpo, antes y después de cambiar los ids. Cada guarda que citaba el de staging pasa a citar el nuevo.
    mapa = {}
    for nombre in ("mcp0_03", "web0_01", "web3_02"):
        viejo, ruta = MEDIDO[nombre]
        nuevo = hook_md5(cambiar_ids(ruta.read_text(), conector, web))
        mapa[viejo] = nuevo
    salida.mkdir(parents=True, exist_ok=True)
    cabecera = (f"-- GENERADO por webapp/supabase/sql_produccion.py para PRODUCCIÓN: conector {conector}, web {web}.\n"
                "-- No editar: regenerar.\n")
    for nombre in FILES:
        sql = cambiar_ids((DIR / nombre).read_text(), conector, web)
        for viejo, nuevo in mapa.items():
            sql = sql.replace(viejo, nuevo)
        if STAGING_CONECTOR in sql or STAGING_WEB in sql:
            print(f"{nombre}: sigue nombrando un cliente de staging", file=sys.stderr)
            return 1
        (salida / nombre).write_text(cabecera + sql)
    for viejo, nuevo in mapa.items():
        print(f"md5 {viejo} → {nuevo}")
    print(f"md5 del hook en producción: tras mcp0_03 {mapa['0a03fb943169e9fcee294fca49710398']} · "
          f"tras web0_01 {mapa['120f45468bc1db690a4c5655e7a7d48c']} · tras web3_02 {mapa['54a4444f713eea227049396021d27ebd']}")
    print(f"Escritos {len(FILES)} ficheros en {salida}")
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--verificar"]:
        sys.exit(verificar())
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(generar(sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])))
