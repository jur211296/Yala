#!/usr/bin/env python3
"""El SQL que le falta a Supabase PRODUCCIÓN para el conector de Claude, y nada más (runbook: mcp/RUNBOOK-produccion.md).

Por qué este script y no `mcp/scripts/sql-produccion.py`. Producción ya tiene, desde el 16-nov, la cadena entera de
Yala web: `mcp0_01`–`mcp0_03` (con el id del conector como uuid NULO) y `web0_01`, `web1_01`, `web3_01`, `web3_02`
(webapp/README.md, «Producción»). Volver a aplicar los `mcp0_0*` abortaría por su guarda md5 y, si pasara, el hook
perdería el rol `yala_web` y la web dejaría de entrar. Lo único que falta es:

  conector01  El hook de token reconoce al cliente del conector: el MISMO cuerpo de `web3_02` que corre hoy, con el id
              real del conector donde hoy está el uuid nulo. La web sigue con `yala_web`; el login de la app, intacto.
  conector02  El barrido diario de las sesiones huérfanas del conector (`qa/cloud/mcp0_04`, con el id real). Necesita
              `pg_cron`, que producción ya tiene desde `web1_01`.

Cada uno con su marcha atrás (`*_rollback.sql`). Las guardas abortan si producción no está como se midió el 22-nov:
hook con md5 `HOOK_PROD_ANTES`, roles `yala_mcp_reader` y `yala_web`, cliente web vivo y el cliente del conector
registrado como confidencial con la vuelta de producción. Cada fichero acaba comprobando su propio resultado y aborta
si no cuadra: aplicado como una sola transacción (`aplicar`, o `psql -1`), un fallo no deja nada a medias.

Uso:
    python3 mcp/scripts/sql-conector-produccion.py --verificar
        Las fuentes del repo siguen dando los md5 medidos en staging y en producción. Sin red.
    python3 mcp/scripts/sql-conector-produccion.py generar <id-cliente-conector> <carpeta>
        Escribe los cuatro SQL de producción y `_md5.json`. Sin red.
    python3 mcp/scripts/sql-conector-produccion.py estado [produccion|staging]
        SOLO LECTURA: hook, roles, clientes OAuth (sin secretos), barrido, cron y la config de Auth que importa.
    python3 mcp/scripts/sql-conector-produccion.py ensayo <produccion|staging> <carpeta>
        Aplica la carpeta generada, la vuelve atrás y la reaplica DENTRO de una transacción que un RAISE final deshace.
    python3 mcp/scripts/sql-conector-produccion.py aplicar <produccion|staging> <fichero.sql>
        Aplica UN fichero como una sola transacción. Es lo único que escribe: lo corre Dan, uno a uno.
    python3 mcp/scripts/sql-conector-produccion.py ensayo-staging
        La prueba de punta a punta en staging, sin dejar nada cambiado (ver `ensayo_staging`).

Los modos con red usan el token de la Management API (`~/Secrets/yala-supabase-mgmt/pat`, en la Mini) y no imprimen
secretos.
"""
import hashlib
import json
import pathlib
import re
import sys
import tempfile
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
WEB3_02 = ROOT / "webapp" / "supabase" / "web3_02_grupos_escritura.sql"
MCP0_04 = ROOT / "qa" / "cloud" / "mcp0_04_sweep_connector_sessions.sql"
MCP0_04_ROLLBACK = ROOT / "qa" / "cloud" / "mcp0_04_rollback.sql"

PROYECTOS = {"produccion": "kefvaiymtgytemwbltlz", "staging": "fostjbbwstyuunmmefuk"}
NULO = "00000000-0000-0000-0000-000000000000"
STAGING_CONECTOR = "65fb5767-59a5-4f50-b77c-7970e67589c5"
STAGING_WEB = "03e0f13b-818f-4a93-8e69-701ea6343fda"
STAGING_VUELTA = "https://yala-mcp-staging.misty-surf-6866.workers.dev/oauth/supabase/callback"
PROD_WEB = "79c7e38e-409e-470f-9151-81784a02760c"  # «Yala web», registrado el 16-nov
PROD_VUELTA = "https://mcp.yala-app.pe/oauth/supabase/callback"
CLIENTE_FALSO = "abcdef01-2345-4678-9abc-def012345678"

