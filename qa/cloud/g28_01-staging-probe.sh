#!/bin/bash
# g28_01-staging-probe.sh — la receta de líneas (`tx_items.split_lines_raw`) va y vuelve entre DOS teléfonos por el
# Worker de STAGING desplegado, con el usuario de test A. Los dos «teléfonos» son dos nodos de HLC distintos sobre la
# misma cuenta, que es lo que distingue a dos aparatos para el backend.
#
# Lo que mide, con un movimiento nuevo en cada corrida:
#   1. `/config` anuncia `manifestVersion: 6`.
#   2. El nodo 1 sube el movimiento con su receta (v6) → `applied`.
#   3. El nodo 2 la baja con v6: misma receta y su unidad en `field_hlcs`.
#   4. El nodo 2 la baja con v5: ni la columna ni su unidad (un teléfono con 2.2 sin esta build no la ve).
#   5. El Merkle con v6 y con v5 contestan 200 y anuncian 6 (sin la columna en Postgres, el v6 daría 502).
#   6. El nodo 2 cambia la receta → el nodo 1 baja la del nodo 2 (la vuelta).
#   7. El nodo 1 la vacía → el nodo 2 baja `null` (vaciarla también viaja).
#   8. Limpieza: tombstone del movimiento.
# Staging corre App Attest en `observe`: sin la cabecera de attest el Worker cuenta la petición y la deja pasar.
#
# Deja en staging un `tx_items` borrado y sin receta del usuario A (DELETE revocado: no se puede borrar del todo).
#
# Uso:  bash qa/cloud/g28_01-staging-probe.sh      → «g28_01-staging: N/N PASS»
# Env:  ~/Secrets/yala-supabase-test/test-users.env (USER_A_EMAIL, USER_A_PASS).
set -euo pipefail

ENV_FILE="${HOME}/Secrets/yala-supabase-test/test-users.env"
[ -f "$ENV_FILE" ] || { echo "falta $ENV_FILE"; exit 2; }
set -a; . "$ENV_FILE"; set +a

URL="https://fostjbbwstyuunmmefuk.supabase.co"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
GW="https://yala-gateway-staging.misty-surf-6866.workers.dev"
export URL ANON GW

python3 -I - <<'PY'
import datetime, json, os, urllib.request, uuid

URL, ANON, GW = os.environ["URL"], os.environ["ANON"], os.environ["GW"]

def call(url, body=None, method="POST", headers=None):
    h = {"Content-Type": "application/json", "User-Agent": "yala-probe"}
    h.update(headers or {})
    r = urllib.request.Request(url, method=method, data=None if body is None else json.dumps(body).encode(), headers=h)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

st, tok = call(URL + "/auth/v1/token?grant_type=password",
               {"email": os.environ["USER_A_EMAIL"], "password": os.environ["USER_A_PASS"]},
               headers={"apikey": ANON})
assert st == 200, f"login A: {st} {tok}"
AUTH = {"Authorization": "Bearer " + tok["access_token"]}

