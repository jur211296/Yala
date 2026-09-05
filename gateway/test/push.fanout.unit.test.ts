/**
 * Units OFFLINE del fan-out de silent push (G8-1) + guard de auth del registro. 100% sin red (fetch
 * stubbeado): corren en CI como los unit de apns.sign/attest. Ejercen `fanOutGroupPush` como función pura
 * (env + JWT dummy + fetch stub) — no pegan a staging ni a APNs reales.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Hono } from "hono";
import { exportPKCS8, generateKeyPair } from "jose";
import type { Env } from "../src/env";
import { fanOutGroupPush } from "../src/groups/routes";
import { handlePushRegister } from "../src/push/register";
import { notifyMembershipChange } from "../src/groups/rpc";
import { _resetJwtCacheForTests } from "../src/push/apns";

const RPC_URL = "https://stub.local";

async function makePem(): Promise<string> {
  const { privateKey } = await generateKeyPair("ES256", { extractable: true });
  return exportPKCS8(privateKey);
}

/** Env base para el fan-out. Sin RATE_LIMITER (skip del rate-limit); ENFORCE observe (attest opcional).
 *  G8-3: PUSH_ROLE_JWT presente por default (el stub de fetch NO lo verifica) — el fan-out lo exige tras g8_02;
 *  para probar el short-circuit se pasa `{ PUSH_ROLE_JWT: undefined }` en overrides. */
function makeFanoutEnv(pem: string | undefined, overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    APPLE_TEAM_ID: "3WKFFVD66J",
    APPLE_BUNDLE_IDS: "com.jurgenschmidt.yala.dev",
    APNS_KEY_ID: pem ? "TESTKEYID1" : undefined,
    APNS_AUTH_KEY: pem,
    SUPABASE_URL: RPC_URL,
    SUPABASE_ANON_KEY: "anon-stub",
    PUSH_ROLE_JWT: "machine.jwt.token",
    ...overrides,
  } as unknown as Env;
}

const AUTH = { userJWT: "dummy.jwt.token", sub: "u-a" };

interface Recorded {
  url: string;
  init?: RequestInit;
}

/** Stub de fetch: registra cada llamada; responde según un router por-URL. */
function stubFetch(router: (url: string, init?: RequestInit) => Response, sink: Recorded[]) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const u = typeof url === "string" ? url : url instanceof URL ? url.toString() : (url as Request).url;
      sink.push({ url: u, init });
      return router(u, init);
    }),
  );
}

function tokensResponse(rows: Array<{ user_id: string; device_token: string; platform: string }>): Response {
  return new Response(JSON.stringify(rows), { status: 200, headers: { "content-type": "application/json" } });
}

const APPLE_OK = () => new Response("{}", { status: 200, headers: { "apns-id": "x" } });