# Medido el 2026-11-22 en solo lectura: el hook de producción (web3_02 con el conector nulo y la web de producción),
# el de staging (web3_02 con sus dos clientes) y el cuerpo del barrido de staging (mcp0_04 con su conector).
HOOK_PROD_ANTES = "7a703d859cc6b241dff8eba12dabf906"
HOOK_STAGING = "54a4444f713eea227049396021d27ebd"
BARRIDO_STAGING = "47f0bfc98b5191071517395b44cbd88b"

UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
BODY_RE = re.compile(r"\nas \$\$(.*?)\$\$;", re.S)
HOOK_BLOQUE_RE = re.compile(
    r"create or replace function public\.yala_mcp_access_token_hook\(event jsonb\).*?"
    r"revoke execute on function public\.yala_mcp_access_token_hook\(jsonb\) from authenticated, anon, public;\n",
    re.S,
)
BARRIDO_BLOQUE_RE = re.compile(r"create extension if not exists pg_cron;\n.*", re.S)


def md5_cuerpo(sql: str) -> str:
    """md5(prosrc) de la primera función del texto, calculado como Postgres: el texto exacto entre `as $$` y `$$;`."""
    m = BODY_RE.search(sql)
    if not m:
        raise ValueError("no hay cuerpo de función")
    return hashlib.md5(m.group(1).encode()).hexdigest()


def hook(conector: str, web: str) -> str:
    """El bloque del hook de web3_02 (función + grants), con estos dos clientes."""
    bloque = HOOK_BLOQUE_RE.search(WEB3_02.read_text())
    if not bloque:
        raise SystemExit("web3_02: no encuentro el bloque del hook")
    return bloque.group(0).replace(STAGING_CONECTOR, conector).replace(STAGING_WEB, web)


def barrido(conector: str) -> str:
    bloque = BARRIDO_BLOQUE_RE.search(MCP0_04.read_text())
    if not bloque:
        raise SystemExit("mcp0_04: no encuentro el cuerpo")
    return bloque.group(0).replace(STAGING_CONECTOR, conector)


def verificar() -> int:
    casos = [
        ("hook de producción hoy (web3_02, conector nulo, web de producción)", md5_cuerpo(hook(NULO, PROD_WEB)), HOOK_PROD_ANTES),
        ("hook de staging (web3_02 tal cual)", md5_cuerpo(hook(STAGING_CONECTOR, STAGING_WEB)), HOOK_STAGING),
        ("barrido de staging (mcp0_04 tal cual)", md5_cuerpo(barrido(STAGING_CONECTOR)), BARRIDO_STAGING),
    ]
    mal = 0
    for nombre, got, esperado in casos:
        ok = got == esperado
        mal += not ok
        print(f"{'OK ' if ok else 'MAL'} {nombre}: {got} (medido: {esperado})")
    return 1 if mal else 0


def guarda_base(etiqueta: str, aceptados: list[str], web: str) -> str:
    lista = ", ".join(f"'{m}'" for m in aceptados)
    return f"""do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is null or cur not in ({lista}) then
    raise exception '{etiqueta}: el hook no es el esperado (md5 %). No se toca.', cur;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'yala_mcp_reader')
     or not exists (select 1 from pg_roles where rolname = 'yala_web') then
    raise exception '{etiqueta}: faltan los roles yala_mcp_reader o yala_web. No se toca.';
  end if;
  if not exists (select 1 from auth.oauth_clients where id = '{web}' and deleted_at is null) then
    raise exception '{etiqueta}: el cliente de Yala web ({web}) no está. No se toca.';
  end if;
end $$;
"""


def guarda_cliente(etiqueta: str, conector: str, vuelta: str) -> str:
    return f"""do $$
begin
  if not exists (select 1 from auth.oauth_clients c where c.id = '{conector}' and c.deleted_at is null
                   and c.client_type::text = 'confidential' and c.redirect_uris::text = '{vuelta}') then
    raise exception '{etiqueta}: {conector} no es un cliente OAuth confidencial vivo con la vuelta {vuelta}. No se toca.';
  end if;
end $$;
"""


