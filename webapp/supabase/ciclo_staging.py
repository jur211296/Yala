#!/usr/bin/env python3
"""Prueba de punta a punta de los SQL de Yala web en Supabase STAGING, sin dejar nada cambiado.

Qué hace, en UNA sola consulta (una transacción implícita):
  1. toma la huella del estado actual (staging tiene aplicados web0_01, web1_01, web3_01 y web3_02);
  2. corre las cuatro marchas atrás en orden inverso (web3_02 → web3_01 → web1_01 → web0_01) y comprueba que queda el
     estado de antes de la web: hook de mcp0_03, sin rol `yala_web`, sin funciones `web_*`, sin políticas de la web,
     sin el cron de barrido;
  3. aplica los cuatro SQL en orden (web0_01 → web1_01 → web3_01 → web3_02) y comprueba que la huella vuelve a ser
     la del paso 1;
  4. termina con un RAISE que lleva el resultado. El RAISE aborta la transacción: staging queda exactamente igual.

Por qué así: la Management API de Supabase ejecuta la consulta entera como una transacción, así que un error al final
deshace todo lo anterior (medido el 2026-11-15 con una tabla de prueba). Es la forma de probar las marchas atrás sin
tumbar la web de staging ni un segundo.

Necesita el token de la Management API (`~/Secrets/yala-supabase-mgmt/pat`, en la Mini). No imprime secretos.

Segundo modo, `--produccion-simulada <sql-conector> <sql-web>`: con las carpetas que generan
`mcp/scripts/sql-produccion.py` y `webapp/supabase/sql_produccion.py`, simula en staging un proyecto SIN conector (como
producción el 2026-11-15): quita la web y el conector (mcp0_04 → mcp0_01), comprueba que no queda ni rol ni hook, aplica
la cadena de producción entera (mcp0_01–03 y los cuatro web), sus cuatro marchas atrás y otra vez los cuatro, y compara.
Todo en la misma transacción, que el RAISE final deshace. Lo que NO simula: `pg_cron` sin instalar (en staging está;
lo cubre el tercer modo).

Tercer modo, `--ensayo-produccion <sql-conector> <sql-web>` (16-nov): lo mismo contra PRODUCCIÓN, sin quitar nada
antes. Aplica la cadena, la vuelve atrás (web y conector), la reaplica y la vuelve atrás otra vez, y comprueba que las
dos marchas atrás dejan la huella de partida. Valida contra la base real (sin `pg_cron`, sin conector) y acaba en RAISE.

Uso:  python3 webapp/supabase/ciclo_staging.py            # contra staging (fostjbbwstyuunmmefuk)
      python3 webapp/supabase/ciclo_staging.py --produccion-simulada <carpeta-mcp> <carpeta-web>
Sale 0 si el ciclo cuadra; 1 si no.
"""
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

STAGING = "fostjbbwstyuunmmefuk"
PRODUCCION = "kefvaiymtgytemwbltlz"
DIR = pathlib.Path(__file__).resolve().parent
ADELANTE = ["web0_01_hook_web_client.sql", "web1_01_bandeja_y_sesiones.sql", "web3_01_grupos_lectura.sql",
            "web3_02_grupos_escritura.sql"]
ATRAS = ["web3_02_rollback.sql", "web3_01_rollback.sql", "web1_01_rollback.sql", "web0_01_rollback.sql"]
HOOK_MCP0_03 = "0a03fb943169e9fcee294fca49710398"
HOOK_WEB3_02 = "54a4444f713eea227049396021d27ebd"

