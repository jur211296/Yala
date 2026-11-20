#!/bin/bash
# g32_01-staging-probe.sh — el logo propio de un pago planificado va y vuelve entre DOS teléfonos de la misma cuenta
# (dos nodos de HLC del usuario de test A) por el Worker y el Storage de STAGING desplegados.
#
# Lo que mide, con un pago y dos fotos nuevas en cada corrida:
#   1. `/config` y el pull v7 anuncian `manifestVersion: 7`.
#   2. El nodo 1 sube la foto al bucket privado (su carpeta) y el pago con `custom_logo_ref` (v7) → `applied`.
#   3. El nodo 2 baja la referencia con v7 (y su unidad); con v6 la fila baja sin ella (un teléfono con 2.2 no la ve).
#   4. El nodo 2 encuentra la foto en la lista de la carpeta y la baja byte a byte.
#   5. Aislamiento: el usuario B no lista, no baja, no sube en la carpeta de A, no la borra; sin sesión, tampoco.
#   6. El bucket rechaza lo que no es JPEG.
#   7. El Merkle v7 y v6 contestan 200 y anuncian 7.
#   8. El nodo 2 cambia la foto (otra referencia) → el nodo 1 baja la nueva; el nodo 1 la quita → el nodo 2 baja `null`.
#   9. Limpieza: borra las dos fotos y tombstone del pago.
# Staging corre App Attest en `observe`: sin la cabecera de attest el Worker cuenta la petición y la deja pasar.
#
# Deja en staging un `scheduled_payments` borrado y sin foto del usuario A.
#
# Uso:  bash qa/cloud/g32_01-staging-probe.sh [staging|production-storage]   → «g32_01-staging: N/N PASS»
# Env:  ~/Secrets/yala-supabase-test/test-users.env (USER_A_EMAIL, USER_A_PASS, USER_B_EMAIL, USER_B_PASS).
set -euo pipefail

ENV_FILE="${HOME}/Secrets/yala-supabase-test/test-users.env"
[ -f "$ENV_FILE" ] || { echo "falta $ENV_FILE"; exit 2; }
set -a; . "$ENV_FILE"; set +a

URL="https://fostjbbwstyuunmmefuk.supabase.co"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"
GW="https://yala-gateway-staging.misty-surf-6866.workers.dev"
export URL ANON GW

python3 -I - <<'PY'
import base64, datetime, json, os, urllib.request, uuid

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

def login(user):
    st, tok = call(URL + "/auth/v1/token?grant_type=password",
                   {"email": os.environ[f"USER_{user}_EMAIL"], "password": os.environ[f"USER_{user}_PASS"]},
                   headers={"apikey": ANON})
    assert st == 200, f"login {user}: {st} {tok}"
    return tok

tokA, tokB = login("A"), login("B")
AUTH = {"Authorization": "Bearer " + tokA["access_token"]}
AUTH_B = {"Authorization": "Bearer " + tokB["access_token"]}
UID_A = tokA["user"]["id"].lower()
BUCKET = "scheduled-payment-logos"

def storage(method, path, data=None, auth=None, ctype="image/jpeg", json_body=None):
    h = {"apikey": ANON, "User-Agent": "yala-probe"}
    if auth:
        h.update(auth)
    body = data
    if json_body is not None:
        body = json.dumps(json_body).encode()
        h["Content-Type"] = "application/json"
    elif data is not None:
        h["Content-Type"] = ctype
        h["x-upsert"] = "true"
    r = urllib.request.Request(URL + "/storage/v1/" + path, method=method, data=body, headers=h)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()

def listing(auth):
    st, body = storage("POST", f"object/list/{BUCKET}", auth=auth,
                       json_body={"prefix": UID_A, "limit": 1000, "offset": 0})
    return st, (json.loads(body) if st == 200 else body)

# Un JPEG mínimo válido (1×1), distinto en cada foto por un segmento de comentario (COM) tras el SOI.
BASE_JPEG = base64.b64decode(
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////"
    "////////wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8Af//Z")
