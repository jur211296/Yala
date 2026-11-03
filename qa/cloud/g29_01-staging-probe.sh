#!/bin/bash
# g29_01-staging-probe.sh — mide en STAGING, por la vía real (Worker + JWT de usuario), las tres cosas del servidor que
# piden las cards de la sesión S35q (2026-11-02):
#
#   xi74 · el autor viaja: un gasto subido con `last_edited_by_member_key` y una liquidación con `recorded_by_member_key`
#          bajan con su autor en el pull de OTRO miembro con `X-Yala-Capability-Set: v3`, y SIN él con `v2` y sin
#          cabecera (los teléfonos que aún no los conocen). El Worker anuncia `manifest_version` 3.
#   m76a · el reparto huérfano de un saldo inicial rechazado: un miembro NO admin crea un saldo inicial → el gasto se
#          rechaza (`yala_opening_balance_not_admin`) y su reparto SÍ se aplica (el huérfano del ticket); su tombstone
#          también se aplica (la limpieza que hace la app). CONTROL: el tombstone del reparto de un saldo inicial que
#          SÍ existe (lo creó el dueño) lo rechaza el mismo trigger: la limpieza no puede borrar un saldo de verdad.
#   hfhs · grupo migrado: la fila heredada de B es admin y no está reclamada (`user_id` NULL). Si B entra SIN reclamarla,
#          el servidor no lo ve admin (`is_group_admin` = false, su saldo inicial se rechaza). Si entra RECLAMÁNDOLA, sí.
#
# Cada grupo acaba en el custodio (relevo en `finally`, molde de `opening-balance-admin-staging-probe.sh`): el pull de A y
# B no crece. Nunca toca producción: las URLs están fijadas a staging y se comprueban.
#
# Uso:  GROUPS_ENC_KEY="$(cat ~/Secrets/yala-groups-enc/staging.key)" bash qa/cloud/g29_01-staging-probe.sh
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
    h = {"apikey": ANON, "Content-Type": "application/json", "User-Agent": "Yala/probe-g29_01"}
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
def hlc(step):
    return (t0 + datetime.timedelta(seconds=step)).strftime("%Y-%m-%dT%H:%M:%S.000Z") + "-0000-00000000000000aa"

passed = failed = 0
def check(label, ok, detail=""):
    global passed, failed
    if ok: passed += 1; print(f"  PASS  {label}")
    else:  failed += 1; print(f"  FAIL  {label} {detail}")

# ---------- Worker
def gw_push(jwt, deltas):
    return http(GW, "/groups/push", {"deltas": deltas}, jwt)

def gw_pull(jwt, gid, capability):
    q = urllib.parse.urlencode({"cursors": json.dumps({gid: 0}), "limit": 500})
    h = {} if capability is None else {"X-Yala-Capability-Set": capability}
    return http(GW, f"/groups/pull?{q}", None, jwt, method="GET", headers=h)

def delta(entity, gid, sid, fields, units, h):
    return {"entity_type": entity, "group_id": gid, "sync_id": sid, "op": "upsert", "fields": fields,
            "field_hlcs": {u: h for u in units}, "hlc": h, "client_mutation_id": str(uuid.uuid4()), "schema_version": 1}

def expense_fields(payer, author, opening=False, amount="40.0000"):
    f = {"amount": amount, "currency_code": "USD", "expense_description": "Cena", "date": t0.strftime("%Y-%m-%dT00:00:00.000Z"),
         "created_at": t0.strftime("%Y-%m-%dT%H:%M:%S.000Z"), "paid_by_member_key": payer, "split_type": "equal",
         "is_settled": False, "is_opening_balance": opening}
    if author is not None: f["last_edited_by_member_key"] = author
    units = ["gmoney"] + [k for k in f if k not in ("amount", "currency_code")]
    return f, units