# La huella: todo lo que tocan los cuatro SQL, en texto estable. Roles y pertenencias, cuerpo y permisos de cada
# función implicada, permisos y políticas de las tablas implicadas, y los trabajos de cron de la web.
HUELLA = r"""
-- Los trabajos de cron de la web, leídos con EXECUTE: producción no tiene `pg_cron` hasta que web1_01 lo instala, y una
-- función SQL que nombrara `cron.job` no llegaría a crearse allí.
create or replace function pg_temp.cron_web(detalle boolean) returns text language plpgsql as $f$
declare r text;
begin
  if to_regclass('cron.job') is null then return null; end if;
  if detalle then
    execute $q$select string_agg(jobname || ':' || schedule || ':' || command, ',' order by jobname) from cron.job
               where jobname like 'yala-web%'$q$ into r;
  else
    execute $q$select string_agg(jobname, '+') from cron.job where jobname like 'yala-web%'$q$ into r;
  end if;
  return r;
end
$f$;
create or replace function pg_temp.huella() returns text language sql as $f$
  select md5(concat_ws('|',
    (select string_agg(r.rolname || ':' || r.rolcanlogin, ',' order by r.rolname) from pg_roles r
       where r.rolname in ('yala_web', 'yala_mcp_reader')),
    (select string_agg(m.roleid::regrole || '>' || m.member::regrole, ',' order by 1) from pg_auth_members m
       where m.roleid::regrole::text in ('yala_web', 'yala_mcp_reader') or m.member::regrole::text in ('yala_web', 'yala_mcp_reader')),
    (select string_agg(p.oid::regprocedure || ':' || md5(p.prosrc) || ':' || p.prosecdef || ':' || coalesce(p.proacl::text, '-'),
                       ',' order by p.oid::regprocedure::text)
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and (p.proname like 'web\_%' or p.proname like 'yala\_web%' or p.proname like 'yala\_is\_web%'
         or p.proname like 'yala\_mcp%' or p.proname like 'groups\_pull\_rows\_%' or p.proname in
         ('apply_group_delta', 'create_group_invite', 'is_group_member', 'is_group_writer', 'yala_try_decrypt'))),
    (select string_agg(c.relname || ':' || coalesce(c.relacl::text, '-'), ',' order by c.relname) from pg_class c
       join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname in
       ('split_groups', 'group_members', 'split_expenses', 'split_shares', 'split_settlements', 'inbox_drafts')),
    (select string_agg(a.attname || ':' || a.attacl::text, ',' order by a.attname) from pg_attribute a
       where a.attacl is not null and a.attrelid = 'public.inbox_drafts'::regclass),
    (select string_agg(tablename || ':' || policyname || ':' || roles::text || ':' || coalesce(qual, '') || ':' || coalesce(with_check, ''),
                       ',' order by tablename, policyname)
       from pg_policies where schemaname = 'public' and tablename in
       ('split_groups', 'group_members', 'split_expenses', 'split_shares', 'split_settlements', 'inbox_drafts')),
    pg_temp.cron_web(true)
  ))
$f$;
create or replace function pg_temp.hook() returns text language sql as $f$
  select md5(p.prosrc) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook'
$f$;
create or replace function pg_temp.restos_web() returns text language sql as $f$
  select concat_ws(',',
    (select 'rol yala_web' from pg_roles where rolname = 'yala_web'),
    (select string_agg(p.proname, '+') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and (p.proname like 'web\_%' or p.proname like 'yala\_web%' or p.proname like 'yala\_is\_web%')),
    (select string_agg(tablename || '.' || policyname, '+') from pg_policies where schemaname = 'public'
      and (policyname like 'web\_%' or (tablename = 'inbox_drafts' and policyname = 'mcp_reader_select_own'))),
    pg_temp.cron_web(false))
$f$;
create temp table _ciclo (n int, paso text, huella text, hook text, restos text);
"""


def paso(n: int, nombre: str) -> str:
    return f"insert into _ciclo select {n}, '{nombre}', pg_temp.huella(), pg_temp.hook(), pg_temp.restos_web();\n"


