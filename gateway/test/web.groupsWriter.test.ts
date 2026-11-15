/**
 * Yala web, lote 3 (opción A) · la entrada interna `WebGroupsWriter`. Unit OFFLINE: se mockean `verifyUserToken` y el
 * fan-out de avisos, y se stubbea `fetch` de PostgREST (molde `web.groupsReader.test.ts`).
 *
 * Lo que fija: solo el rol propio de la web (`yala_web`) escribe, ni el del iPhone ni el del conector; solo en staging
 * con el interruptor; el gateway arma los deltas como el iPhone (unidades de coherencia enteras, un reloj por delta, el
 * reparto igual de la app); quién confirma un pago; los reintentos no duplican; el límite por cuenta; y el enlace de
 * invitación con el formato de la app.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { appMemberRef } from "../../shared-core/src/logic/groupMemberRef";

/** Lo que escribe la web en las filas: el id con que la app nombra al miembro, no su `member_key` (barrido 2.3). */
const ref = (key: string) => appMemberRef(GID, key);

const SUB = "11111111-2222-3333-4444-555555555555";
const OTHER = "99999999-2222-3333-4444-555555555555";

function jwt(role: string): string {
  const b64 = (o: object) => btoa(JSON.stringify(o)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${b64({ alg: "ES256" })}.${b64({ sub: SUB, role })}.firma`;
}
const WEB = jwt("yala_web");
const CONNECTOR = jwt("yala_mcp_reader");
const PHONE = jwt("authenticated");

vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => ([WEB, CONNECTOR, PHONE].includes(token) ? { sub: SUB, token } : null)),
  };
});
const fanOut = vi.fn(async () => {});
vi.mock("../src/groups/routes", () => ({ fanOutGroupPush: (...a: unknown[]) => fanOut(...(a as [])) }));

const { addWebExpense, addWebSettlement, createWebInvite, shareId, webHlc } = await import("../src/web/groupsWriter");

const GID = "SplitGroup-0000aaaa";
const EXP = "0f8e2c1a-1111-4222-8333-444455556666";
const PAY = "0f8e2c1a-2222-4222-8333-444455556666";
const NOW = Date.UTC(2026, 10, 14, 18, 0, 0);

function baseEnv(over: Partial<Record<string, unknown>> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    SUPABASE_URL: "https://web-writer.local",
    SUPABASE_ANON_KEY: "anon",
    GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
    GROUPS_ENC_KEY: "enc-key-unit-0123456789",
    WEB_GROUPS_READER: "on",
    WEB_GROUPS_WRITER: "on",
    ...over,
  } as unknown as Env;
}

interface World {
  group: Record<string, unknown>;
  members: Record<string, unknown>[];
  expenses: Record<string, unknown>[];
  shares: Record<string, unknown>[];
  settlements: Record<string, unknown>[];
  /** Lo que contesta la función de escritura de la base: 200 (aplicado), «exists» (ya estaba en el grupo) u otro estado. */
  applyStatus: (body: Record<string, unknown>) => number | "exists";
}

function world(): World {
  return {
    group: { group_id: GID, name: "Viaje", currency_code: "PEN", icon_name: "airplane", color_hex: "#FF8800", members_can_invite: false, is_archived: false },
    members: [
      { member_key: "m-ana", user_id: SUB, display_name: "Ana", role: "admin", status: "active" },
      { member_key: "m-beto", user_id: OTHER, display_name: "Beto", role: "member", status: "active" },
      { member_key: "m-caro", user_id: "c", display_name: "Caro", role: "member", status: "active" },
      { member_key: "m-dani", user_id: "d", display_name: "Dani", role: "member", status: "left" },
    ],
    expenses: [{ sync_id: "old-1", currency_code: "USD", amount: "10.0000" }],
    shares: [],
    settlements: [],
    applyStatus: () => 200,
  };
}

interface Call {
  url: string;
  auth: string | null;
  body: Record<string, unknown> | null;
}

function stub(w: World): Call[] {
  const calls: Call[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = String(input);
      const body = init?.body ? (JSON.parse(String(init.body)) as Record<string, unknown>) : null;
      calls.push({ url, auth: new Headers(init?.headers).get("Authorization"), body });
      if (url.includes("/rest/v1/group_members?")) {
        const me = w.members.find((m) => m.user_id === SUB);
        return Response.json(me && me.status === "active" ? [{ group_id: GID, member_key: me.member_key }] : []);
      }
      const fn = url.split("/rpc/")[1];
      if (fn === "groups_pull_rows_split_groups") return Response.json([w.group]);
      if (fn === "groups_pull_rows_group_members") return Response.json(w.members);
      if (fn === "groups_pull_rows_split_expenses") return Response.json(w.expenses);
      if (fn === "groups_pull_rows_split_shares") return Response.json(w.shares);
      if (fn === "groups_pull_rows_split_settlements") return Response.json(w.settlements);
      if (fn === "web_add_group_expense" || fn === "web_add_group_settlement") {
        const st = w.applyStatus(body ?? {});
        if (st === "exists") return Response.json({ op: "upsert", noop: true, reason: "exists" });
        return st === 200 ? Response.json({ op: "upsert", inserted: true, noop: false }) : new Response('{"code":"P0001","message":"yala_bad_request"}', { status: st });
      }
      if (fn === "create_group_invite") return Response.json("0123456789abcdef0123456789abcdef");
      return new Response("no", { status: 404 });
    }),
  );
  return calls;
}

const applies = (calls: Call[]) => calls.filter((c) => /\/rpc\/web_add_group_(expense|settlement)$/.test(c.url));
const expense = (over: Record<string, unknown> = {}) => ({
  groupId: GID,
  id: EXP,
  description: "Cena",
  amount: 100,
  currency: "PEN",
  paidBy: "m-ana",
  date: "2026-11-14T15:30:00.000Z",
  participants: ["m-ana", "m-beto", "m-caro"],
  ...over,
});
const defer = vi.fn();

beforeEach(() => {
  fanOut.mockClear();
  defer.mockClear();
});
afterEach(() => vi.unstubAllGlobals());

describe("WebGroupsWriter · quién puede", () => {
  it("solo el rol propio de la web: ni el token del iPhone (se saltaría App Attest) ni el del conector", async () => {
    for (const token of [PHONE, CONNECTOR]) {
      const calls = stub(world());
      expect(await addWebExpense(baseEnv(), token, expense(), defer, NOW)).toEqual({ ok: false, error: "role" });
      expect(calls).toHaveLength(0);
    }
  });

  it("apagado sin el interruptor y siempre en producción", async () => {
    for (const env of [baseEnv({ WEB_GROUPS_WRITER: undefined }), baseEnv({ ENVIRONMENT: "production" })]) {
      const calls = stub(world());
      expect(await addWebSettlement(env, WEB, { groupId: GID, id: PAY, from: "m-beto", to: "m-ana", amount: 5, currency: "PEN", date: "2026-11-14T15:00:00Z" }, defer, NOW)).toEqual({ ok: false, error: "disabled" });
      expect(calls).toHaveLength(0);
    }
  });

  it("con el límite por cuenta agotado no lee ni escribe, y el cubo es el de la cuenta en la web", async () => {
    const calls = stub(world());
    const seen: string[] = [];
    const env = baseEnv({
      RATE_LIMITER: {
        idFromName: (n: string) => (seen.push(n), n),
        get: () => ({ fetch: async () => Response.json({ allowed: false, reason: "burst" }) }),
      },
    });
    expect(await addWebExpense(env, WEB, expense(), defer, NOW)).toEqual({ ok: false, error: "rate" });
    expect(seen).toEqual([`webw:${SUB}`]);
    expect(calls).toHaveLength(0);
  });

  it("un grupo archivado o del que no eres miembro activo no se toca", async () => {
    const w = world();
    w.group.is_archived = true;
    let calls = stub(w);
    expect(await addWebExpense(baseEnv(), WEB, expense(), defer, NOW)).toEqual({ ok: false, error: "not_allowed", detail: "archived" });
    expect(applies(calls)).toHaveLength(0);
    const w2 = world();
    w2.members[0]!.status = "left";
    calls = stub(w2);
    expect(await addWebExpense(baseEnv(), WEB, expense(), defer, NOW)).toEqual({ ok: false, error: "not_found" });
    expect(applies(calls)).toHaveLength(0);
  });
});

describe("WebGroupsWriter · añadir un gasto", () => {
  it("arma el gasto y sus cuotas como el iPhone, con el reparto igual de la app, en UNA llamada", async () => {
    const calls = stub(world());
    expect(await addWebExpense(baseEnv(), WEB, expense(), defer, NOW)).toEqual({ ok: true, status: "applied" });
    const a = applies(calls);
    // Una sola llamada: gasto y cuotas entran juntos o no entra nada (web3_02, `web_add_group_expense`).
    expect(a).toHaveLength(1);
    const c = a[0]!;
    expect(c.url.endsWith("/rpc/web_add_group_expense")).toBe(true);
    expect(c.auth).toBe(`Bearer ${WEB}`);
    expect(c.url).not.toContain("enc-key");
    const e = c.body!;
    expect(e.p_key).toBe("enc-key-unit-0123456789");
    expect(e.p_group_id).toBe(GID);
    expect(e.p_expense_id).toBe(EXP);
    expect(e.p_fields).toEqual({
      gmoney: { amount: 100, currency_code: "PEN" },
      expense_description: { expense_description: "Cena" },
      date: { date: "2026-11-14T15:30:00.000Z" },
      created_at: { created_at: new Date(NOW).toISOString() },
      paid_by_member_key: { paid_by_member_key: await ref("m-ana") },
      split_type: { split_type: "equal" },
      is_settled: { is_settled: false },
      is_opening_balance: { is_opening_balance: false },
      last_edited_by_member_key: { last_edited_by_member_key: await ref("m-ana") },
    });
    // Un reloj por delta, con el formato de la app (46 caracteres), en todas sus unidades.
    const hlc = e.p_row_hlc as string;
    expect(hlc).toMatch(/^2026-11-14T18:00:00\.000Z-0000-[0-9a-f]{16}$/);
    expect(hlc).toHaveLength(46);
    expect(new Set(Object.values(e.p_field_hlcs as Record<string, string>))).toEqual(new Set([hlc]));
    expect(Object.keys(e.p_field_hlcs as object).sort()).toEqual(Object.keys(e.p_fields as object).sort());
    // 100 / 3: el céntimo que sobra va al primero, como `GroupSplitCalculator.equalSplit`.
    const shares = e.p_shares as { sync_id: string; fields: Record<string, Record<string, unknown>>; field_hlcs: Record<string, string> }[];
    expect(shares.map((s) => s.fields.gshare)).toEqual([
      { expense_id: EXP, member_key: await ref("m-ana"), amount: 33.34 },
      { expense_id: EXP, member_key: await ref("m-beto"), amount: 33.33 },
      { expense_id: EXP, member_key: await ref("m-caro"), amount: 33.33 },
    ]);
    for (const s of shares) {
      expect(s.fields.is_paid).toEqual({ is_paid: false });
      expect(s.field_hlcs).toEqual({ gshare: hlc, is_paid: hlc });
    }
    expect(shares.map((s) => s.sync_id)).toEqual(await Promise.all(["m-ana", "m-beto", "m-caro"].map((m) => shareId(EXP, m))));
    // Los demás miembros reciben el aviso de siempre, con quién y qué.
    expect(defer).toHaveBeenCalledTimes(1);
    const [, auth, gids, exclude, audience, , alerts] = fanOut.mock.calls[0] as unknown as [unknown, { sub: string }, string[], unknown, unknown, unknown, Record<string, { locKey: string; locArgs: string[]; title: string }>];
    expect(auth.sub).toBe(SUB);
    expect(gids).toEqual([GID]);
    expect(exclude).toBeNull();
    expect(audience).toEqual({ kind: "coMembers" });
    expect(alerts[GID]?.title).toBe("Viaje");
    expect(alerts[GID]?.locKey).toBe("notifications.groups.push.expenseAdded");
    expect(alerts[GID]?.locArgs.slice(0, 2)).toEqual(["Ana", "Cena"]);
  });

  it("rechaza lo que el iPhone no dejaría: miembro que salió, divisa que el grupo no usa, céntimos de más, concepto vacío", async () => {
    const cases: [Record<string, unknown>, string][] = [
      [{ participants: ["m-ana", "m-dani"] }, "participants"],
      [{ participants: ["m-ana", "m-ana"] }, "participants"],
      [{ paidBy: "m-dani" }, "paidBy"],
      [{ currency: "EUR" }, "currency"],
      [{ amount: 10.005 }, "amount"],
      [{ amount: 0 }, "amount"],
      [{ description: "   " }, "description"],
      [{ date: "2031-01-01T00:00:00Z" }, "date"],
      [{ id: "no-es-uuid" }, "id"],
    ];
    for (const [over, detail] of cases) {
      const calls = stub(world());
      expect(await addWebExpense(baseEnv(), WEB, expense(over), defer, NOW), detail).toEqual({ ok: false, error: "invalid", detail });
      expect(applies(calls)).toHaveLength(0);
    }
    // Una divisa que el grupo ya usa en un gasto sí vale.
    const calls = stub(world());
    expect((await addWebExpense(baseEnv(), WEB, expense({ currency: "USD" }), defer, NOW)).ok).toBe(true);
    expect(applies(calls)).toHaveLength(1);
  });

  it("un reenvío no toca nada: ni el gasto ni cuotas sueltas sobre un gasto que ya existe", async () => {
    // El gasto ya está en el grupo (lo ve el lector): «ya estaba», sin llamar a la base.
    const w = world();
    w.expenses.push({ sync_id: EXP, currency_code: "PEN" });
    let calls = stub(w);
    expect(await addWebExpense(baseEnv(), WEB, expense({ participants: ["m-caro"], amount: 500 }), defer, NOW)).toEqual({ ok: true, status: "already" });
    expect(applies(calls)).toHaveLength(0);
    // El lector no lo ve (borrado, o entró entre medias) y la base dice `exists`: tampoco se escribe nada ni se avisa.
    const w2 = world();
    w2.applyStatus = () => "exists";
    calls = stub(w2);
    expect(await addWebExpense(baseEnv(), WEB, expense(), defer, NOW)).toEqual({ ok: true, status: "already" });
    expect(applies(calls)).toHaveLength(1);
    expect(defer).not.toHaveBeenCalled();
  });

  it("si la base lo rechaza (un id de otro grupo, cuotas que no cuadran), no avisa a nadie y lo dice", async () => {
    for (const [st, out] of [
      [400, { ok: false, error: "invalid", detail: "id" }],
      [503, { ok: false, error: "upstream" }],
    ] as const) {
      const w = world();
      w.applyStatus = () => st;
      stub(w);
      expect(await addWebExpense(baseEnv(), WEB, expense(), defer, NOW)).toEqual(out);
    }
    expect(defer).not.toHaveBeenCalled();
  });
});

describe("WebGroupsWriter · apuntar un pago", () => {
  const pay = (over: Record<string, unknown> = {}) => ({ groupId: GID, id: PAY, from: "m-ana", to: "m-beto", amount: 25.5, currency: "PEN", date: "2026-11-14T15:00:00Z", ...over });

  it("nace confirmado si lo apunta quien paga o quien recibe, y pendiente si lo apunta un tercero", async () => {
    const cases: [Record<string, unknown>, boolean][] = [
      [{ from: "m-ana", to: "m-beto" }, true],
      [{ from: "m-beto", to: "m-ana" }, true],
      [{ from: "m-beto", to: "m-caro" }, false],
    ];
    for (const [over, confirmed] of cases) {
      const calls = stub(world());
      expect(await addWebSettlement(baseEnv(), WEB, pay(over), defer, NOW)).toEqual({ ok: true, status: "applied" });
      const [a] = applies(calls);
      expect(a?.url.endsWith("/rpc/web_add_group_settlement")).toBe(true);
      expect(a?.body?.p_sync_id).toBe(PAY);
      expect(a?.body?.p_fields).toEqual({
        from_member_key: { from_member_key: await ref(over.from as string) },
        to_member_key: { to_member_key: await ref(over.to as string) },
        smoney: { amount: 25.5, currency_code: "PEN" },
        date: { date: "2026-11-14T15:00:00.000Z" },
        is_confirmed: { is_confirmed: confirmed },
        recorded_by_member_key: { recorded_by_member_key: await ref("m-ana") },
      });
      const alerts = (fanOut.mock.calls.at(-1) as unknown as unknown[])[6] as Record<string, { locKey: string }>;
      expect(alerts[GID]?.locKey).toBe("notifications.groups.push.settlementAdded");
    }
  });

  it("rechaza pagarse a sí mismo o a quien ya no está; un pago repetido no se escribe dos veces", async () => {
    for (const over of [{ to: "m-ana" }, { to: "m-dani" }]) {
      const calls = stub(world());
      expect(await addWebSettlement(baseEnv(), WEB, pay(over), defer, NOW)).toEqual({ ok: false, error: "invalid", detail: "members" });
      expect(applies(calls)).toHaveLength(0);
    }
    const w = world();
    w.settlements.push({ sync_id: PAY });
    const calls = stub(w);
    expect(await addWebSettlement(baseEnv(), WEB, pay(), defer, NOW)).toEqual({ ok: true, status: "already" });
    expect(applies(calls)).toHaveLength(0);
  });
});

describe("WebGroupsWriter · invitar", () => {
  it("con el formato de enlace de la app, y `s` lleva la forma mínima", async () => {
    const calls = stub(world());
    const r = await createWebInvite(baseEnv(), WEB, GID, NOW);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    const inv = calls.find((c) => c.url.endsWith("/rpc/create_group_invite"));
    expect(inv?.body).toEqual({ p_group_id: GID, p_ttl_seconds: 7 * 24 * 3600, p_max_uses: 20 });
    const u = new URL(r.url);
    expect(`${u.origin}${u.pathname}`).toBe("https://yala-app.pe/invite");
    expect(u.searchParams.get("g")).toBe(GID);
    expect(u.searchParams.get("t")).toBe("0123456789abcdef0123456789abcdef");
    const s = u.searchParams.get("s")!;
    expect(atob(s.replace(/-/g, "+").replace(/_/g, "/"))).toBe(`https://yala-app.pe/invite?g=${GID}&t=0123456789abcdef0123456789abcdef`);
    expect(u.searchParams.get("n")).toBe("Viaje");
    expect(u.searchParams.get("c")).toBe("FF8800");
    expect(u.searchParams.get("m")).toBe("Ana,Beto,Caro");
    expect(u.searchParams.get("u")).toBe("Ana");
    expect(r.expiresAt).toBe(new Date(NOW + 7 * 24 * 3600 * 1000).toISOString());
  });

  it("sin ser admin y sin «miembros pueden invitar» no pide el token", async () => {
    const w = world();
    w.members[0]!.role = "member";
    const calls = stub(w);
    expect(await createWebInvite(baseEnv(), WEB, GID, NOW)).toEqual({ ok: false, error: "not_allowed", detail: "invite" });
    expect(calls.some((c) => c.url.endsWith("/rpc/create_group_invite"))).toBe(false);
    w.group.members_can_invite = true;
    stub(w);
    expect((await createWebInvite(baseEnv(), WEB, GID, NOW)).ok).toBe(true);
  });
});

describe("webHlc", () => {
  it("tiene el formato de `HLC.description` de la app", () => {
    expect(webHlc(Date.UTC(2026, 0, 2, 3, 4, 5, 6), "00112233445566ff")).toBe("2026-01-02T03:04:05.006Z-0000-00112233445566ff");
  });
});
