#!/bin/bash
# hlc01-cap-staging-probe.sh — mide en STAGING, por REST y con el usuario de test A, que el tope a un HLC futuro
# (`hlc01_cap_future_hlc.sql`) está puesto en los RPC del canal personal, cuyo cuerpo no vive en el repo.
#
# Lo que mide, con una fila `tags` y una key de preferencias nuevas en cada corrida:
#   1. `apply_delta` con un HLC un mes por delante → `applied`, y lo GUARDADO queda en ≤ now()+60 s con su
#      contador y nodo.
#   2. Un upsert de «otro dispositivo» con HLC now()+90 s → `applied`: ya no pierde contra el adelantado.
#   3. `apply_pref` con un HLC un mes por delante → guardado acotado.
# Sin la migración, (1) guarda el HLC entero y (2) sale `noop/all_units_stale`: es el control negativo, y es lo que
# esta sonda midió el 2026-10-07 antes de aplicar (Paso 0 del encargo).
#
# Deja en staging una fila `tags` borrada (tombstone) y una key `zz_hlc01_probe_*` del usuario A: no se pueden
# borrar (DELETE revocado), y no las baja ningún teléfono real.
#
# Uso:  bash qa/cloud/hlc01-cap-staging-probe.sh      → «hlc01-staging: N/N PASS»
# Env:  ~/Secrets/yala-supabase-test/test-users.env (USER_A_EMAIL, USER_A_PASS). SUPABASE_URL/SUPABASE_ANON_KEY opcionales.
set -euo pipefail

ENV_FILE="${HOME}/Secrets/yala-supabase-test/test-users.env"
[ -f "$ENV_FILE" ] || { echo "falta $ENV_FILE"; exit 2; }
set -a; . "$ENV_FILE"; set +a

URL="${SUPABASE_URL:-https://fostjbbwstyuunmmefuk.supabase.co}"
ANON="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg}"

export URL ANON
python3 -I - <<'PY'
import datetime, json, os, urllib.request, uuid

URL, ANON = os.environ["URL"], os.environ["ANON"]

def req(path, body=None, method="POST", jwt=None):
    r = urllib.request.Request(URL + path, method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={"apikey": ANON, "Authorization": "Bearer " + (jwt or ANON), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

st, tok = req("/auth/v1/token?grant_type=password",
              {"email": os.environ["USER_A_EMAIL"], "password": os.environ["USER_A_PASS"]})
assert st == 200, f"login A: {st} {tok}"
JWT = tok["access_token"]

def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{dt.microsecond // 1000:03d}Z"

def hlc(off, counter, node):
    return f"{iso(datetime.datetime.now(datetime.timezone.utc) + off)}-{counter:04x}-{node}"

def capped(h):
    now = datetime.datetime.now(datetime.timezone.utc)
    return iso(now + datetime.timedelta(seconds=50)) <= h[:24] <= iso(now + datetime.timedelta(seconds=75))

results = []
def check(name, cond, detail=""):
    results.append(cond)
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f" — {detail}"))

sid = str(uuid.uuid4())
month = datetime.timedelta(days=30)
fut = hlc(month, 7, "00000000000000aa")
st, out = req("/rest/v1/rpc/apply_delta", {"p_entity": "tags", "p_sync_id": sid, "p_op": "upsert",
    "p_fields": {"name": {"name": "zz-hlc01-A"}}, "p_field_hlcs": {"name": fut}, "p_row_hlc": fut,
    "p_schema_version": 1}, jwt=JWT)
check("apply_delta: el cambio del adelantado entra", st == 200 and out.get("noop") is False, f"{st} {out}")

st, rows = req(f"/rest/v1/tags?sync_id=eq.{sid}&select=hlc,field_hlcs,name", method="GET", jwt=JWT)
row = rows[0] if st == 200 and rows else {}
check("apply_delta: guardado acotado a now()+60 s, con contador y nodo",
      bool(row) and capped(row["hlc"]) and row["hlc"].endswith("-0007-00000000000000aa")
      and capped(row["field_hlcs"]["name"]), str(row))

later = hlc(datetime.timedelta(seconds=90), 0, "00000000000000bb")
st, out = req("/rest/v1/rpc/apply_delta", {"p_entity": "tags", "p_sync_id": sid, "p_op": "upsert",
    "p_fields": {"name": {"name": "zz-hlc01-B"}}, "p_field_hlcs": {"name": later}, "p_row_hlc": later,
    "p_schema_version": 1}, jwt=JWT)
check("apply_delta: el otro dispositivo, pasado el minuto, gana", st == 200 and out.get("noop") is False, f"{st} {out}")

st, out = req("/rest/v1/rpc/apply_delta", {"p_entity": "tags", "p_sync_id": sid, "p_op": "tombstone",
    "p_fields": {}, "p_field_hlcs": {}, "p_row_hlc": hlc(datetime.timedelta(seconds=95), 0, "00000000000000bb"),
    "p_schema_version": 1}, jwt=JWT)

key = "zz_hlc01_probe_" + datetime.datetime.now().strftime("%Y%m%d%H%M%S")
st, out = req("/rest/v1/rpc/apply_pref", {"p_key": key, "p_value": "A", "p_hlc": hlc(month, 3, "00000000000000aa")}, jwt=JWT)
st2, rows = req(f"/rest/v1/user_preferences?key=eq.{key}&select=hlc", method="GET", jwt=JWT)
h = rows[0]["hlc"] if st2 == 200 and rows else ""
check("apply_pref: guardado acotado a now()+60 s", st == 200 and capped(h) and h.endswith("-0003-00000000000000aa"), f"{st} {out} {h}")

n = len(results); ok = sum(results)
print(f"hlc01-staging: {ok}/{n} PASS")
raise SystemExit(0 if ok == n else 1)
PY