def consulta() -> str:
    partes = [HUELLA, paso(1, "inicio")]
    partes += [f"-- {f}\n{(DIR / f).read_text()}\n" for f in ATRAS]
    partes.append(paso(2, "tras_marchas_atras"))
    partes += [f"-- {f}\n{(DIR / f).read_text()}\n" for f in ADELANTE]
    partes.append(paso(3, "tras_reaplicar"))
    partes.append(r"""do $fin$
declare r text;
begin
  select string_agg(n || '=' || paso || '|' || huella || '|' || coalesce(hook, 'sin_hook') || '|'
                    || coalesce(nullif(restos, ''), 'sin_restos'), ' ;; ' order by n)
    into r from _ciclo;
  raise exception 'CICLO_RESULTADO %', r;
end $fin$;
""")
    return "".join(partes)


CLOUD = DIR.parents[1] / "qa" / "cloud"
QUITAR_CONECTOR = ["mcp0_04_rollback.sql", "mcp0_03_rollback.sql", "mcp0_02_rollback.sql", "mcp0_01_rollback.sql"]
CONECTOR_PROD = ["mcp0_01_readonly_role.sql", "mcp0_02_oauth_client_allowlist.sql", "mcp0_03_hook_keys_on_session.sql"]


def consulta_produccion(mcp: pathlib.Path, web: pathlib.Path) -> str:
    leer = lambda d, fs: [f"-- {d.name}/{f}\n{(d / f).read_text()}\n" for f in fs]
    partes = [HUELLA, paso(1, "inicio")]
    partes += leer(DIR, ATRAS) + leer(CLOUD, QUITAR_CONECTOR)
    partes.append(paso(2, "sin_web_ni_conector"))
    partes += leer(mcp, CONECTOR_PROD) + leer(web, ADELANTE)
    partes.append(paso(3, "cadena_produccion"))
    partes += leer(web, ATRAS)
    partes.append(paso(4, "marchas_atras_produccion"))
    partes += leer(web, ADELANTE)
    partes.append(paso(5, "reaplicada_produccion"))
    partes.append(consulta().split("insert into _ciclo select 3")[1].split(";\n", 1)[1])
    return "".join(partes)


CONECTOR_PROD_ATRAS = ["mcp0_03_rollback.sql", "mcp0_02_rollback.sql", "mcp0_01_rollback.sql"]


def consulta_ensayo_produccion(mcp: pathlib.Path, web: pathlib.Path) -> str:
    """Ensayo en PRODUCCIÓN: aplica, vuelve atrás, reaplica y vuelve atrás otra vez, y termina en RAISE.

    Acaba en el estado de partida a propósito: si el RAISE no llegara a deshacer la transacción, producción quedaría
    como estaba (más `pg_cron`, que web1_01 instala y ninguna marcha atrás quita).
    """
    leer = lambda d, fs: [f"-- {d.name}/{f}\n{(d / f).read_text()}\n" for f in fs]
    adelante = leer(mcp, CONECTOR_PROD) + leer(web, ADELANTE)
    atras = leer(web, ATRAS) + leer(mcp, CONECTOR_PROD_ATRAS)
    partes = [HUELLA, paso(1, "inicio")]
    partes += adelante
    partes.append(paso(2, "cadena_aplicada"))
    partes += atras
    partes.append(paso(3, "marchas_atras"))
    partes += adelante
    partes.append(paso(4, "reaplicada"))
    partes += atras
    partes.append(paso(5, "otra_vez_atras"))
    partes.append(consulta().split("insert into _ciclo select 3")[1].split(";\n", 1)[1])
    return "".join(partes)


def main() -> int:
    if sys.argv[1:2] == ["--produccion-simulada"]:
        return correr(consulta_produccion(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])), simulada=True)
    if sys.argv[1:2] == ["--ensayo-produccion"]:
        sql = consulta_ensayo_produccion(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))
        return correr(sql, simulada=False, proyecto=PRODUCCION, ensayo=True)
    return correr(consulta(), simulada=False)