describe("fanOutGroupPush — units offline", () => {
  beforeEach(() => _resetJwtCacheForTests());
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("short-circuit sin APNS_KEY_ID: cero fetches (ni PostgREST ni Apple)", async () => {
    const calls: Recorded[] = [];
    stubFetch(() => APPLE_OK(), calls);
    await fanOutGroupPush(makeFanoutEnv(undefined), AUTH, ["g-1"]);
    expect(calls.length).toBe(0);
  });

  it("short-circuit sin PUSH_ROLE_JWT (G8-3): cero fetches (credencial de máquina ausente)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => APPLE_OK(), calls);
    // APNs SÍ configurado (pem) pero sin PUSH_ROLE_JWT → short-circuit tras el guard de APNs.
    await fanOutGroupPush(makeFanoutEnv(pem, { PUSH_ROLE_JWT: undefined }), AUTH, ["g-1"]);
    expect(calls.length).toBe(0);
  });

  it("G8-3: get_group_push_tokens se llama con p_exclude_user_id=auth.sub + p_exclude_device_token (device emisor)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokensResponse([]);
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    const emitter = "e".repeat(64);
    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"], emitter);

    const rpc = calls.find((c) => c.url.includes("/rpc/get_group_push_tokens"));
    expect(rpc).toBeDefined();
    const args = JSON.parse(rpc!.init?.body as string);
    expect(args.p_group_id).toBe("g-1");
    expect(args.p_exclude_user_id).toBe("u-a"); // auth.sub
    expect(args.p_exclude_device_token).toBe(emitter);
  });

  it("G8-3: sin device emisor → p_exclude_device_token null (fallback G8-1: excluye TODOS los devices del autor)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokensResponse([]);
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]); // sin 4º arg → default null

    const rpc = calls.find((c) => c.url.includes("/rpc/get_group_push_tokens"));
    const args = JSON.parse(rpc!.init?.body as string);
    expect(args.p_exclude_device_token).toBeNull();
  });

  it("happy path: 1 grupo → get_group_push_tokens + 1 push a Apple (host por platform, payload yala)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) {
        return tokensResponse([{ user_id: "u-b", device_token: "b".repeat(64), platform: "ios-sandbox" }]);
      }
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);

    const apple = calls.filter((c) => c.url.includes("push.apple.com"));
    expect(apple.length).toBe(1);
    expect(apple[0].url).toContain("api.sandbox.push.apple.com"); // ios-sandbox
    expect(apple[0].url).toContain("b".repeat(64));
    const headers = apple[0].init?.headers as Record<string, string>;
    // g8_03 (2026-09-03): de `background`/5 a `alert`/10. El aviso deja de depender de que iOS
    // despierte a la app — con `background`, si no entregaba el silent push no había notificación.
    expect(headers["apns-push-type"]).toBe("alert");
    expect(headers["apns-priority"]).toBe("10");
    const payload = JSON.parse(apple[0].init?.body as string);
    // La alerta que pinta el sistema. Genérica: nombre de grupo, concepto e importe son bytea † en el
    // DDL y el Worker no los puede leer.
    expect(payload.aps.alert["loc-key"]).toBe("notifications.groups.remoteActivity");
    // El eco silencioso sigue viajando en el MISMO push: es lo que permite que la app reemplace el
    // banner pobre por el rico. Sin esta aserción, quitarlo dejaría el test verde con la alerta sola.
    expect(payload.aps["content-available"]).toBe(1);
    expect(payload.yala.kind).toBe("groups-sync");
  });

  it("dedup cross-grupo: un member en 2 grupos del batch recibe UN solo push", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    const shared = { user_id: "u-b", device_token: "b".repeat(64), platform: "ios-prod" };
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokensResponse([shared]);
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1", "g-2"]);

    // 2 grupos → 2 RPCs de tokens, pero el token repetido → 1 solo push a Apple.
    expect(calls.filter((c) => c.url.includes("/rpc/get_group_push_tokens")).length).toBe(2);
    expect(calls.filter((c) => c.url.includes("push.apple.com")).length).toBe(1);
  });

  it("cap de 50: 60 tokens distintos → exactamente 50 pushes a Apple", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    const rows = Array.from({ length: 60 }, (_, i) => ({
      user_id: `u-${i}`,
      device_token: i.toString(16).padStart(64, "0"),
      platform: "ios-prod",
    }));
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokensResponse(rows);
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);
    expect(calls.filter((c) => c.url.includes("push.apple.com")).length).toBe(50);
  });

  it("BadDeviceToken → prune_push_token del par (best-effort)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) {
        return tokensResponse([{ user_id: "u-b", device_token: "d".repeat(64), platform: "ios-prod" }]);
      }
      if (url.includes("push.apple.com")) {
        return new Response(JSON.stringify({ reason: "BadDeviceToken" }), { status: 400 });
      }
      if (url.includes("/rpc/prune_push_token")) return new Response(JSON.stringify({ pruned: 1 }), { status: 200 });
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);

    const prune = calls.filter((c) => c.url.includes("/rpc/prune_push_token"));
    expect(prune.length).toBe(1);
    const pruneBody = JSON.parse(prune[0].init?.body as string);
    expect(pruneBody.p_user_id).toBe("u-b");
    expect(pruneBody.p_device_token).toBe("d".repeat(64));
  });

  it("get_group_push_tokens upstream error → sin push, sin crash (best-effort)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return new Response("boom", { status: 500 });
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);
    expect(calls.filter((c) => c.url.includes("push.apple.com")).length).toBe(0);
  });
});

