#!/bin/bash
# g18_01-staging-probe.sh — mide en STAGING, por el Worker y con el usuario de test A, que la columna
# `accounts.parent_account_id` (g18_01) y el capability-set por versión (`manifest_version: 2`) funcionan de punta
# a punta: push, pull y Merkle, como los vería un teléfono 2.2 (`v2`) y uno 2.1 (`v1`).
#
# Lo que mide, con dos cuentas nuevas en cada corrida (una principal en PEN y su línea en USD):
#   1. El push de la línea con `parent_account_id` → `applied` (el Worker conoce la columna).
#   2. El pull con `v2` baja la línea CON el enlace y anuncia `manifest_version: 2`.
#   3. El pull con `v1` baja la línea SIN la columna ni su unidad (un 2.1 no la ve).
#   4. El Merkle responde 200 con `v1` y con `v2` (la base tiene la columna) y anuncia la versión; el hash de
#      `accounts` difiere entre los dos (v1 hashea sin la columna) y el de `tx_items` no.
#   5. Lo que guarda la base es el UUID crudo, sin FK: una línea cuya principal no existe también entra.
#   6. Un push «de 2.1» (sin la columna) sobre la línea no borra el enlace (ausencia = no la toqué).
# Deja dos o tres cuentas `zz-g18-*` borradas (tombstone) del usuario A: no se pueden borrar (DELETE revocado).
#
# Uso:  bash qa/cloud/g18_01-staging-probe.sh      → «g18_01-staging: N/N PASS»
# Env:  ~/Secrets/yala-supabase-test/test-users.env (USER_A_EMAIL, USER_A_PASS). WORKER_URL/SUPABASE_URL opcionales.
set -euo pipefail

ENV_FILE="${HOME}/Secrets/yala-supabase-test/test-users.env"
[ -f "$ENV_FILE" ] || { echo "falta $ENV_FILE"; exit 2; }
set -a; . "$ENV_FILE"; set +a

URL="${SUPABASE_URL:-https://fostjbbwstyuunmmefuk.supabase.co}"
ANON="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg}"
WORKER="${WORKER_URL:-https://yala-gateway-staging.misty-surf-6866.workers.dev}"

export URL ANON WORKER
python3 -I - <<'PY'
import datetime, json, os, urllib.request, uuid

URL, ANON, WORKER = os.environ["URL"], os.environ["ANON"], os.environ["WORKER"]

def call(url, body=None, method="POST", headers=None):
    r = urllib.request.Request(url, method=method,
        data=None if body is None else json.dumps(body).encode(), headers=headers or {})
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

st, tok = call(URL + "/auth/v1/token?grant_type=password",
               {"email": os.environ["USER_A_EMAIL"], "password": os.environ["USER_A_PASS"]},
               headers={"apikey": ANON, "Content-Type": "application/json"})
assert st == 200, f"login A: {st} {tok}"
JWT = tok["access_token"]

def worker(path, body=None, method="POST", cap=None):
    # Con el User-Agent de urllib, Cloudflare responde 403 «error code: 1010» antes de llegar al Worker.
    h = {"Authorization": "Bearer " + JWT, "Content-Type": "application/json", "User-Agent": "yala-qa-probe/g18_01"}
    if cap: h["X-Yala-Capability-Set"] = cap
    return call(WORKER + path, body, method, h)

def rest(path):
    return call(URL + path, method="GET", headers={"apikey": ANON, "Authorization": "Bearer " + JWT})

def hlc(counter):
    now = datetime.datetime.now(datetime.timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z-{counter:04x}-00000000000000a1"

results = []
def check(name, cond, detail=""):
    results.append(bool(cond))
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f" — {detail}"))

st, seq = rest("/rest/v1/sync_seq_counters?select=seq")
since = seq[0]["seq"] if st == 200 and seq else 0

principal, line, orphan = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
missing_parent = str(uuid.uuid4())
def account(sync_id, name, currency, parent, counter):
    h = hlc(counter)
    fields = {"name": name, "currency_code": currency, "color_hex": "#6366F1", "icon_name": "creditcard",
              "type": "creditCard", "account_number": None, "adjustment_mode": "manual",
              "exclude_from_statistics": False, "is_archived": False, "is_system_account": False,
              "credit_card_payment_reminder": False, "credit_card_payment_day": 5}
    if parent is not False:
        fields["parent_account_id"] = parent
    return {"entity_type": "accounts", "sync_id": sync_id, "op": "upsert", "fields": fields,
            "field_hlcs": {k: h for k in fields}, "hlc": h, "schema_version": 1}