def correr(sql: str, simulada: bool, proyecto: str = STAGING, ensayo: bool = False) -> int:
    pat = pathlib.Path("~/Secrets/yala-supabase-mgmt/pat").expanduser().read_text().strip()
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{proyecto}/database/query", method="POST",
        data=json.dumps({"query": sql}).encode(),
        headers={"Authorization": f"Bearer {pat}", "Content-Type": "application/json", "User-Agent": "yala-web-ciclo"})
    try:
        with urllib.request.urlopen(req, timeout=120) as f:
            print("MAL: la consulta terminó sin el RAISE final, y eso quiere decir que se confirmó:", f.read()[:300])
            return 1
    except urllib.error.HTTPError as e:
        cuerpo = e.read().decode()
    m = re.search(r"CICLO_RESULTADO (.*?)(?:\\n|\")", cuerpo)
    if not m:
        print("MAL: el ciclo se cortó antes del final (la transacción se deshizo igual). Error de Postgres:")
        print(cuerpo[:1500])
        return 1
    filas = {}
    for trozo in m.group(1).split(" ;; "):
        n, resto = trozo.split("=", 1)
        nombre, huella, hook, restos = resto.split("|")
        filas[int(n)] = (nombre, huella, hook, restos)
        print(f"{n}. {nombre}: huella {huella} · hook {hook} · restos de la web: {restos}")
    ok = True
    if ensayo:
        if filas[1][2] is None or filas[1][2] != "sin_hook" or filas[1][3] != "sin_restos":
            print("MAL: producción no partía sin hook ni restos de la web")
            ok = False
        if filas[2][3] == "sin_restos" or filas[2][2] == "sin_hook":
            print("MAL: la cadena no dejó el hook ni la web")
            ok = False
        for n in (3, 5):
            if filas[n][1] != filas[1][1] or filas[n][2] != "sin_hook" or filas[n][3] != "sin_restos":
                print(f"MAL: tras las marchas atrás ({n}) la huella no es la de partida")
                ok = False
        if filas[4][1] != filas[2][1] or filas[4][2] != filas[2][2]:
            print("MAL: tras reaplicar, la huella no es la de la cadena")
            ok = False
        print("ENSAYO OK: en producción la cadena aplica, vuelve atrás a la huella de partida y se reaplica idéntica; "
              "nada confirmado (transacción deshecha)" if ok else "ENSAYO CON FALLOS")
        return 0 if ok else 1
    if simulada:
        if filas[2][2] != "sin_hook" or filas[2][3] != "sin_restos":
            print("MAL: sin web ni conector quedó hook o restos de la web")
            ok = False
        if filas[4][3] != "sin_restos":
            print("MAL: tras las marchas atrás de producción quedan restos de la web")
            ok = False
        if filas[4][2] == filas[3][2]:
            print("MAL: la marcha atrás de producción no cambió el hook")
            ok = False
        if filas[5][1] != filas[3][1] or filas[5][2] != filas[3][2]:
            print("MAL: tras reaplicar, la huella de producción no es la de la cadena")
            ok = False
        print("SIMULACIÓN OK: la cadena de producción aplica sobre un proyecto sin conector, vuelve atrás limpia y se "
              "reaplica idéntica; staging sin cambios (transacción deshecha)" if ok else "SIMULACIÓN CON FALLOS")
        return 0 if ok else 1
    if filas[1][2] != HOOK_WEB3_02:
        print(f"MAL: staging no partía del hook de web3_02 ({HOOK_WEB3_02})")
        ok = False
    if filas[2][2] != HOOK_MCP0_03:
        print(f"MAL: tras las marchas atrás el hook no es el de mcp0_03 ({HOOK_MCP0_03})")
        ok = False
    if filas[2][3] != "sin_restos":
        print("MAL: tras las marchas atrás quedan restos de la web")
        ok = False
    if filas[3][1] != filas[1][1] or filas[3][2] != filas[1][2]:
        print("MAL: tras reaplicar, la huella no es la del inicio")
        ok = False
    print("CICLO OK: marchas atrás limpias, reaplicación idéntica, staging sin cambios (transacción deshecha)" if ok
          else "CICLO CON FALLOS")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