def comprobar_hook(etiqueta: str, esperado: str) -> str:
    return f"""do $$
declare
  cur text;
begin
  select md5(p.prosrc) into cur from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
  if cur is distinct from '{esperado}' then
    raise exception '{etiqueta}: el hook está con md5 % y se esperaba {esperado}. No se sigue.', cur;
  end if;
end $$;
"""


def ficheros(conector: str, web: str, vuelta: str) -> dict[str, str]:
    antes = md5_cuerpo(hook(NULO, web))
    despues = md5_cuerpo(hook(conector, web))
    barrido_md5 = md5_cuerpo(barrido(conector))
    cab = (f"-- GENERADO por mcp/scripts/sql-conector-produccion.py: conector {conector}, web {web}.\n"
           "-- No editar: regenerar. Se aplica como UNA transacción (modo `aplicar` del script, o psql -1 -v ON_ERROR_STOP=1).\n")
    c01 = (cab + f"-- conector01: el hook reconoce al conector. md5 del hook {antes} → {despues}.\n"
           "-- La web sigue con `yala_web` y el login de la app sale intacto: solo cambia el id del conector.\n\n"
           + guarda_base("conector01", [antes, despues], web) + guarda_cliente("conector01", conector, vuelta)
           + "\n" + hook(conector, web) + "\n" + comprobar_hook("conector01", despues))
    c01r = (cab + f"-- conector01_rollback: el hook vuelve al de antes (conector nulo). md5 {despues} → {antes}.\n"
            "-- Desde aquí el conector no recibe token (403) y sus conexiones dejan de refrescar. La web no cambia.\n\n"
            + guarda_base("conector01_rollback", [despues, antes], web)
            + "\n" + hook(NULO, web) + "\n" + comprobar_hook("conector01_rollback", antes))
    c02 = (cab + f"-- conector02: barrido diario de las sesiones huérfanas del conector (qa/cloud/mcp0_04). md5 {barrido_md5}.\n"
           "-- Solo borra sesiones de Supabase cuyo cliente OAuth es el conector; las de la app y la web no las toca.\n\n"
           + comprobar_hook("conector02 (va después de conector01)", despues)
           + "\n" + barrido(conector) + """
do $$
begin
  if not exists (select 1 from cron.job where jobname = 'yala-mcp-sweep-connector-sessions') then
    raise exception 'conector02: no quedó el trabajo de cron. Se deshace.';
  end if;
end $$;
""")
    c02r = (cab + "-- conector02_rollback: quita el barrido del conector (su trabajo de cron y su función). pg_cron se\n"
            "-- queda: lo usa el barrido de la web.\n\n" + MCP0_04_ROLLBACK.read_text())
    return {"conector01_hook.sql": c01, "conector01_rollback.sql": c01r,
            "conector02_barrido.sql": c02, "conector02_rollback.sql": c02r,
            "_md5.json": json.dumps({"hook_antes": antes, "hook_despues": despues, "barrido": barrido_md5}, indent=2) + "\n"}


def generar(conector: str, carpeta: pathlib.Path, web: str = PROD_WEB, vuelta: str = PROD_VUELTA, voz: bool = True) -> int:
    if not UUID_RE.match(conector):
        print(f"El id del conector tiene que ser un uuid en minúsculas: {conector!r}", file=sys.stderr)
        return 2
    if conector in (NULO, PROD_WEB, STAGING_WEB) or (web == PROD_WEB and conector == STAGING_CONECTOR):
        print("Ese id no puede ser el del conector (es el nulo, el de una web o el conector de staging).", file=sys.stderr)
        return 2
    if verificar() if voz else any(m != e for m, e in (
            (md5_cuerpo(hook(NULO, PROD_WEB)), HOOK_PROD_ANTES), (md5_cuerpo(hook(STAGING_CONECTOR, STAGING_WEB)), HOOK_STAGING))):
        print("Las fuentes ya no dan los md5 medidos: no se genera nada.", file=sys.stderr)
        return 1
    carpeta.mkdir(parents=True, exist_ok=True)
    for nombre, texto in ficheros(conector, web, vuelta).items():
        (carpeta / nombre).write_text(texto)
    if voz:
        md5 = json.loads((carpeta / "_md5.json").read_text())
        print(f"hook: {md5['hook_antes']} → {md5['hook_despues']} · barrido: {md5['barrido']}")
        print(f"Escritos en {carpeta}: conector01_hook, conector01_rollback, conector02_barrido, conector02_rollback")
    return 0