describe("/push/register — guard offline (sin red)", () => {
  const app = new Hono<{ Bindings: Env }>();
  app.post("/push/register", handlePushRegister);

  it("401 sin JWT (Authorization ausente → requireUserAndAttest corta antes de cualquier fetch)", async () => {
    const calls: Recorded[] = [];
    stubFetch(() => new Response("{}", { status: 200 }), calls);
    const res = await app.request(
      "/push/register",
      { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ device_token: "a".repeat(64), platform: "ios-prod" }) },
      makeFanoutEnv(undefined),
    );
    expect(res.status).toBe(401);
    expect(calls.length).toBe(0); // ni siquiera intentó verificar el JWT (no hay Bearer)
    vi.unstubAllGlobals();
  });
});

// =====================================================================================================
// g8_03 · AUDIENCIAS. El fan-out nació con una sola («los co-members activos, menos el autor») y su
// resolver estaba cableado a `get_group_push_tokens`. Los eventos de membresía necesitan otras dos, y
// elegir mal aquí no rompe nada visible: manda el aviso a QUIEN NO TOCA, en silencio.
//
// Eso es exactamente lo que estos tests existen para impedir. Una solicitud de entrada notificada a
// todo el grupo, o el aviso de «te respondieron» disparado con la RPC que excluye a los rechazados
// (y que por tanto no avisaría a nadie), pasarían inadvertidos sin ellos.
// =====================================================================================================
describe("fanOutGroupPush — audiencias (g8_03)", () => {
  beforeEach(() => {
    _resetJwtCacheForTests();
  });
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("audiencia `admins` → llama a get_group_admin_push_tokens, NO al resolver de co-members", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_admin_push_tokens")) {
        return tokensResponse([{ user_id: "u-admin", device_token: "c".repeat(64), platform: "ios-sandbox" }]);
      }
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"], null, { kind: "admins" }, "notifications.groups.remotePendingRequest");

    // El resolver correcto, y el de co-members NI SE ROZA: usarlo avisaría a todo el grupo de una
    // solicitud que sólo incumbe a quien puede aprobarla.
    expect(calls.some((c) => c.url.includes("/rpc/get_group_admin_push_tokens"))).toBe(true);
    expect(calls.some((c) => c.url.includes("/rpc/get_group_push_tokens"))).toBe(false);

    const rpc = calls.find((c) => c.url.includes("/rpc/get_group_admin_push_tokens"));
    const args = JSON.parse(rpc!.init?.body as string);
    expect(args.p_group_id).toBe("g-1");
    expect(args.p_exclude_user_id).toBe(AUTH.sub); // el solicitante no se avisa a sí mismo

    const payload = JSON.parse(calls.find((c) => c.url.includes("push.apple.com"))!.init?.body as string);
    expect(payload.aps.alert["loc-key"]).toBe("notifications.groups.remotePendingRequest");
  });

  it("audiencia `member` → get_group_member_push_tokens por member_key, y SIN excluir a nadie", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_member_push_tokens")) {
        return tokensResponse([{ user_id: "u-target", device_token: "d".repeat(64), platform: "ios-sandbox" }]);
      }
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"], null, { kind: "member", memberKey: "mk-42" }, "notifications.groups.remoteMembershipUpdate");

    const rpc = calls.find((c) => c.url.includes("/rpc/get_group_member_push_tokens"));
    expect(rpc).toBeDefined();
    const args = JSON.parse(rpc!.init?.body as string);
    expect(args.p_member_key).toBe("mk-42");
    // **NO lleva p_exclude_user_id, y es la mitad del punto.** Aquí el autor es el admin y el
    // destinatario es otro: excluir al autor no sobra, pero pasar la exclusión de la otra RPC sí
    // rompería — y el rechazado, que queda en status 'rejected', es justo a quien hay que avisar.
    expect(args.p_exclude_user_id).toBeUndefined();

    const payload = JSON.parse(calls.find((c) => c.url.includes("push.apple.com"))!.init?.body as string);
    expect(payload.aps.alert["loc-key"]).toBe("notifications.groups.remoteMembershipUpdate");
  });

  it("sin audiencia explícita → sigue siendo co-members (el llamador de siempre no cambia)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokensResponse([]);
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);

    expect(calls.some((c) => c.url.includes("/rpc/get_group_push_tokens"))).toBe(true);
    expect(calls.some((c) => c.url.includes("/rpc/get_group_admin_push_tokens"))).toBe(false);
    expect(calls.some((c) => c.url.includes("/rpc/get_group_member_push_tokens"))).toBe(false);
  });
});

