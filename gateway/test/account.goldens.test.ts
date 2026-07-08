/**
 * Goldens de I7a — `/account/claim` + `/account/exists` contra STAGING REAL (network ON). Ejercen el
 * Worker end-to-end vía `app.fetch(...)`: verifica el JWT (ES256/JWKS) y llama al RPC `claim_account`
 * (SECURITY INVOKER, `auth.uid()` adentro) con el JWT del USUARIO (RLS).
 *
 * NO corren en CI (necesitan red + los 2 usuarios de test sembrados en I5).
 *
 * ESTADO PREVIO REQUERIDO: los `profiles` de los 2 subs de test deben estar VACÍOS al empezar (el test 1
 * exige que la fila NO preexista para ver `created`; `profiles` tiene 1 fila por sub, PK = id, y `DELETE`
 * está revocado). Limpia con `DELETE FROM profiles WHERE id IN (<subA>,<subB>)` en contexto service
 * (SQL editor / MCP) ANTES de correr — ver qa/cloud/README. Los tests que necesitan estado in-progress lo
 * fijan por un PATCH directo a PostgREST con el JWT del propio dueño (RLS UPDATE lo permite; sin service_role).
 */
import { beforeAll, describe, expect, it } from "vitest";
import app from "../src/index";
import type { Env } from "../src/env";

const URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";

const env = {
  ENVIRONMENT: "staging",
  ENFORCE: "observe",
  JWT_SIGNING_SECRET: "test-secret-please-change-0123456789",
  SUPABASE_URL: URL,
  SUPABASE_ANON_KEY: ANON,
} as unknown as Env;

let jwtA = "";
let jwtB = "";
let subA = "";
let subB = "";

function decodeSub(jwt: string): string {
  let p = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
  p += "=".repeat((4 - (p.length % 4)) % 4);
  return (JSON.parse(atob(p)) as { sub: string }).sub;
}
async function login(email: string, password: string): Promise<string> {
  const res = await fetch(`${URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const body = (await res.json()) as { access_token?: string };
  if (!body.access_token) throw new Error(`login ${email} failed: ${JSON.stringify(body)}`);
  return body.access_token;
}

interface ClaimResult {
  state?: "created" | "existing_stable" | "claiming_in_progress";
  profile?: Record<string, unknown>;
}

async function claim(jwt: string, body: Record<string, unknown>): Promise<{ status: number; body: ClaimResult }> {
  const res = await app.fetch(
    new Request("https://gw.local/account/claim", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
    env,
  );
  return { status: res.status, body: (await res.json()) as ClaimResult };
}

async function exists(jwt: string): Promise<boolean> {
  const res = await app.fetch(
    new Request("https://gw.local/account/exists", { method: "GET", headers: { Authorization: `Bearer ${jwt}` } }),
    env,
  );
  return ((await res.json()) as { exists: boolean }).exists;
}

/** PATCH directo a `profiles` con el JWT del dueño (RLS UPDATE lo permite) para fijar estado in-progress. */
async function patchProfile(jwt: string, patch: Record<string, unknown>): Promise<number> {
  const sub = decodeSub(jwt);
  const res = await fetch(`${URL}/rest/v1/profiles?id=eq.${sub}`, {
    method: "PATCH",
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json", Prefer: "return=minimal" },
    body: JSON.stringify(patch),
  });
  return res.status;
}
async function readProfileId(jwt: string): Promise<string | null> {
  const sub = decodeSub(jwt);
  const res = await fetch(`${URL}/rest/v1/profiles?id=eq.${sub}&select=id`, {
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}` },
  });
  const rows = (await res.json()) as { id: string }[];
  return rows[0]?.id ?? null;
}

const DEV_A = "device-A-01";
const DEV_OTHER = "device-other-99";

beforeAll(async () => {
  jwtA = await login("i5-user-a@test.yala", "I5-Passw0rd-A!");
  jwtB = await login("i5-user-b@test.yala", "I5-Passw0rd-B!");
  subA = decodeSub(jwtA);
  subB = decodeSub(jwtB);
});

describe("I7a goldens · /account/* contra staging real", () => {
  it("1. dos claims CONCURRENTES del mismo sub → exactamente uno 'created', el otro 'existing_stable'", async () => {
    // Requiere profiles[subA] AUSENTE (limpieza previa en contexto service — ver README/header).
    const [r1, r2] = await Promise.all([
      claim(jwtA, { device_id: DEV_A, provider: "apple" }),
      claim(jwtA, { device_id: DEV_A, provider: "apple" }),
    ]);
    expect(r1.status).toBe(200);
    expect(r2.status).toBe(200);
    const states = [r1.body.state, r2.body.state].sort();
    // Uno crea, el otro ve la fila ya estable (default migration_in_progress=false).
    expect(states).toEqual(["created", "existing_stable"]);
  });

  it("2. exists refleja el claim: false ANTES, true DESPUÉS (sub B, limpio)", async () => {
    // Requiere profiles[subB] AUSENTE.
    expect(await exists(jwtB)).toBe(false);
    const r = await claim(jwtB, { device_id: "device-B-01", provider: "google" });
    expect(r.body.state).toBe("created");
    expect(await exists(jwtB)).toBe(true);
  });

  it("3. claim con migration_in_progress + leader DISTINTO → 'claiming_in_progress' (sub B ya existe)", async () => {
    // Fija el estado in-progress con un líder AJENO por PATCH directo (dueño = B).
    expect(await patchProfile(jwtB, { migration_in_progress: true, leader_device_id: DEV_OTHER })).toBeLessThan(300);
    const r = await claim(jwtB, { device_id: "device-B-02", provider: "google" });
    expect(r.body.state).toBe("claiming_in_progress");
    // Limpia el estado para no contaminar corridas siguientes.
    await patchProfile(jwtB, { migration_in_progress: false, leader_device_id: null });
  });

  it("4. reclaim del MISMO leader_device_id → 'created' (idempotente, sub A)", async () => {
    expect(await patchProfile(jwtA, { migration_in_progress: true, leader_device_id: DEV_A })).toBeLessThan(300);
    const r = await claim(jwtA, { device_id: DEV_A, provider: "apple" });
    expect(r.body.state).toBe("created"); // el mismo líder reclama su propia reserva → created-equivalente
    await patchProfile(jwtA, { migration_in_progress: false, leader_device_id: null });
  });

  it("5. el sub SIEMPRE del JWT: un id ajeno en el body se ignora; la fila queda del caller", async () => {
    // A claima con el id de B inyectado en el body → el RPC usa auth.uid()=subA, resuelve la cuenta de A.
    const r = await claim(jwtA, { device_id: DEV_A, provider: "apple", id: subB, sub: subB, user_id: subB });
    expect(r.status).toBe(200);
    // A ya tiene fila estable (test 1/4) → existing_stable, NUNCA toca la cuenta de B.
    expect(r.body.state).toBe("existing_stable");
    expect(await readProfileId(jwtA)).toBe(subA); // la fila que ve A es la de A
  });
});