def result_status(res):
    s, d = res
    if s != 200 or not isinstance(d, dict) or not d.get("results"): return f"http {s} {d}"
    r = d["results"][0]
    return r.get("status") if r.get("status") != "rejected" else f"rejected:{r.get('reason')}"

def find(pull_res, entity, sid):
    s, d = pull_res
    if s != 200: return None
    for x in d.get("deltas", []):
        if x.get("entity_type") == entity and x.get("sync_id") == sid: return x
    return None

# ---------- RPC directo (molde de la sonda del saldo inicial)
def unit_upsert(entity, gid, sid, fields, h):
    return {"p_entity": entity, "p_group_id": gid, "p_sync_id": sid, "p_op": "upsert", "p_fields": fields,
            "p_field_hlcs": {u: h for u in fields}, "p_key": KEY, "p_row_hlc": h, "p_schema_version": 1}

def opening_upsert(gid, sid, creditor, h):
    return unit_upsert("split_expenses", gid, sid, {
        "gmoney": {"amount": 120, "currency_code": "USD"},
        "expense_description": {"expense_description": "Saldo inicial"},
        "paid_by_member_key": {"paid_by_member_key": creditor},
        "split_type": {"split_type": "exact"},
        "is_opening_balance": {"is_opening_balance": True},
    }, h)

def share_upsert(gid, sid, expense_id, debtor, h):
    return unit_upsert("split_shares", gid, sid, {
        "gshare": {"expense_id": expense_id, "member_key": debtor, "amount": 120}, "is_paid": {"is_paid": False}}, h)

def tombstone(entity, gid, sid, h):
    return {"p_entity": entity, "p_group_id": gid, "p_sync_id": sid, "p_op": "tombstone", "p_fields": {},
            "p_field_hlcs": {}, "p_key": KEY, "p_row_hlc": h, "p_schema_version": 1}

def applied(res):
    s, d = res
    return s == 200 and isinstance(d, dict) and d.get("noop") is False

def rejected_with(res, slug):
    s, d = res
    return s != 200 and slug in json.dumps(d)

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

# ===================================================================== xi74 + m76a (grupo normal, B miembro)
s, cfg = http(GW, "/config", None, None, method="GET")
check("0. el Worker de staging anuncia groupsManifestVersion 3", s == 200 and cfg.get("sync", {}).get("groupsManifestVersion") == 3, f"{s} {cfg}")

gid = str(uuid.uuid4())
must("create_group", rpc(A, "create_group", {"p_group_id": gid, "p_name": "zz-g29-autor", "p_currency_code": "USD",
     "p_icon_name": "cart", "p_color_hex": "#112233", "p_display_name": "A", "p_default_split_type": "equal", "p_key": KEY}))