# ─── Red: Management API de Supabase ────────────────────────────────────────────────────────────────────────────────

def _pat() -> str:
    return pathlib.Path("~/Secrets/yala-supabase-mgmt/pat").expanduser().read_text().strip()


def consulta(proyecto: str, sql: str) -> tuple[bool, object]:
    """POST /database/query, que ejecuta la consulta entera como UNA transacción. (ok, filas | texto del error)."""
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{proyecto}/database/query", method="POST",
        data=json.dumps({"query": sql}).encode(),
        headers={"Authorization": f"Bearer {_pat()}", "Content-Type": "application/json",
                 "User-Agent": "yala-sql-conector-produccion"})
    try:
        with urllib.request.urlopen(req, timeout=120) as f:
            return True, json.load(f)
    except urllib.error.HTTPError as e:
        return False, e.read().decode()


def config_auth(proyecto: str) -> dict:
    req = urllib.request.Request(f"https://api.supabase.com/v1/projects/{proyecto}/config/auth",
                                 headers={"Authorization": f"Bearer {_pat()}", "User-Agent": "yala-sql-conector-produccion"})
    with urllib.request.urlopen(req, timeout=60) as f:
        return json.load(f)


# Solo estas claves de la config de Auth: ninguna es un secreto (los id de cliente de Apple y Google son públicos).
CLAVES_AUTH = ["site_url", "uri_allow_list", "external_email_enabled", "external_apple_enabled", "external_apple_client_id",
               "external_google_enabled", "external_google_client_id", "hook_custom_access_token_enabled",
               "hook_custom_access_token_uri", "oauth_server_enabled", "oauth_server_allow_dynamic_registration",
               "oauth_server_authorization_path", "mfa_totp_enroll_enabled", "mfa_totp_verify_enabled",
               "sessions_inactivity_timeout"]

SQL_ESTADO = r"""
select 'hook' k, md5(p.prosrc) a,
  substring(p.prosrc from 'worker_client constant uuid := ''([0-9a-f-]+)''') b,
  substring(p.prosrc from 'web_client constant uuid := ''([0-9a-f-]+)''') c
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook'
union all select 'rol', rolname, null, null from pg_roles where rolname in ('yala_mcp_reader', 'yala_web')
union all select 'cliente', id::text, client_name || ' · ' || client_type::text, redirect_uris::text
  from auth.oauth_clients where deleted_at is null
union all select 'barrido', md5(p.prosrc), null, null from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'yala_mcp_sweep_connector_sessions'
union all select 'pg_cron', extversion, null, null from pg_extension where extname = 'pg_cron'
"""


def estado(nombre: str) -> int:
    proyecto = PROYECTOS[nombre]
    ok, filas = consulta(proyecto, SQL_ESTADO)
    if not ok:
        print("No se pudo leer la base:", str(filas)[:400])
        return 1
    for f in filas:
        print(f"{f['k']:8} {f['a']} {f.get('b') or ''} {f.get('c') or ''}".rstrip())
    ok_cron, jobs = consulta(proyecto, "select jobname, schedule from cron.job order by 1")
    print("cron     " + (", ".join(f"{j['jobname']} ({j['schedule']})" for j in jobs) if ok_cron else "sin pg_cron"))
    cfg = config_auth(proyecto)
    for k in CLAVES_AUTH:
        print(f"auth     {k} = {cfg.get(k)}")
    if nombre == "produccion":
        hook_md5 = next((f["a"] for f in filas if f["k"] == "hook"), None)
        print("\nHook como el 22-nov (conector nulo): " + ("SÍ" if hook_md5 == HOOK_PROD_ANTES else f"NO ({hook_md5})"))
    return 0