// =====================================================================================================
// g8_03 · EL EMISOR ELIGE BIEN. Los tests de arriba prueban que `fanOutGroupPush` respeta la audiencia
// que le pasan; éstos prueban que `notifyMembershipChange` le pasa la correcta.
//
// La distinción NO es académica: se descubrió por mutación. Cambiando `{kind:"admins"}` por
// `{kind:"coMembers"}` en el emisor, TODA la batería seguía verde — los goldens de membresía no miran
// el fan-out y los units de audiencia llaman a la función directamente. El defecto que eso deja pasar
// es que una solicitud de entrada, que sólo incumbe a quien puede aprobarla, se anuncie a todo el
// grupo. Silencioso y en producción.
// =====================================================================================================
describe("notifyMembershipChange — el emisor elige la audiencia (g8_03)", () => {
  beforeEach(() => {
    _resetJwtCacheForTests();
  });
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  /** `c` mínimo: sólo lo que toca el emisor (env + executionCtx). El ctx COLECTA las promesas. */
  function fakeCtx(env: Env, sink: Promise<unknown>[]) {
    return {
      env,
      get executionCtx() {
        return { waitUntil: (p: Promise<unknown>) => sink.push(p), passThroughOnException() {} };
      },
    } as unknown as Parameters<typeof notifyMembershipChange>[0];
  }

  it("join_group pendiente → audiencia ADMINS (no todo el grupo)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/")) return tokensResponse([]);
      return APPLE_OK();
    }, calls);

    const pending: Promise<unknown>[] = [];
    notifyMembershipChange(fakeCtx(makeFanoutEnv(pem), pending), AUTH, "join_group", {
      group_id: "g-1",
      member_key: "mk-1",
      status: "pendingApproval",
      changed: true,
    });
    await Promise.all(pending);

    expect(calls.some((c) => c.url.includes("/rpc/get_group_admin_push_tokens"))).toBe(true);
    expect(calls.some((c) => c.url.includes("/rpc/get_group_push_tokens"))).toBe(false);
  });

  // ---------------------------------------------------------------------------------------------
  // rejoin-tap-renotifies-admins · el `status` NO alcanza para decidir, y creerlo fue un bug vivo en
  // producción: `pendingApproval` vale tanto para «acaba de solicitar» como para «ya lo había
  // solicitado y vuelve a tocar el enlace». El segundo no cambia nada y despertaba al admin por tap.
  // El discriminante es `changed` (g13_04). Estos tres casos son el contrato entero del gate.
  // ---------------------------------------------------------------------------------------------
  it("join_group de quien YA estaba pendiente y re-toca el enlace → no avisa a nadie (changed:false)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => APPLE_OK(), calls);

    const pending: Promise<unknown>[] = [];
    // La rama no-op del RPC devuelve el estado que la persona YA tenía. Con `pendingApproval` el
    // filtro por status no lo distingue del alta nueva: sin `changed`, esto era un push al admin.
    notifyMembershipChange(fakeCtx(makeFanoutEnv(pem), pending), AUTH, "join_group", {
      group_id: "g-1",
      member_key: "mk-1",
      status: "pendingApproval",
      changed: false,
    });
    await Promise.all(pending);

    expect(calls.length).toBe(0);
  });

  it("join_group de un RECHAZADO que vuelve a entrar → SÍ avisa (changed:true, y este no hay que apagarlo)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/")) return tokensResponse([]);
      return APPLE_OK();
    }, calls);

    const pending: Promise<unknown>[] = [];
    // Rama de re-activación (rejected/removed → pendingApproval): transición REAL. Es el caso que
    // arregló `rejected-member-cold-tap-does-nothing`; gatearlo por `rebound` lo habría vuelto a
    // romper, porque esta rama devuelve `rebound:false` igual que el no-op.
    notifyMembershipChange(fakeCtx(makeFanoutEnv(pem), pending), AUTH, "join_group", {
      group_id: "g-1",
      member_key: "mk-1",
      status: "pendingApproval",
      rebound: false,
      changed: true,
    });
    await Promise.all(pending);

    expect(calls.some((c) => c.url.includes("/rpc/get_group_admin_push_tokens"))).toBe(true);
  });

  it("join_group SIN campo `changed` (servidor aún sin g13_04) → avisa igual: el fail-open es deliberado", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/")) return tokensResponse([]);
      return APPLE_OK();
    }, calls);

    const pending: Promise<unknown>[] = [];
    // El despliegue no es atómico. Si este Worker sale antes que la migración, exigir `changed===true`
    // dejaría a los admins sin enterarse de NINGUNA solicitud — más grave y más silencioso que el
    // ruido que arregla. Ausente ⇒ comportamiento de hoy. Este test PINNEA esa elección: si alguien
    // endurece el gate a `changed !== true`, se entera aquí y no en producción.
    notifyMembershipChange(fakeCtx(makeFanoutEnv(pem), pending), AUTH, "join_group", {
      group_id: "g-1",
      member_key: "mk-1",
      status: "pendingApproval",
    });
    await Promise.all(pending);

    expect(calls.some((c) => c.url.includes("/rpc/get_group_admin_push_tokens"))).toBe(true);
  });

  it("join_group de alguien YA activo → no avisa a nadie (re-tap del enlace no es noticia)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => APPLE_OK(), calls);

    const pending: Promise<unknown>[] = [];
    // La rama «ya eras miembro» del RPC devuelve status 'active' sin haber cambiado nada. Notificar
    // aquí spamearía a los admins cada vez que alguien reabre el enlace de invitación.
    notifyMembershipChange(fakeCtx(makeFanoutEnv(pem), pending), AUTH, "join_group", {
      group_id: "g-1",
      member_key: "mk-1",
      status: "active",
    });
    await Promise.all(pending);

    expect(calls.length).toBe(0);
  });

  it("approve_member y remove_member → audiencia MEMBER, por su member_key", async () => {
    for (const fn of ["approve_member", "remove_member"]) {
      const pem = await makePem();
      const calls: Recorded[] = [];
      stubFetch((url) => {
        if (url.includes("/rpc/")) return tokensResponse([]);
        return APPLE_OK();
      }, calls);

      const pending: Promise<unknown>[] = [];
      notifyMembershipChange(fakeCtx(makeFanoutEnv(pem), pending), AUTH, fn, {
        group_id: "g-1",
        member_key: "mk-42",
        status: fn === "approve_member" ? "active" : "rejected",
      });
      await Promise.all(pending);

      const rpc = calls.find((c) => c.url.includes("/rpc/get_group_member_push_tokens"));
      expect(rpc, `${fn} debería resolver por member`).toBeDefined();
      expect(JSON.parse(rpc!.init?.body as string).p_member_key).toBe("mk-42");
      // El de co-members EXCLUYE a los no-activos: usarlo para un rechazo no avisaría a nadie.
      expect(calls.some((c) => c.url.includes("/rpc/get_group_push_tokens"))).toBe(false);
      vi.unstubAllGlobals();
    }
  });

  it("un RPC que no toca membresía no dispara nada", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => APPLE_OK(), calls);
    const pending: Promise<unknown>[] = [];
    notifyMembershipChange(fakeCtx(makeFanoutEnv(pem), pending), AUTH, "create_group", { group_id: "g-1" });
    await Promise.all(pending);
    expect(calls.length).toBe(0);
  });

  it("sin ExecutionContext no lanza: el aviso se omite, el RPC no se convierte en 500", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => APPLE_OK(), calls);
    // Hono LANZA al acceder a `executionCtx` si el Worker se invocó sin él (`app.fetch(req, env)`).
    // Un RPC que YA tuvo éxito no puede acabar en 500 por un aviso best-effort.
    const cSinCtx = {
      env: makeFanoutEnv(pem),
      get executionCtx(): never {
        throw new Error("This context has no ExecutionContext");
      },
    } as unknown as Parameters<typeof notifyMembershipChange>[0];

    expect(() =>
      notifyMembershipChange(cSinCtx, AUTH, "join_group", { group_id: "g-1", member_key: "mk-1", status: "pendingApproval" }),
    ).not.toThrow();
    expect(calls.length).toBe(0);
  });
});