def jpeg(tag):
    payload = tag.encode()
    return BASE_JPEG[:2] + b"\xff\xfe" + (len(payload) + 2).to_bytes(2, "big") + payload + BASE_JPEG[2:]

NODE1, NODE2 = "00000000000000a1", "00000000000000b2"
counter = [0]
def hlc(node):
    counter[0] += 1
    now = datetime.datetime.now(datetime.timezone.utc)
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z-{counter[0]:04x}-{node}"

def push(delta, cap="v7"):
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
    print(("  ✓ " if cond else "  ✗ ") + name + ("" if cond else f" — {str(detail)[:300]}"))

# 1 · el Worker anuncia la v7
st, cfg = call(GW + "/config", method="GET")
check("/config anuncia manifestVersion 7", st == 200 and cfg["sync"]["manifestVersion"] == 7, cfg)
_, base, mv = pull_all(0, "v7")
check("el pull v7 anuncia manifest_version 7", mv == 7, mv)

# 2 · el nodo 1 sube la foto y el pago
sid = str(uuid.uuid4())
ref1, ref2 = f"{uuid.uuid4()}.jpg", f"{uuid.uuid4()}.jpg"
foto1, foto2 = jpeg("g32 foto 1 " + sid), jpeg("g32 foto 2 " + sid)
st, body = storage("POST", f"object/{BUCKET}/{UID_A}/{ref1}", data=foto1, auth=AUTH)
check("nodo 1 sube la foto a su carpeta", st == 200, (st, body))
now = datetime.datetime.now(datetime.timezone.utc)
h = hlc(NODE1)
fields = {"name": "g32_01 probe · colegio", "currency_code": "PEN",
          "next_due_date": now.strftime("%Y-%m-%dT%H:%M:%S.000Z"), "custom_logo_ref": ref1}
st, body = push({"entity_type": "scheduled_payments", "sync_id": sid, "op": "upsert", "fields": fields,
                 "field_hlcs": {k: h for k in fields}, "hlc": h, "client_mutation_id": str(uuid.uuid4())})
check("nodo 1 sube el pago con la referencia (v7) → applied",
      st == 200 and body["results"][0]["status"] == "applied", body)

def find(deltas):
    rows = [d for d in deltas if d["sync_id"] == sid]
    return rows[-1] if rows else None

# 3 · el nodo 2 la baja con v7; con v6 no
deltas, seq1, _ = pull_all(base, "v7")
row = find(deltas)
check("nodo 2 baja la referencia con v7", row is not None and row["fields"].get("custom_logo_ref") == ref1, row)
check("…con su unidad en field_hlcs", row is not None and row["field_hlcs"].get("custom_logo_ref") == h, row)
deltas6, _, _ = pull_all(base, "v6")
row6 = find(deltas6)
check("con v6 la fila baja sin la columna ni su unidad", row6 is not None
      and "custom_logo_ref" not in row6["fields"] and "custom_logo_ref" not in row6["field_hlcs"], row6)

# 4 · el nodo 2 encuentra la foto y la baja
st, files = listing(AUTH)
check("nodo 2 ve la foto en la lista de su carpeta", st == 200 and any(f.get("name") == ref1 for f in files), files)
st, data = storage("GET", f"object/authenticated/{BUCKET}/{UID_A}/{ref1}", auth=AUTH)
check("nodo 2 baja la foto byte a byte", st == 200 and data == foto1, st)