def _resultado(res: object, marca: str) -> str | None:
    m = re.search(marca + r" (.*?)(?:\\n|\")", str(res))
    return m.group(1) if m else None


def ensayo(proyecto: str, carpeta: pathlib.Path) -> int:
    """Aplica → vuelve atrás → reaplica → vuelve atrás, y un RAISE final lo deshace todo. Nada se confirma."""
    leer = lambda n: f"-- {n}\n{(carpeta / n).read_text()}\n"
    adelante = leer("conector01_hook.sql") + leer("conector02_barrido.sql")
    atras = leer("conector02_rollback.sql") + leer("conector01_rollback.sql")
    marca = lambda n: (f"insert into _ensayo select {n}, (select md5(p.prosrc) from pg_proc p join pg_namespace s on "
                       "s.oid = p.pronamespace where s.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook'), "
                       "(select count(*) from cron.job where jobname = 'yala-mcp-sweep-connector-sessions');\n")
    sql = ("create temp table _ensayo (n int, hook text, barrido bigint);\n" + marca(1) + adelante + marca(2) + atras
           + marca(3) + adelante + marca(4) + atras + marca(5)
           + "do $f$ declare r text; begin select string_agg(n || ':' || hook || ':' || barrido, ' ' order by n) into r"
             " from _ensayo; raise exception 'ENSAYO_RESULTADO %', r; end $f$;\n")
    ok, res = consulta(proyecto, sql)
    if ok:
        print("MAL: la consulta terminó sin el RAISE final, y eso quiere decir que se confirmó:", str(res)[:300])
        return 1
    r = _resultado(res, "ENSAYO_RESULTADO")
    if not r:
        print("El ensayo se cortó antes del final (la transacción se deshizo igual). Error de Postgres:")
        print(str(res)[:1500])
        return 1
    md5 = json.loads((carpeta / "_md5.json").read_text())
    pasos = {int(n): (h, int(b)) for n, h, b in (t.split(":") for t in r.split())}
    print(" · ".join(f"{n}: hook {h[:8]}… barrido {b}" for n, (h, b) in sorted(pasos.items())))
    bien = (pasos[1] == pasos[3] == pasos[5] and pasos[2] == pasos[4] == (md5["hook_despues"], 1)
            and pasos[1] == (md5["hook_antes"], 0))
    print("ENSAYO OK: aplica, vuelve atrás a lo de antes y se reaplica igual; nada confirmado" if bien
          else "ENSAYO CON FALLOS")
    return 0 if bien else 1


def aplicar(proyecto: str, fichero: pathlib.Path) -> int:
    ok, res = consulta(proyecto, fichero.read_text())
    print(("APLICADO " if ok else "NO APLICADO (la transacción se deshizo) ") + fichero.name)
    if not ok:
        print(str(res)[:1500])
    return 0 if ok else 1


# ─── Ensayo de punta a punta en staging ─────────────────────────────────────────────────────────────────────────────

def _sondas(web: str, conector: str) -> str:
    """Qué devuelve el hook a cuatro tokens: la app (sin cliente), la web, el conector y un cliente ajeno."""
    llamar = lambda claims: f"public.yala_mcp_access_token_hook(jsonb_build_object('claims', {claims}))"
    app = "jsonb_build_object('sub', 'x', 'role', 'authenticated')"
    cliente = lambda cid: f"jsonb_build_object('sub', 'x', 'role', 'authenticated', 'client_id', '{cid}')"
    rol = lambda claims: f"coalesce({llamar(claims)}->'claims'->>'role', {llamar(claims)}->'error'->>'http_code')"
    return f"concat_ws('/', {rol(app)}, {rol(cliente(web))}, {rol(cliente(conector))}, {rol(cliente(CLIENTE_FALSO))})"