st, out = worker("/sync/push", {"deltas": [account(principal, "zz-g18-visa", "PEN", None, 1),
                                         account(line, "zz-g18-visa-usd", "USD", principal, 2),
                                         account(orphan, "zz-g18-huerfana", "EUR", missing_parent, 3)]},
                 cap="v2")
statuses = [r.get("status") for r in out.get("results", [])] if isinstance(out, dict) else out
check("push v2: la principal, la línea y la huérfana entran", st == 200 and statuses == ["applied"] * 3, f"{st} {out}")

def pull(cap):
    st, out = worker(f"/sync/pull?since={since}&limit=1000", method="GET", cap=cap)
    rows = {d["sync_id"]: d for d in out.get("deltas", [])} if st == 200 else {}
    return st, out, rows

st, out, rows = pull("v2")
check("pull v2: anuncia manifest_version 2", st == 200 and out.get("manifest_version") == 2, f"{st} {out if st != 200 else out.get('manifest_version')}")
d = rows.get(line, {})
check("pull v2: la línea baja con su enlace y su unidad",
      d.get("fields", {}).get("parent_account_id") == principal and "parent_account_id" in d.get("field_hlcs", {}), str(d))
check("pull v2: la principal baja con el enlace a NULL",
      "parent_account_id" in rows.get(principal, {}).get("fields", {})
      and rows[principal]["fields"]["parent_account_id"] is None, str(rows.get(principal)))
check("pull v2: la huérfana conserva el UUID crudo (sin FK)",
      rows.get(orphan, {}).get("fields", {}).get("parent_account_id") == missing_parent, str(rows.get(orphan)))

st, out, rows = pull("v1")
d = rows.get(line, {})
check("pull v1: la línea baja SIN la columna ni su unidad (lo que ve un 2.1)",
      st == 200 and d and "parent_account_id" not in d.get("fields", {})
      and "parent_account_id" not in d.get("field_hlcs", {}) and d["fields"].get("name") == "zz-g18-visa-usd", str(d))

merkle = {}
for cap in ("v1", "v2"):
    st, out = worker("/sync/merkle", method="GET", cap=cap)
    merkle[cap] = out if st == 200 else {}
    check(f"merkle {cap}: 200, eco {cap} y manifest_version 2",
          st == 200 and out.get("capability_set") == cap and out.get("manifest_version") == 2,
          f"{st} {str(out)[:200]}")
acc = {cap: merkle[cap].get("entities", {}).get("accounts", {}) for cap in merkle}
check("merkle: el hash de accounts cambia entre v1 y v2 (v1 hashea SIN la columna), el de tx_items no",
      acc.get("v1", {}).get("hash") and acc.get("v1", {}).get("hash") != acc.get("v2", {}).get("hash")
      and acc["v1"].get("count") == acc["v2"].get("count")
      and merkle["v1"].get("entities", {}).get("tx_items") == merkle["v2"].get("entities", {}).get("tx_items"),
      f"{acc}")

h = hlc(9)
st, out = worker("/sync/push", {"deltas": [{"entity_type": "accounts", "sync_id": line, "op": "upsert",
    "fields": {"name": "zz-g18-visa-usd-2"}, "field_hlcs": {"name": h}, "hlc": h, "schema_version": 1}]}, cap="v1")
st2, rows = rest(f"/rest/v1/accounts?sync_id=eq.{line}&select=name,parent_account_id")
row = rows[0] if st2 == 200 and rows else {}
check("push de 2.1 (sin la columna): no borra el enlace",
      st == 200 and row.get("name") == "zz-g18-visa-usd-2" and row.get("parent_account_id") == principal, f"{st} {out} {row}")

for sid in (line, principal, orphan):
    t = hlc(20)
    worker("/sync/push", {"deltas": [{"entity_type": "accounts", "sync_id": sid, "op": "tombstone",
                                      "fields": {}, "field_hlcs": {}, "hlc": t, "schema_version": 1}]}, cap="v2")

n = len(results); ok = sum(results)
print(f"g18_01-staging: {ok}/{n} PASS")
raise SystemExit(0 if ok == n else 1)
PY
