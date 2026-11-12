#!/bin/bash
# opening-balance-admin-staging-probe.sh — mide en STAGING que el servidor deja a un ADMIN que NO es el dueño
# crear, editar y borrar un saldo inicial de un grupo (card yd2w, 2026-10-31).
#
# Por qué existe: la app solo dejaba al dueño gestionar saldos iniciales, y el encargo pedía comprobar si el
# servidor también lo exigía. Medido ese día en staging Y en producción (solo lectura, Management API): las
# políticas de `split_expenses`/`split_shares` piden `is_group_writer` (miembro activo), `apply_group_delta` es
# SECURITY INVOKER y no mira ni dueño ni `is_opening_balance` (md5 61c38595… idéntico en los dos proyectos), y
# ninguna función ni trigger de `public` menciona el saldo inicial salvo el lector del pull. ⇒ no hizo falta
# migración. Esta sonda lo prueba por la vía real: JWT de usuario y el mismo RPC que llama el Worker.
#
# Lo que mide, con un grupo nuevo en cada corrida:
#   0. B es admin y NO es el dueño (owner_user_id = A, rol de B = admin).
#   1. B crea un saldo inicial (gasto `is_opening_balance = true` + su reparto) → aplicado.
#   2. B lo edita (importe nuevo, HLC mayor) → aplicado.
#   3. B lo borra (tombstone del reparto y del gasto) → aplicado.
#   4. CONTROL: el custodio, todavía fuera del grupo, intenta lo mismo → NO aplicado. Sin este control, una sonda
#      que no distinguiera «aplicado» de «rechazado» saldría verde igual.
# Al terminar, el grupo pasa al custodio y A y B salen (molde de `gateway/test/corpusRelevo.ts`): el pull de A y B
# no crece. Nunca toca producción: la URL está fijada a staging y se comprueba.
#
# Uso:  GROUPS_ENC_KEY="$(cat ~/Secrets/yala-groups-enc/staging.key)" bash qa/cloud/opening-balance-admin-staging-probe.sh
# Env:  ~/Secrets/yala-supabase-test/test-users.env (USER_A_*, USER_B_*, USER_CUSTODIO_*).
set -euo pipefail

ENV_FILE="${HOME}/Secrets/yala-supabase-test/test-users.env"
[ -f "$ENV_FILE" ] || { echo "falta $ENV_FILE"; exit 2; }
set -a; . "$ENV_FILE"; set +a
[ -n "${GROUPS_ENC_KEY:-}" ] || { echo "falta GROUPS_ENC_KEY (llave de cifrado de grupos de STAGING)"; exit 2; }

URL="https://fostjbbwstyuunmmefuk.supabase.co"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg"

export URL ANON
python3 -I - <<'PY'
import base64, datetime, json, os, sys, urllib.error, urllib.request, uuid

URL, ANON, KEY = os.environ["URL"], os.environ["ANON"], os.environ["GROUPS_ENC_KEY"]
assert "fostjbbwstyuunmmefuk" in URL, "solo staging"

def http(path, body=None, jwt=None, method="POST"):
    h = {"apikey": ANON, "Content-Type": "application/json"}
    if jwt: h["Authorization"] = f"Bearer {jwt}"
    r = urllib.request.Request(URL + path, method=method,
        data=None if body is None else json.dumps(body).encode(), headers=h)
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except Exception: return e.code, raw
    except urllib.error.URLError as e:
        return 0, str(e)

def login(email, pw):
    s, d = http("/auth/v1/token?grant_type=password", {"email": email, "password": pw})
    assert s == 200, f"login {email}: {s} {d}"
    tok = d["access_token"]; p = tok.split(".")[1]; p += "=" * (-len(p) % 4)
    return tok, json.loads(base64.urlsafe_b64decode(p))["sub"]

def rpc(jwt, fn, args):
    return http(f"/rest/v1/rpc/{fn}", args, jwt)

def must(label, res):
    s, d = res
    if s != 200: raise SystemExit(f"preparación falló en {label}: {s} {d}")
    return d

t0 = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
def hlc(step):
    t = t0 + datetime.timedelta(seconds=step)
    return t.strftime("%Y-%m-%dT%H:%M:%S.000Z") + "-0000-00000000000000aa"

def unit_upsert(entity, gid, sid, fields, h):
    return {"p_entity": entity, "p_group_id": gid, "p_sync_id": sid, "p_op": "upsert",
            "p_fields": fields, "p_field_hlcs": {u: h for u in fields}, "p_key": KEY,
            "p_row_hlc": h, "p_schema_version": 1}

def expense_upsert(gid, sid, amount, creditor, h):
    return unit_upsert("split_expenses", gid, sid, {
        "gmoney": {"amount": amount, "currency_code": "USD"},
        "expense_description": {"expense_description": "Saldo inicial"},
        "date": {"date": t0.strftime("%Y-%m-%dT00:00:00.000Z")},
        "created_at": {"created_at": t0.strftime("%Y-%m-%dT%H:%M:%S.000Z")},
        "paid_by_member_key": {"paid_by_member_key": creditor},
        "split_type": {"split_type": "exact"},
        "is_settled": {"is_settled": False},
        "is_opening_balance": {"is_opening_balance": True},
    }, h)