NODE1, NODE2 = "00000000000000a1", "00000000000000b2"
counter = [0]
def hlc(node):
    counter[0] += 1
    now = datetime.datetime.now(datetime.timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z-{counter[0]:04x}-{node}"

def push(delta, cap="v6"):
    return call(GW + "/sync/push", {"deltas": [delta]}, headers={**AUTH, "X-Yala-Capability-Set": cap})

def pull_all(since, cap):
    out, cur = [], since
    while True:
        st, body = call(f"{GW}/sync/pull?since={cur}&limit=1000", method="GET",
                        headers={**AUTH, "X-Yala-Capability-Set": cap})
        assert st == 200, f"pull {cap}: {st} {body}"
        out += body["deltas"]
        if not body["deltas"] or body["max_server_seq"] == cur:
            return out, body["max_server_seq"], body.get("manifest_version")
        cur = body["max_server_seq"]

results = []
def check(name, cond, detail=""):
    results.append(cond)
    print(("  ✓ " if cond else "  ✗ ") + name + ("" if cond else f" — {detail}"))

# 1 · el Worker anuncia la v6
st, cfg = call(GW + "/config", method="GET")
check("/config anuncia manifestVersion 6", st == 200 and cfg["sync"]["manifestVersion"] == 6, cfg)

_, base, mv = pull_all(0, "v6")
check("el pull v6 anuncia manifest_version 6", mv == 6, mv)

sid = str(uuid.uuid4())
recipe1 = json.dumps({"v": 1, "lines": [{"kind": "transfer", "amount": "500"}, {"kind": "expense", "amount": "10"}]},
                     separators=(",", ":"))
now = datetime.datetime.now(datetime.timezone.utc)
h = hlc(NODE1)
fields = {"date": now.strftime("%Y-%m-%dT%H:%M:%S.000Z"), "local_day": now.strftime("%Y-%m-%d"),
          "currency_code": "PEN", "note": "g28_01 probe", "split_lines_raw": recipe1}
# 2 · el nodo 1 sube el movimiento con su receta
st, body = push({"entity_type": "tx_items", "sync_id": sid, "op": "upsert", "fields": fields,
                 "field_hlcs": {k: h for k in fields}, "hlc": h, "client_mutation_id": str(uuid.uuid4())})
check("nodo 1 sube la receta (v6) → applied", st == 200 and body["results"][0]["status"] == "applied", body)

def find(deltas):
    rows = [d for d in deltas if d["sync_id"] == sid]
    return rows[-1] if rows else None

# 3 · el nodo 2 la baja con v6
deltas, seq_after_1, _ = pull_all(base, "v6")
row = find(deltas)
check("nodo 2 baja la receta con v6", row is not None and row["fields"].get("split_lines_raw") == recipe1, row)
check("…con su unidad en field_hlcs", row is not None and row["field_hlcs"].get("split_lines_raw") == h, row)

# 4 · con v5 no la ve
deltas5, _, _ = pull_all(base, "v5")
row5 = find(deltas5)
check("con v5 la fila baja sin la columna", row5 is not None and "split_lines_raw" not in row5["fields"], row5)
check("…y sin su unidad", row5 is not None and "split_lines_raw" not in row5["field_hlcs"], row5)

# 5 · Merkle
for cap in ("v6", "v5"):
    st, m = call(GW + "/sync/merkle", method="GET", headers={**AUTH, "X-Yala-Capability-Set": cap})
    check(f"Merkle {cap} → 200 y anuncia 6", st == 200 and m.get("manifest_version") == 6, f"{st} {str(m)[:200]}")

# 6 · el nodo 2 cambia la receta y el nodo 1 la baja
recipe2 = json.dumps({"v": 1, "lines": [{"kind": "expense", "amount": "510"}]}, separators=(",", ":"))
h2 = hlc(NODE2)
st, body = push({"entity_type": "tx_items", "sync_id": sid, "op": "upsert", "fields": {"split_lines_raw": recipe2},
                 "field_hlcs": {"split_lines_raw": h2}, "hlc": h2})
check("nodo 2 cambia la receta → applied", st == 200 and body["results"][0]["status"] == "applied", body)
deltas, seq_after_2, _ = pull_all(seq_after_1, "v6")
row = find(deltas)
check("nodo 1 baja la receta del nodo 2", row is not None and row["fields"].get("split_lines_raw") == recipe2, row)
check("…y la nota del nodo 1 sigue", row is not None and row["fields"].get("note") == "g28_01 probe", row)

# 7 · el nodo 1 la vacía
h3 = hlc(NODE1)
st, body = push({"entity_type": "tx_items", "sync_id": sid, "op": "upsert", "fields": {"split_lines_raw": None},
                 "field_hlcs": {"split_lines_raw": h3}, "hlc": h3})
check("nodo 1 vacía la receta → applied", st == 200 and body["results"][0]["status"] == "applied", body)
deltas, _, _ = pull_all(seq_after_2, "v6")
row = find(deltas)
check("nodo 2 baja la receta vacía (null)", row is not None and "split_lines_raw" in row["fields"]
      and row["fields"]["split_lines_raw"] is None, row)

# 8 · limpieza
h4 = hlc(NODE1)
st, body = push({"entity_type": "tx_items", "sync_id": sid, "op": "tombstone", "hlc": h4})
check("tombstone de limpieza → applied", st == 200 and body["results"][0]["status"] == "applied", body)

ok = sum(results)
print(f"g28_01-staging: {ok}/{len(results)} PASS")
raise SystemExit(0 if ok == len(results) else 1)
PY
