#!/bin/bash
# g30_01-staging-probe.sh — mide en STAGING, por la vía real (Worker + JWT de usuario), lo que pide la card vx6f
# (2026-11-03): la edición de un gasto desde un teléfono que no conoce el autor (todo iOS hasta 2.1) deja el autor en NULL,
# y no en el de antes.
#
#   1. A (app 2.2) crea un gasto con su autor: A lo baja con `X-Yala-Capability-Set: v3` con autor = A.
#   2. B lo edita como un 2.1: la unidad del importe (`gmoney`) SIN la unidad del autor → A lo baja con autor NULL
#      (la clave presente y nula: con la clave presente, la app manda el servidor y cae al pagador) y con el importe
#      nuevo.
#   3. CONTROL: B lo edita como un 2.2 (importe + su autor, mismo HLC) → autor = B.
#   4. CONTROL: A cambia como un 2.1 solo `is_settled` (no es el formulario) → el autor sigue siendo B.
#
# El grupo acaba en el custodio (relevo en `finally`, molde de `g29_01-staging-probe.sh`): el pull de A y B no crece.
# Nunca toca producción: las URLs están fijadas a staging y se comprueban.
#
# Uso:  GROUPS_ENC_KEY="$(cat ~/Secrets/yala-groups-enc/staging.key)" bash qa/cloud/g30_01-staging-probe.sh
# Env:  ~/Secrets/yala-supabase-test/test-users.env (USER_A_*, USER_B_*, USER_CUSTODIO_*).
set -euo pipefail

ENV_FILE="${HOME}/Secrets/yala-supabase-test/test-users.env"
[ -f "$ENV_FILE" ] || { echo "falta $ENV_FILE"; exit 2; }
set -a; . "$ENV_FILE"; set +a
[ -n "${GROUPS_ENC_KEY:-}" ] || { echo "falta GROUPS_ENC_KEY (llave de cifrado de grupos de STAGING)"; exit 2; }

URL="https://fostjbbwstyuunmmefuk.supabase.co"
GW="https://yala-gateway-staging.misty-surf-6866.workers.dev"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"

export URL GW ANON
python3 -I - <<'PY'
import base64, datetime, json, os, sys, urllib.error, urllib.parse, urllib.request, uuid

URL, GW, ANON, KEY = os.environ["URL"], os.environ["GW"], os.environ["ANON"], os.environ["GROUPS_ENC_KEY"]
assert "fostjbbwstyuunmmefuk" in URL and "staging" in GW, "solo staging"

def http(base, path, body=None, jwt=None, method="POST", headers=None):
    h = {"apikey": ANON, "Content-Type": "application/json", "User-Agent": "Yala/probe-g30_01"}
    if jwt: h["Authorization"] = f"Bearer {jwt}"
    h.update(headers or {})
    r = urllib.request.Request(base + path, method=method,
        data=None if body is None else json.dumps(body).encode(), headers=h)
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except Exception: return e.code, raw

def login(email, pw):
    s, d = http(URL, "/auth/v1/token?grant_type=password", {"email": email, "password": pw})
    assert s == 200, f"login {email}: {s} {d}"
    tok = d["access_token"]; p = tok.split(".")[1]; p += "=" * (-len(p) % 4)
    return tok, json.loads(base64.urlsafe_b64decode(p))["sub"]

def rpc(jwt, fn, args): return http(URL, f"/rest/v1/rpc/{fn}", args, jwt)

def must(label, res):
    s, d = res
    if s != 200: raise SystemExit(f"preparación falló en {label}: {s} {d}")
    return d

t0 = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
def hlc(step, node):
    return (t0 + datetime.timedelta(seconds=step)).strftime("%Y-%m-%dT%H:%M:%S.000Z") + f"-0000-00000000000000{node}"

passed = failed = 0
def check(label, ok, detail=""):
    global passed, failed
    if ok: passed += 1; print(f"  PASS  {label}")
    else:  failed += 1; print(f"  FAIL  {label} {detail}")

def gw_push(jwt, deltas):
    return http(GW, "/groups/push", {"deltas": deltas}, jwt)

def gw_pull(jwt, gid, capability):
    q = urllib.parse.urlencode({"cursors": json.dumps({gid: 0}), "limit": 500})
    h = {} if capability is None else {"X-Yala-Capability-Set": capability}
    return http(GW, f"/groups/pull?{q}", None, jwt, method="GET", headers=h)

def delta(gid, sid, fields, units, h):
    return {"entity_type": "split_expenses", "group_id": gid, "sync_id": sid, "op": "upsert", "fields": fields,
            "field_hlcs": {u: h for u in units}, "hlc": h, "client_mutation_id": str(uuid.uuid4()), "schema_version": 1}

def result_status(res):
    s, d = res
    if s != 200 or not isinstance(d, dict) or not d.get("results"): return f"http {s} {d}"
    r = d["results"][0]
    return r.get("status") if r.get("status") != "rejected" else f"rejected:{r.get('reason')}"

def find(pull_res, sid):
    s, d = pull_res
    if s != 200: return None
    for x in d.get("deltas", []):
        if x.get("entity_type") == "split_expenses" and x.get("sync_id") == sid: return x
    return None

