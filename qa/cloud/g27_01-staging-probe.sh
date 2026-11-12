#!/bin/bash
# g27_01-staging-probe.sh — mide en STAGING, por la vía real (JWT de usuario y `apply_group_delta` por PostgREST, como
# lo llama el Worker), que con g27_01 puesto el servidor deja gestionar los saldos iniciales a un ADMIN y se lo niega a
# un MIEMBRO NORMAL con un código que la app sabe enseñar (card 6n1o, 2026-10-31).
#
# Con un grupo nuevo en cada corrida (A dueña, B miembro):
#   0. B es admin activo y NO es el dueño.
#   1. B (admin) crea un saldo inicial (gasto + reparto) → aplicado.
#   2. A le quita el admin a B. B edita el saldo → 400 `yala_opening_balance_not_admin`, y el saldo no cambia.
#   3. B (miembro normal) crea otro saldo → 400 `yala_opening_balance_not_admin`.
#   4. CONTROL: B (miembro normal) crea un gasto normal → aplicado (el candado solo mira saldos iniciales).
#   5. A vuelve a hacer admin a B; B edita el saldo → aplicado; B lo borra (reparto y gasto) → aplicado.
#   6. CONTROL: el custodio, fuera del grupo → rechazado sin código de saldo (la RLS de siempre).
# Al terminar, el grupo pasa al custodio y A y B salen (molde de `opening-balance-admin-staging-probe.sh`).
#
# Uso:  GROUPS_ENC_KEY="$(cat ~/Secrets/yala-groups-enc/staging.key)" bash qa/cloud/g27_01-staging-probe.sh
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
must("create_group", rpc(A, "create_group", {"p_group_id": gid, "p_name": "zz-g27-opening-guard", "p_currency_code": "USD",
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

    def rejected(res, code):
        s, d = res
        return s == 400 and isinstance(d, dict) and d.get("message") == code

    exp_id, share_id = str(uuid.uuid4()), str(uuid.uuid4())
    r1 = rpc(B, "apply_group_delta", expense_upsert(gid, exp_id, 120, subB, hlc(1)))
    r2 = rpc(B, "apply_group_delta", share_upsert(gid, share_id, exp_id, subA, 120, hlc(2)))
    check("1. B (admin) crea un saldo inicial (gasto + reparto)", applied(r1) and applied(r2), f"{r1} {r2}")

    must("B member", rpc(A, "set_member_role", {"p_group_id": gid, "p_member_key": subB, "p_role": "member"}))
    r3 = rpc(B, "apply_group_delta", expense_upsert(gid, exp_id, 80, subB, hlc(10)))
    s, rows = http(f"/rest/v1/rpc/groups_pull_rows_split_expenses", {"p_group_id": gid, "p_after_seq": 0, "p_limit": 50, "p_key": KEY}, A)
    amount = next((r.get("amount") for r in (rows or []) if isinstance(r, dict) and r.get("sync_id") == exp_id), None) if s == 200 else f"pull {s} {rows}"
    check("2. B (ya miembro normal) edita el saldo → yala_opening_balance_not_admin, y no cambia",
          rejected(r3, "yala_opening_balance_not_admin") and amount is not None and float(amount) == 120, f"{r3} amount={amount}")

    r4 = rpc(B, "apply_group_delta", expense_upsert(gid, str(uuid.uuid4()), 50, subB, hlc(11)))
    check("3. B (miembro normal) crea otro saldo → yala_opening_balance_not_admin", rejected(r4, "yala_opening_balance_not_admin"), f"{r4}")

    normal = expense_upsert(gid, str(uuid.uuid4()), 30, subB, hlc(12))
    normal["p_fields"]["is_opening_balance"] = {"is_opening_balance": False}
    normal["p_fields"]["expense_description"] = {"expense_description": "Cena"}
    r5 = rpc(B, "apply_group_delta", normal)
    check("4. CONTROL B (miembro normal) crea un gasto normal → aplicado", applied(r5), f"{r5}")

    must("B admin otra vez", rpc(A, "set_member_role", {"p_group_id": gid, "p_member_key": subB, "p_role": "admin"}))
    r6 = rpc(B, "apply_group_delta", expense_upsert(gid, exp_id, 80, subB, hlc(20)))
    r7 = rpc(B, "apply_group_delta", tombstone("split_shares", gid, share_id, hlc(21)))
    r8 = rpc(B, "apply_group_delta", tombstone("split_expenses", gid, exp_id, hlc(22)))
    check("5. B (admin otra vez) edita y borra el saldo → aplicado", applied(r6) and applied(r7) and applied(r8), f"{r6} {r7} {r8}")

    r9 = rpc(C, "apply_group_delta", expense_upsert(gid, str(uuid.uuid4()), 50, subA, hlc(30)))
    check("6. CONTROL el custodio, fuera del grupo → rechazado por la RLS de siempre",
          rejected(r9, "yala_not_authorized"), f"{r9}")

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

print(f"g27_01-staging-probe: {passed}/{passed + failed} PASS")
sys.exit(1 if failed else 0)
PY