def ensayo_staging() -> int:
    """En staging, en UNA transacción que un RAISE final deshace (staging no cambia ni un segundo):

    1. staging tal cual (hook de web3_02 con su conector y su barrido);
    2. las marchas atrás generadas → staging queda como producción HOY: conector nulo, sin barrido, la web intacta;
    3. el SQL generado → staging vuelve a ser exactamente el de partida (misma huella, hook y barrido);
    4. otra vez atrás y 5. otra vez adelante, con conector01 aplicado dos veces (idempotente).
    En cada paso se llama al hook con cuatro tokens: app (sigue `authenticated`), web (`yala_web`), conector y ajeno.
    Aparte, dos negativos en su propia transacción: el SQL de PRODUCCIÓN contra staging y un id que no es el cliente.
    """
    sys.path.insert(0, str(ROOT / "webapp" / "supabase"))
    import ciclo_staging  # la huella de todo lo que toca Yala web: roles, funciones, permisos, políticas y su cron

    tmp = pathlib.Path(tempfile.mkdtemp(prefix="ensayo-conector-"))
    if generar(STAGING_CONECTOR, tmp / "staging", web=STAGING_WEB, vuelta=STAGING_VUELTA, voz=False):
        return 1
    leer = lambda d, n: f"-- {n}\n{(d / n).read_text()}\n"
    st = tmp / "staging"
    adelante = leer(st, "conector01_hook.sql") + leer(st, "conector02_barrido.sql")
    atras = leer(st, "conector02_rollback.sql") + leer(st, "conector01_rollback.sql")
    paso = lambda n, nombre: (
        f"insert into _e select {n}, '{nombre}', pg_temp.huella(), pg_temp.hook(), pg_temp.restos_web(), "
        "(select count(*) from cron.job where jobname = 'yala-mcp-sweep-connector-sessions'), "
        "coalesce((select md5(p.prosrc) from pg_proc p join pg_namespace s on s.oid = p.pronamespace "
        "where s.nspname = 'public' and p.proname = 'yala_mcp_sweep_connector_sessions'), 'sin_barrido'), "
        f"{_sondas(STAGING_WEB, STAGING_CONECTOR)};\n")
    sql = (ciclo_staging.HUELLA
           + "create temp table _e (n int, paso text, huella text, hook text, restos text, cron bigint, barrido text, sondas text);\n"
           + paso(1, "staging") + atras + paso(2, "como_produccion") + adelante + paso(3, "con_conector")
           + atras + paso(4, "otra_vez_atras") + adelante + leer(st, "conector01_hook.sql") + paso(5, "reaplicado")
           + "do $f$ declare r text; begin select string_agg(n || '=' || paso || '|' || huella || '|' || hook || '|' || "
             "coalesce(nullif(restos, ''), '-') || '|' || cron || '|' || barrido || '|' || sondas, ' ;; ' order by n) "
             "into r from _e; raise exception 'ENSAYO_STAGING %', r; end $f$;\n")
    ok, res = consulta(PROYECTOS["staging"], sql)
    if ok:
        print("MAL: terminó sin el RAISE final: se confirmó en staging.", str(res)[:300])
        return 1
    r = _resultado(res, "ENSAYO_STAGING")
    if not r:
        print("El ensayo se cortó antes del final (deshecho igual). Error de Postgres:\n" + str(res)[:1500])
        return 1
    f = {}
    for trozo in r.split(" ;; "):
        n, resto = trozo.split("=", 1)
        nombre, huella, hook_md5, restos, cron, barrido_md5, sondas = resto.split("|")
        f[int(n)] = dict(huella=huella, hook=hook_md5, restos=restos, cron=int(cron), barrido=barrido_md5, sondas=sondas)
        print(f"{n}. {nombre}: huella {huella[:8]}… · hook {hook_md5[:8]}… · barrido {barrido_md5[:8]} (cron {cron}) · "
              f"app/web/conector/ajeno = {sondas}")
    md5 = json.loads((st / "_md5.json").read_text())
    checks = [
        ("staging partía del hook de web3_02 y de su barrido",
         f[1]["hook"] == HOOK_STAGING and f[1]["barrido"] == BARRIDO_STAGING and f[1]["cron"] == 1),
        ("el «después» generado ES el hook que staging corre hoy (y con el que su web entra)",
         md5["hook_despues"] == HOOK_STAGING and md5["barrido"] == BARRIDO_STAGING),
        ("como producción: hook con el conector nulo y sin barrido",
         f[2]["hook"] == md5["hook_antes"] and f[2]["cron"] == 0 and f[2]["barrido"] == "sin_barrido"),
        ("como producción: lo de la web, intacto (mismos restos: rol, funciones, políticas, cron)",
         f[2]["restos"] == f[1]["restos"] != "-"),
        ("como producción: app authenticated · web yala_web · conector 403 · ajeno 403",
         f[2]["sondas"] == "authenticated/yala_web/403/403"),
        ("con el conector: huella, hook y barrido idénticos a los de partida",
         f[3]["huella"] == f[1]["huella"] and f[3]["hook"] == HOOK_STAGING and f[3]["barrido"] == BARRIDO_STAGING and f[3]["cron"] == 1),
        ("con el conector: app authenticated · web yala_web · conector yala_mcp_reader · ajeno 403",
         f[3]["sondas"] == "authenticated/yala_web/yala_mcp_reader/403"),
        ("la segunda marcha atrás deja lo mismo que la primera",
         f[4]["huella"] == f[2]["huella"] and f[4]["hook"] == f[2]["hook"] and f[4]["sondas"] == f[2]["sondas"]),
        ("reaplicar (conector01 dos veces) vuelve a la huella de partida",
         f[5]["huella"] == f[1]["huella"] and f[5]["sondas"] == f[3]["sondas"]),
    ]
    # Negativos, cada uno en su transacción; si una guarda no abortara, el RAISE del final lo deshace igual.
    no_aborto = "\ndo $f$ begin raise exception 'NO_ABORTO'; end $f$;\n"
    generar(CLIENTE_FALSO, tmp / "produccion", voz=False)
    ok_p, res_p = consulta(PROYECTOS["staging"], (tmp / "produccion" / "conector01_hook.sql").read_text() + no_aborto)
    checks.append(("el SQL de PRODUCCIÓN aborta sobre un hook que no es el de producción",
                   not ok_p and "el hook no es el esperado" in str(res_p)))
    generar(CLIENTE_FALSO, tmp / "falso", web=STAGING_WEB, vuelta=STAGING_VUELTA, voz=False)
    ok_c, res_c = consulta(PROYECTOS["staging"], atras + leer(tmp / "falso", "conector01_hook.sql") + no_aborto)
    checks.append(("un id que no es un cliente confidencial con la vuelta del conector aborta",
                   not ok_c and "no es un cliente OAuth confidencial" in str(res_c)))
    ok_o, res_o = consulta(PROYECTOS["staging"], atras + leer(st, "conector02_barrido.sql") + no_aborto)
    checks.append(("el barrido no se aplica sin el hook del conector",
                   not ok_o and "va después de conector01" in str(res_o)))
    print()
    for nombre, bien in checks:
        print(f"{'OK ' if bien else 'MAL'} {nombre}")
    todo = all(b for _, b in checks)
    print("\nENSAYO EN STAGING OK: nada confirmado (todas las transacciones se deshicieron)" if todo
          else "\nENSAYO EN STAGING CON FALLOS")
    return 0 if todo else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--verificar"]:
        sys.exit(verificar())
    if len(a) == 3 and a[0] == "generar":
        sys.exit(generar(a[1], pathlib.Path(a[2]).expanduser()))
    if len(a) in (1, 2) and a[0] == "estado":
        sys.exit(estado(a[1] if len(a) == 2 else "produccion"))
    if len(a) == 3 and a[0] in ("ensayo", "aplicar") and a[1] in PROYECTOS:
        fn = ensayo if a[0] == "ensayo" else aplicar
        sys.exit(fn(PROYECTOS[a[1]], pathlib.Path(a[2]).expanduser()))
    if a == ["ensayo-staging"]:
        sys.exit(ensayo_staging())
    print(__doc__, file=sys.stderr)
    sys.exit(2)