b_in = False
try:
    token = must("invite B", rpc(A, "create_group_invite", {"p_group_id": gid}))
    must("join B", rpc(B, "join_group", {"p_token": token, "p_display_name": "B", "p_key": KEY}))
    b_in = True
    must("approve B", rpc(A, "approve_member", {"p_group_id": gid, "p_member_key": subB}))
    print(f"== grupo {gid}")

    # xi74 · B apunta un gasto que pagó A: el autor es B.
    exp_id = str(uuid.uuid4())
    f, units = expense_fields(payer=subA, author=subB)
    r = gw_push(B, [delta("split_expenses", gid, exp_id, f, units, hlc(1))])
    check("1. B sube por el Worker un gasto que pagó A, con su autor", result_status(r) == "applied", f"{r}")

    p3 = gw_pull(A, gid, "v3")
    d3 = find(p3, "split_expenses", exp_id)
    check("2. A baja con v3 el gasto con autor = B (y pagador = A) y el anuncio manifest_version 3",
          d3 is not None and d3["fields"].get("last_edited_by_member_key") == subB
          and d3["fields"].get("paid_by_member_key") == subA and p3[1].get("manifest_version") == 3, f"{d3}")
    for cap in ("v2", None):
        dx = find(gw_pull(A, gid, cap), "split_expenses", exp_id)
        check(f"3. con {cap or 'sin cabecera'} el gasto baja SIN el autor (teléfono que no lo conoce)",
              dx is not None and "last_edited_by_member_key" not in dx["fields"]
              and "last_edited_by_member_key" not in dx.get("field_hlcs", {}), f"{dx}")

    # A lo edita después: el autor pasa a A (LWW por columna).
    f2, units2 = expense_fields(payer=subA, author=subA, amount="50.0000")
    r = gw_push(A, [delta("split_expenses", gid, exp_id, f2, units2, hlc(5))])
    d3b = find(gw_pull(B, gid, "v3"), "split_expenses", exp_id)
    check("4. A lo edita: B baja autor = A", result_status(r) == "applied" and d3b is not None
          and d3b["fields"].get("last_edited_by_member_key") == subA, f"{r} {d3b}")

    # xi74 · liquidación registrada por B («A me pagó»).
    st_id = str(uuid.uuid4())
    sf = {"from_member_key": subA, "to_member_key": subB, "amount": "10.0000", "currency_code": "USD",
          "date": t0.strftime("%Y-%m-%dT00:00:00.000Z"), "is_confirmed": True, "recorded_by_member_key": subB}
    su = ["smoney", "from_member_key", "to_member_key", "date", "is_confirmed", "recorded_by_member_key"]
    r = gw_push(B, [delta("split_settlements", gid, st_id, sf, su, hlc(6))])
    ds = find(gw_pull(A, gid, "v3"), "split_settlements", st_id)
    ds2 = find(gw_pull(A, gid, "v2"), "split_settlements", st_id)
    check("5. la liquidación baja con quién la registró (v3) y sin él (v2)",
          result_status(r) == "applied" and ds is not None and ds["fields"].get("recorded_by_member_key") == subB
          and ds2 is not None and "recorded_by_member_key" not in ds2["fields"], f"{r} {ds} {ds2}")

    # m76a · B (miembro, no admin) crea un saldo inicial NUEVO.
    ob_id, ob_share = str(uuid.uuid4()), str(uuid.uuid4())
    r1 = rpc(B, "apply_group_delta", opening_upsert(gid, ob_id, subB, hlc(10)))
    r2 = rpc(B, "apply_group_delta", share_upsert(gid, ob_share, ob_id, subA, hlc(11)))
    check("6. el saldo inicial de B se rechaza (not_admin) y su reparto SÍ se aplica: el huérfano",
          rejected_with(r1, "yala_opening_balance_not_admin") and applied(r2), f"{r1} {r2}")
    r3 = rpc(B, "apply_group_delta", tombstone("split_shares", gid, ob_share, hlc(12)))
    s, rows = http(URL, f"/rest/v1/split_shares?group_id=eq.{gid}&sync_id=eq.{ob_share}&select=deleted", jwt=A, method="GET")
    check("7. el tombstone de ese reparto se aplica y queda borrado en el servidor (la limpieza de la app)",
          applied(r3) and s == 200 and rows == [{"deleted": True}], f"{r3} {s} {rows}")

    # CONTROL m76a · el reparto de un saldo inicial que SÍ existe no lo puede borrar B.
    ok_id, ok_share = str(uuid.uuid4()), str(uuid.uuid4())
    must("A crea saldo", rpc(A, "apply_group_delta", opening_upsert(gid, ok_id, subA, hlc(20))))
    must("A crea reparto", rpc(A, "apply_group_delta", share_upsert(gid, ok_share, ok_id, subB, hlc(21))))
    r4 = rpc(B, "apply_group_delta", tombstone("split_shares", gid, ok_share, hlc(22)))
    check("8. CONTROL: B no puede borrar el reparto de un saldo inicial vivo (lo juzga el trigger)",
          rejected_with(r4, "yala_opening_balance_not_admin"), f"{r4}")
finally:
    handover(gid, b_in)