def share_upsert(gid, sid, expense_id, debtor, amount, h):
    return unit_upsert("split_shares", gid, sid, {
        "gshare": {"expense_id": expense_id, "member_key": debtor, "amount": amount},
        "is_paid": {"is_paid": False},
    }, h)

def tombstone(entity, gid, sid, h):
    return {"p_entity": entity, "p_group_id": gid, "p_sync_id": sid, "p_op": "tombstone",
            "p_fields": {}, "p_field_hlcs": {}, "p_key": KEY, "p_row_hlc": h, "p_schema_version": 1}

passed = failed = 0
def check(label, ok, detail=""):
    global passed, failed
    if ok: passed += 1; print(f"  PASS  {label}")
    else:  failed += 1; print(f"  FAIL  {label} {detail}")

def applied(res):
    s, d = res
    return s == 200 and isinstance(d, dict) and d.get("noop") is False

A, subA = login(os.environ["USER_A_EMAIL"], os.environ["USER_A_PASS"])
B, subB = login(os.environ["USER_B_EMAIL"], os.environ["USER_B_PASS"])
C, subC = login(os.environ["USER_CUSTODIO_EMAIL"], os.environ["USER_CUSTODIO_PASS"])
gid = str(uuid.uuid4())

# Grupo de A. Desde aquí, pase lo que pase, el grupo acaba en el custodio (`finally`): una corrida cortada a medias
# no puede dejar un grupo vivo en el pull de A y B.
must("create_group", rpc(A, "create_group", {"p_group_id": gid, "p_name": "zz-opening-admin", "p_currency_code": "USD",
     "p_icon_name": "cart", "p_color_hex": "#112233", "p_display_name": "A", "p_default_split_type": "equal", "p_key": KEY}))
try:
    # B entra, A lo aprueba y lo hace admin.
    token = must("invite B", rpc(A, "create_group_invite", {"p_group_id": gid}))
    must("join B", rpc(B, "join_group", {"p_token": token, "p_display_name": "B", "p_key": KEY}))
    must("approve B", rpc(A, "approve_member", {"p_group_id": gid, "p_member_key": subB}))
    must("B admin", rpc(A, "set_member_role", {"p_group_id": gid, "p_member_key": subB, "p_role": "admin"}))

    print(f"== grupo {gid}")
    s, g = http(f"/rest/v1/split_groups?group_id=eq.{gid}&select=owner_user_id", jwt=B, method="GET")
    s2, m = http(f"/rest/v1/group_members?group_id=eq.{gid}&member_key=eq.{subB}&select=role,status", jwt=B, method="GET")
    check("0. B es admin activo y NO es el dueño",
          s == 200 and s2 == 200 and bool(g) and g[0]["owner_user_id"] == subA and bool(m) and m[0] == {"role": "admin", "status": "active"},
          f"{s} {g} {s2} {m}")

    exp_id, share_id = str(uuid.uuid4()), str(uuid.uuid4())
    r1 = rpc(B, "apply_group_delta", expense_upsert(gid, exp_id, 120, subB, hlc(1)))
    r2 = rpc(B, "apply_group_delta", share_upsert(gid, share_id, exp_id, subA, 120, hlc(2)))
    check("1. B crea un saldo inicial (gasto + reparto)", applied(r1) and applied(r2), f"{r1} {r2}")

    r3 = rpc(B, "apply_group_delta", expense_upsert(gid, exp_id, 80, subB, hlc(10)))
    r4 = rpc(B, "apply_group_delta", share_upsert(gid, share_id, exp_id, subA, 80, hlc(11)))
    check("2. B lo edita (120 → 80)", applied(r3) and applied(r4), f"{r3} {r4}")

    r5 = rpc(B, "apply_group_delta", tombstone("split_shares", gid, share_id, hlc(20)))
    r6 = rpc(B, "apply_group_delta", tombstone("split_expenses", gid, exp_id, hlc(21)))
    check("3. B lo borra (tombstone del reparto y del gasto)", applied(r5) and applied(r6), f"{r5} {r6}")

    r7 = rpc(C, "apply_group_delta", expense_upsert(gid, str(uuid.uuid4()), 50, subA, hlc(30)))
    check("4. CONTROL: alguien de fuera del grupo NO puede", not applied(r7), f"{r7}")

finally:
    # Relevo, a mejor esfuerzo: B sale si entró, el custodio entra y hereda el grupo, A sale.
    rpc(B, "leave_group", {"p_group_id": gid})
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

print(f"opening-balance-admin-staging: {passed}/{passed + failed} PASS")
sys.exit(1 if failed else 0)
PY