# 5 · aislamiento
st, files_b = listing(AUTH_B)
check("B no ve nada en la carpeta de A", st == 200 and not any(f.get("name") == ref1 for f in files_b), files_b)
st, _ = storage("GET", f"object/authenticated/{BUCKET}/{UID_A}/{ref1}", auth=AUTH_B)
check("B no baja la foto de A", st in (400, 403, 404), st)
st, _ = storage("POST", f"object/{BUCKET}/{UID_A}/{uuid.uuid4()}.jpg", data=foto1, auth=AUTH_B)
check("B no sube en la carpeta de A", st in (400, 403), st)
st, _ = storage("DELETE", f"object/{BUCKET}", auth=AUTH_B, json_body={"prefixes": [f"{UID_A}/{ref1}"]})
st2, data = storage("GET", f"object/authenticated/{BUCKET}/{UID_A}/{ref1}", auth=AUTH)
check("B no borra la foto de A", st2 == 200 and data == foto1, (st, st2))
st, _ = storage("GET", f"object/authenticated/{BUCKET}/{UID_A}/{ref1}", auth={"Authorization": "Bearer " + ANON})
check("sin sesión no se baja", st in (400, 403, 404), st)
st, _ = storage("GET", f"object/public/{BUCKET}/{UID_A}/{ref1}")
check("el bucket no es público", st in (400, 403, 404), st)

# 6 · solo JPEG
st, _ = storage("POST", f"object/{BUCKET}/{UID_A}/{uuid.uuid4()}.jpg", data=b"<html>", auth=AUTH, ctype="text/html")
check("el bucket rechaza lo que no es JPEG", st in (400, 415, 422), st)

# 7 · Merkle
for cap in ("v7", "v6"):
    st, m = call(GW + "/sync/merkle", method="GET", headers={**AUTH, "X-Yala-Capability-Set": cap})
    check(f"Merkle {cap} → 200 y anuncia 7", st == 200 and m.get("manifest_version") == 7, f"{st} {str(m)[:200]}")

# 8 · el nodo 2 cambia la foto y el nodo 1 la baja; el nodo 1 la quita
st, _ = storage("POST", f"object/{BUCKET}/{UID_A}/{ref2}", data=foto2, auth=AUTH)
h2 = hlc(NODE2)
st, body = push({"entity_type": "scheduled_payments", "sync_id": sid, "op": "upsert",
                 "fields": {"custom_logo_ref": ref2}, "field_hlcs": {"custom_logo_ref": h2}, "hlc": h2})
check("nodo 2 cambia la foto → applied", st == 200 and body["results"][0]["status"] == "applied", body)
deltas, seq2, _ = pull_all(seq1, "v7")
row = find(deltas)
check("nodo 1 baja la referencia nueva", row is not None and row["fields"].get("custom_logo_ref") == ref2, row)
check("…y el nombre del nodo 1 sigue", row is not None and row["fields"].get("name") == "g32_01 probe · colegio", row)
st, data = storage("GET", f"object/authenticated/{BUCKET}/{UID_A}/{ref2}", auth=AUTH)
check("nodo 1 baja la foto nueva", st == 200 and data == foto2, st)
h3 = hlc(NODE1)
st, body = push({"entity_type": "scheduled_payments", "sync_id": sid, "op": "upsert",
                 "fields": {"custom_logo_ref": None}, "field_hlcs": {"custom_logo_ref": h3}, "hlc": h3})
check("nodo 1 quita la foto → applied", st == 200 and body["results"][0]["status"] == "applied", body)
deltas, _, _ = pull_all(seq2, "v7")
row = find(deltas)
check("nodo 2 baja la referencia vacía (null)", row is not None and "custom_logo_ref" in row["fields"]
      and row["fields"]["custom_logo_ref"] is None, row)

# 9 · limpieza
st, _ = storage("DELETE", f"object/{BUCKET}", auth=AUTH,
                json_body={"prefixes": [f"{UID_A}/{ref1}", f"{UID_A}/{ref2}"]})
st2, files = listing(AUTH)
check("A borra sus dos fotos", st == 200 and st2 == 200
      and not any(f.get("name") in (ref1, ref2) for f in files), (st, files))
h4 = hlc(NODE1)
st, body = push({"entity_type": "scheduled_payments", "sync_id": sid, "op": "tombstone", "hlc": h4})
check("tombstone de limpieza → applied", st == 200 and body["results"][0]["status"] == "applied", body)

ok = sum(results)
print(f"g32_01-staging: {ok}/{len(results)} PASS")
raise SystemExit(0 if ok == len(results) else 1)
PY