A, subA = login(os.environ["USER_A_EMAIL"], os.environ["USER_A_PASS"])
B, subB = login(os.environ["USER_B_EMAIL"], os.environ["USER_B_PASS"])
C, subC = login(os.environ["USER_CUSTODIO_EMAIL"], os.environ["USER_CUSTODIO_PASS"])

def handover(gid, b_joined):
    """Relevo al custodio, a mejor esfuerzo: B sale, el custodio entra y hereda el grupo, A sale."""
    if b_joined: rpc(B, "leave_group", {"p_group_id": gid})
    try:
        token2 = must("invite custodio", rpc(A, "create_group_invite", {"p_group_id": gid}))
        must("join custodio", rpc(C, "join_group", {"p_token": token2, "p_display_name": "Custodio", "p_key": KEY}))
        must("approve custodio", rpc(A, "approve_member", {"p_group_id": gid, "p_member_key": subC}))
        tr = must("transfer", rpc(A, "transfer_group_ownership", {"p_group_id": gid}))
        if not (isinstance(tr, dict) and tr.get("new_owner_user_id") == subC):
            raise SystemExit(f"el traspaso no fue al custodio: {tr}")
        must("A leave", rpc(A, "leave_group", {"p_group_id": gid}))
    except BaseException as e:
        print(f"  AVISO  el relevo al custodio no terminó ({e}); el grupo {gid} queda en staging con A como dueña")
        raise

s, cfg = http(GW, "/config", None, None, method="GET")
check("0. el Worker de staging anuncia groupsManifestVersion 3",
      s == 200 and cfg.get("sync", {}).get("groupsManifestVersion") == 3, f"{s} {cfg}")

gid = str(uuid.uuid4())
must("create_group", rpc(A, "create_group", {"p_group_id": gid, "p_name": "zz-g30-autor-v2", "p_currency_code": "USD",
     "p_icon_name": "cart", "p_color_hex": "#112233", "p_display_name": "A", "p_default_split_type": "equal", "p_key": KEY}))
b_in = False
try:
    token = must("invite B", rpc(A, "create_group_invite", {"p_group_id": gid}))
    must("join B", rpc(B, "join_group", {"p_token": token, "p_display_name": "B", "p_key": KEY}))
    b_in = True
    must("approve B", rpc(A, "approve_member", {"p_group_id": gid, "p_member_key": subB}))
    print(f"== grupo {gid}")

    # 1. A crea el gasto desde la 2.2: todas las unidades + su autor, un HLC.
    exp_id = str(uuid.uuid4())
    f = {"amount": "40.0000", "currency_code": "USD", "expense_description": "Cena",
         "date": t0.strftime("%Y-%m-%dT00:00:00.000Z"), "created_at": t0.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
         "paid_by_member_key": subA, "split_type": "equal", "is_settled": False, "is_opening_balance": False,
         "last_edited_by_member_key": subA}
    units = ["gmoney"] + [k for k in f if k not in ("amount", "currency_code")]
    r = gw_push(A, [delta(gid, exp_id, f, units, hlc(1, "aa"))])
    d = find(gw_pull(A, gid, "v3"), exp_id)
    check("1. A crea el gasto (2.2) y lo baja con v3 con autor = A",
          result_status(r) == "applied" and d is not None and d["fields"].get("last_edited_by_member_key") == subA,
          f"{r} {d}")

    # 2. B lo edita como un 2.1: solo el importe, sin la unidad del autor.
    r = gw_push(B, [delta(gid, exp_id, {"amount": "55.0000", "currency_code": "USD"}, ["gmoney"], hlc(2, "bb"))])
    d = find(gw_pull(A, gid, "v3"), exp_id)
    check("2. B edita el importe como un 2.1 → A baja con v3 el autor NULL (clave presente) y el importe nuevo",
          result_status(r) == "applied" and d is not None
          and "last_edited_by_member_key" in d["fields"] and d["fields"]["last_edited_by_member_key"] is None
          and str(d["fields"].get("amount", "")).startswith("55"), f"{r} {d}")

    # 3. CONTROL: B lo edita como un 2.2 (importe + su autor, mismo HLC).
    r = gw_push(B, [delta(gid, exp_id, {"amount": "60.0000", "currency_code": "USD", "last_edited_by_member_key": subB},
                          ["gmoney", "last_edited_by_member_key"], hlc(3, "bb"))])
    d = find(gw_pull(A, gid, "v3"), exp_id)
    check("3. CONTROL: B edita como un 2.2 (importe + autor B) → autor = B",
          result_status(r) == "applied" and d is not None and d["fields"].get("last_edited_by_member_key") == subB
          and str(d["fields"].get("amount", "")).startswith("60"), f"{r} {d}")

    # 4. CONTROL: A cambia como un 2.1 solo is_settled → no es el formulario, el autor sigue siendo B.
    r = gw_push(A, [delta(gid, exp_id, {"is_settled": True}, ["is_settled"], hlc(4, "aa"))])
    d = find(gw_pull(A, gid, "v3"), exp_id)
    check("4. CONTROL: A cambia solo is_settled como un 2.1 → el autor sigue siendo B",
          result_status(r) == "applied" and d is not None and d["fields"].get("last_edited_by_member_key") == subB
          and d["fields"].get("is_settled") is True, f"{r} {d}")
finally:
    handover(gid, b_in)

print(f"g30_01-staging: {passed}/{passed + failed} PASS")
sys.exit(1 if failed else 0)
PY