# ===================================================================== hfhs (grupo migrado con fila heredada admin)
def mgmt_sql(query):
    """Management API de Supabase (entra como `postgres`): solo para sembrar la fila heredada, que hoy ningún RPC crea
    (`migrate_group` ya no se ofrece a `authenticated`). Se comprueba que el proyecto es el de staging."""
    pat = open(os.path.expanduser("~/Secrets/yala-supabase-mgmt/pat")).read().strip()
    r = urllib.request.Request("https://api.supabase.com/v1/projects/fostjbbwstyuunmmefuk/database/query", method="POST",
        data=json.dumps({"query": query}).encode(),
        headers={"Authorization": f"Bearer {pat}", "Content-Type": "application/json", "User-Agent": "Yala/probe-g29_01"})
    with urllib.request.urlopen(r) as resp:
        return json.loads(resp.read().decode() or "null")

def migrated_group(label):
    """Un grupo de A con la fila HEREDADA de B: admin, activa y sin reclamar (`user_id` NULL), como la deja
    `migrate_group` (g6_01) para todo miembro que no es el dueño."""
    g = str(uuid.uuid4())
    legacy = "ck-legacy-" + uuid.uuid4().hex[:12]
    must("create_group", rpc(A, "create_group", {"p_group_id": g, "p_name": label, "p_currency_code": "USD",
         "p_icon_name": "cart", "p_color_hex": "#112233", "p_display_name": "A", "p_default_split_type": "equal", "p_key": KEY}))
    h = hlc(30)
    mgmt_sql(f"insert into public.group_members (group_id, member_key, user_id, display_name, role, status, joined_at, "
             f"field_hlcs, hlc, deleted, schema_version) values ('{g}', '{legacy}', null, "
             f"extensions.pgp_sym_encrypt('B', '{KEY}'), 'admin', 'active', now(), "
             f"jsonb_build_object('profile', '{h}', 'membership', '{h}'), '{h}', false, 1)")
    return g, legacy

for claims in (False, True):
    g, legacy = migrated_group("zz-g29-migrado-" + ("reclama" if claims else "sin-reclamar"))
    b_in = False
    try:
        token = must("invite B", rpc(A, "create_group_invite", {"p_group_id": g}))
        args = {"p_token": token, "p_display_name": "B", "p_key": KEY}
        if claims: args["p_legacy_member_key"] = legacy
        j = must("join B", rpc(B, "join_group", args)); b_in = True
        must("approve B", rpc(A, "approve_member", {"p_group_id": g, "p_member_key": j["member_key"]}))
        s, mem = http(URL, f"/rest/v1/group_members?group_id=eq.{g}&select=member_key,user_id,role,status&order=member_key",
                      jwt=A, method="GET")
        _, is_admin = rpc(B, "is_group_admin", {"p_group_id": g})
        r = rpc(B, "apply_group_delta", opening_upsert(g, str(uuid.uuid4()), subB, hlc(40)))
        mine = [m for m in mem if m["user_id"] == subB]
        if not claims:
            legacy_row = [m for m in mem if m["member_key"] == legacy]
            check("9. migrado SIN reclamar: la fila heredada sigue admin con user_id NULL, la de B es member, "
                  "el servidor no lo ve admin y rechaza su saldo inicial",
                  legacy_row == [{"member_key": legacy, "user_id": None, "role": "admin", "status": "active"}]
                  and len(mine) == 1 and mine[0]["role"] == "member" and is_admin is False
                  and rejected_with(r, "yala_opening_balance_not_admin"), f"{mem} {is_admin} {r}")
        else:
            check("10. migrado RECLAMANDO la fila heredada: B es admin y su saldo inicial se aplica",
                  len(mine) == 1 and mine[0]["member_key"] == legacy and mine[0]["role"] == "admin"
                  and is_admin is True and applied(r), f"{mem} {is_admin} {r}")
    finally:
        handover(g, b_in)

print(f"g29_01-staging: {passed}/{passed + failed} PASS")
sys.exit(1 if failed else 0)
PY
