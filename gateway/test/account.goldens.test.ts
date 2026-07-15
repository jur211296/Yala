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

interface ProgressResult {
  ok?: boolean;
  reason?: string;
}
async function migrationProgress(
  jwt: string,
  body: Record<string, unknown>,
): Promise<{ status: number; body: ProgressResult }> {
  const res = await app.fetch(
    new Request("https://gw.local/account/migration", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
    env,
  );
  return { status: res.status, body: (await res.json()) as ProgressResult };
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

interface ProfileRow {
  migrated_at: string | null;
  migration_in_progress: boolean;
  leader_device_id: string | null;
  reverse_in_progress: boolean;
  reverse_frozen_at: string | null;
  reverted_at: string | null;
}
async function readProfile(jwt: string): Promise<ProfileRow | null> {
  const sub = decodeSub(jwt);
  const res = await fetch(
    `${URL}/rest/v1/profiles?id=eq.${sub}&select=migrated_at,migration_in_progress,leader_device_id,reverse_in_progress,reverse_frozen_at,reverted_at`,
    { headers: { apikey: ANON, Authorization: `Bearer ${jwt}` } },
  );
  const rows = (await res.json()) as ProfileRow[];
  return rows[0] ?? null;
}
/** Lee `migration_updated_at` (el timestamp del lease) — usado por los goldens del heartbeat (I14-pre). */
async function readMigrationUpdatedAt(jwt: string): Promise<string | null> {
  const sub = decodeSub(jwt);
  const res = await fetch(`${URL}/rest/v1/profiles?id=eq.${sub}&select=migration_updated_at`, {
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}` },
  });
  const rows = (await res.json()) as { migration_updated_at: string | null }[];
  return rows[0]?.migration_updated_at ?? null;
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
  it("1. dos claims CONCURRENTES del mismo sub → exactamente uno 'created', el otro 'existing_stable'", async (ctx) => {
    // Requiere profiles[subA] AUSENTE (limpieza previa en contexto service — ver README/header).
    // SKIP limpio si el seed no está preparado (2026-07-15): el golden es one-shot-tras-seed por
    // diseño; fallar en cada corrida sin seed solo ensuciaba la suite (era el "preexistente" ×2).
    if (await exists(jwtA)) {
      console.warn("[account.goldens] golden 1 SKIP: profiles[subA] existe — corre tras el seed (delete en contexto service)");
      ctx.skip();
    }
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

  it("2. exists refleja el claim: false ANTES, true DESPUÉS (sub B, limpio)", async (ctx) => {
    // Requiere profiles[subB] AUSENTE. SKIP limpio si el seed no está (ver golden 1).
    if (await exists(jwtB)) {
      console.warn("[account.goldens] golden 2 SKIP: profiles[subB] existe — corre tras el seed (delete en contexto service)");
      ctx.skip();
    }
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

// I10-wiring w6 — cutover server-side (migration_progress + lease). Usan SOLO sub B (corren al final;
// dejan la fila en estado estable — la limpieza pre-run de la suite la resetea). Ver header.
const DEV_LEADER = "device-B-leader";

describe("I10 goldens · /account/migration + lease (staging real)", () => {
  it("6. cutover por el LÍDER registrado → ok:true y estampa migrated_at (idempotente)", async () => {
    // Estado in-progress con ESTE device como líder (migrated_at limpio).
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        leader_device_id: DEV_LEADER,
        migration_updated_at: new Date().toISOString(),
        migrated_at: null,
      }),
    ).toBeLessThan(300);

    const r1 = await migrationProgress(jwtB, { device_id: DEV_LEADER, action: "cutover" });
    expect(r1.status).toBe(200);
    expect(r1.body.ok).toBe(true);
    const p1 = await readProfile(jwtB);
    expect(p1?.migrated_at).not.toBeNull(); // migrated_at quedó estampado

    // Idempotente: un 2º cutover del mismo líder NO falla ni re-mueve migrated_at.
    const r2 = await migrationProgress(jwtB, { device_id: DEV_LEADER, action: "cutover" });
    expect(r2.body.ok).toBe(true);
    expect((await readProfile(jwtB))?.migrated_at).toBe(p1?.migrated_at);
  });

  it("7. complete por el líder → ok:true, migration_in_progress=false (returning-user correcto)", async () => {
    // Continúa del estado del test 6 (líder = DEV_LEADER, mip=true, migrated_at estampado).
    const r = await migrationProgress(jwtB, { device_id: DEV_LEADER, action: "complete" });
    expect(r.body.ok).toBe(true);
    expect((await readProfile(jwtB))?.migration_in_progress).toBe(false);

    // Idempotente tras el flip (leader match basta): un resume del complete no debe romper.
    expect((await migrationProgress(jwtB, { device_id: DEV_LEADER, action: "complete" })).body.ok).toBe(true);
  });

  it("8. otro líder → ok:false, reason 'other_leader' (el usurpado corta y converge a follower)", async () => {
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        leader_device_id: "device-other-usurper",
        migration_updated_at: new Date().toISOString(),
      }),
    ).toBeLessThan(300);
    const r = await migrationProgress(jwtB, { device_id: DEV_LEADER, action: "cutover" });
    expect(r.body.ok).toBe(false);
    expect(r.body.reason).toBe("other_leader");
    // Limpia.
    await patchProfile(jwtB, { migration_in_progress: false, leader_device_id: null });
  });

  it("9. lease expiry: claim(migration) con líder ANTIGUO (>60min) → 'created' (takeover)", async () => {
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        leader_device_id: "device-stale-leader",
        migration_updated_at: "2000-01-01T00:00:00Z", // heartbeat vencido
      }),
    ).toBeLessThan(300);
    const r = await claim(jwtB, { device_id: DEV_LEADER, provider: "google", migration: true });
    expect(r.body.state).toBe("created"); // takeover: este device toma el liderazgo
    expect((await readProfile(jwtB))?.leader_device_id).toBe(DEV_LEADER);
    // Limpia el estado in-progress.
    await patchProfile(jwtB, { migration_in_progress: false, leader_device_id: null });
  });

  it("9-bis. takeover DENEGADO a p_migration=false: born-cloud sobre lease vencida → 'claiming_in_progress' (SERIO 2)", async () => {
    // SERIO 2 del review adversarial: un caller NO-migración (born-cloud/returning-user) sobre una
    // migración abortada >60min JAMÁS usurpa la lease — recibiría 'created' y sembraría defaults ENCIMA
    // de datos parcialmente migrados, dejando mip=true colgado. Debe recibir claiming_in_progress y
    // encaminar a espera/adopt, nunca sembrar.
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        leader_device_id: "device-stale-leader",
        migration_updated_at: "2000-01-01T00:00:00Z", // heartbeat vencido
      }),
    ).toBeLessThan(300);
    const r = await claim(jwtB, { device_id: DEV_LEADER, provider: "google" }); // SIN migration
    expect(r.body.state).toBe("claiming_in_progress"); // denegado: la lease vencida NO es suya
    expect((await readProfile(jwtB))?.leader_device_id).toBe("device-stale-leader"); // líder intacto
    // Limpia el estado in-progress.
    await patchProfile(jwtB, { migration_in_progress: false, leader_device_id: null });
  });

  it("10. claim(migration) sobre fila EXISTENTE estable → 'existing_stable' (el mip se arma solo en el INSERT)", async () => {
    expect(
      await patchProfile(jwtB, { migration_in_progress: false, leader_device_id: null }),
    ).toBeLessThan(300);
    const r = await claim(jwtB, { device_id: DEV_LEADER, provider: "google", migration: true });
    expect(r.body.state).toBe("existing_stable"); // fila ya existe → nunca re-arma mip aquí
    expect((await readProfile(jwtB))?.migration_in_progress).toBe(false);
  });
});

// I11-3 — reversa server-side (§h): las 4 acciones reverse_* del RPC. Usan sub B (ya migrado por los
// goldens 6-7) salvo el 11 (sub A, jamás migrado). Corren en orden y dejan la fila de B estable
// (rip=false) — la limpieza pre-run de la suite la resetea igual. Ver header.
const DEV_REV = "device-B-rev-leader";
const DEV_REV_OTHER = "device-rev-usurper";

describe("I11-3 goldens · /account/migration reverse_* (staging real)", () => {
  it("11. reverse_claim sobre cuenta NO migrada → 'not_migrated' (born-cloud v1 excluido)", async () => {
    // Sub A tiene fila (test 1) pero jamás migró → migrated_at null.
    expect((await readProfile(jwtA))?.migrated_at).toBeNull();
    const r = await migrationProgress(jwtA, { device_id: DEV_A, action: "reverse_claim" });
    expect(r.status).toBe(200);
    expect(r.body.ok).toBe(false);
    expect(r.body.reason).toBe("not_migrated");
  });

  it("12. takeover reverse-sobre-migración-ABANDONADA: lease vigente → 'migration_in_progress'; vencida → ok + mip=false + rip=true", async () => {
    // El modo de fallo real del device run 2026-07-10: líder crasheado entre cutover y complete →
    // mip=true colgado para siempre. Sin el takeover, esa cuenta jamás podría revertir.
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        leader_device_id: "device-stale-leader",
        migration_updated_at: new Date().toISOString(), // lease VIGENTE
        migrated_at: "2026-01-01T00:00:00Z", // cutover ya ocurrió (autocontenido)
        reverse_in_progress: false,
      }),
    ).toBeLessThan(300);

    const r1 = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_claim" });
    expect(r1.body.ok).toBe(false);
    expect(r1.body.reason).toBe("migration_in_progress"); // lease vigente: la ida aún manda

    expect(await patchProfile(jwtB, { migration_updated_at: "2000-01-01T00:00:00Z" })).toBeLessThan(300);
    const r2 = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_claim" });
    expect(r2.body.ok).toBe(true); // lease vencida: la reversa TOMA
    const p = await readProfile(jwtB);
    expect(p?.migration_in_progress).toBe(false);
    expect(p?.reverse_in_progress).toBe(true);
    expect(p?.leader_device_id).toBe(DEV_REV);
    // Limpia para el ciclo completo del test 13.
    await patchProfile(jwtB, { reverse_in_progress: false, leader_device_id: null });
  });

  it("13. ciclo completo: migrar (patrón 6-7) → reverse_claim por el líder → ok + reverse_in_progress=true", async () => {
    // Migra con el patrón de los goldens 6-7: arma lease + cutover + complete.
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        leader_device_id: DEV_REV,
        migration_updated_at: new Date().toISOString(),
        migrated_at: null,
        reverse_frozen_at: null,
        reverted_at: null,
      }),
    ).toBeLessThan(300);
    expect((await migrationProgress(jwtB, { device_id: DEV_REV, action: "cutover" })).body.ok).toBe(true);
    expect((await migrationProgress(jwtB, { device_id: DEV_REV, action: "complete" })).body.ok).toBe(true);

    const r = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_claim" });
    expect(r.body.ok).toBe(true);
    const p = await readProfile(jwtB);
    expect(p?.reverse_in_progress).toBe(true);
    expect(p?.leader_device_id).toBe(DEV_REV);
    expect(p?.migrated_at).not.toBeNull(); // la reversa NO toca migrated_at
  });

  it("14. re-claim mismo device → ok idempotente; otro device lease vigente → 'other_leader'; vencida → takeover", async () => {
    // Estado del test 13: rip=true, líder=DEV_REV, heartbeat fresco.
    const r1 = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_claim" });
    expect(r1.body.ok).toBe(true); // re-claim tras kill: SIN chequear edad del lease para el MISMO líder

    const r2 = await migrationProgress(jwtB, { device_id: DEV_REV_OTHER, action: "reverse_claim" });
    expect(r2.body.ok).toBe(false);
    expect(r2.body.reason).toBe("other_leader"); // lease vigente: nadie usurpa

    expect(await patchProfile(jwtB, { migration_updated_at: "2000-01-01T00:00:00Z" })).toBeLessThan(300);
    const r3 = await migrationProgress(jwtB, { device_id: DEV_REV_OTHER, action: "reverse_claim" });
    expect(r3.body.ok).toBe(true); // lease vencida: takeover
    expect((await readProfile(jwtB))?.leader_device_id).toBe(DEV_REV_OTHER);
    // Devuelve el liderazgo a DEV_REV para los tests siguientes.
    await patchProfile(jwtB, { leader_device_id: DEV_REV, migration_updated_at: new Date().toISOString() });
  });

  it("15. reverse_freeze: no-líder → 'other_leader'; líder → ok + reverse_frozen_at set (idempotente, sin edad de lease)", async () => {
    const rBad = await migrationProgress(jwtB, { device_id: DEV_REV_OTHER, action: "reverse_freeze" });
    expect(rBad.body.ok).toBe(false);
    expect(rBad.body.reason).toBe("other_leader");

    // El MISMO líder pasa aunque su lease esté vencida (el lease existe SOLO para que competidores usurpen).
    expect(await patchProfile(jwtB, { migration_updated_at: "2000-01-01T00:00:00Z" })).toBeLessThan(300);
    const r1 = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_freeze" });
    expect(r1.body.ok).toBe(true);
    const frozen = (await readProfile(jwtB))?.reverse_frozen_at;
    expect(frozen).not.toBeNull();

    // Idempotente: un 2º freeze no re-mueve el timestamp.
    expect((await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_freeze" })).body.ok).toBe(true);
    expect((await readProfile(jwtB))?.reverse_frozen_at).toBe(frozen);
  });

  it("16. reverse_complete líder → rip=false + reverted_at set + migrated_at INTACTO (idempotente)", async () => {
    const before = await readProfile(jwtB);
    expect(before?.migrated_at).not.toBeNull();

    const r = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_complete" });
    expect(r.body.ok).toBe(true);
    const p = await readProfile(jwtB);
    expect(p?.reverse_in_progress).toBe(false);
    expect(p?.reverted_at).not.toBeNull();
    expect(p?.migrated_at).toBe(before?.migrated_at); // §h.4: el backend congelado sigue marcando "migró una vez"

    // Idempotente tras el flip (resume del complete): rip ya false + reverted_at set → ok.
    expect((await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_complete" })).body.ok).toBe(true);
    expect((await readProfile(jwtB))?.reverted_at).toBe(p?.reverted_at);
  });

  it("17. reverse_abort desde claim fresco + freeze → rip=false + reverse_frozen_at=null + reverted_at=null (DES-congela)", async () => {
    // Claim FRESCO sobre la cuenta ya revertida (2ª reversa = variante migrado, §h.6): debe resetear
    // reverse_frozen_at Y reverted_at del run anterior (test 16 los dejó set).
    const rc = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_claim" });
    expect(rc.body.ok).toBe(true);
    const pc = await readProfile(jwtB);
    expect(pc?.reverted_at).toBeNull(); // el claim fresco resetea los marcadores del run anterior
    expect(pc?.reverse_frozen_at).toBeNull();

    expect((await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_freeze" })).body.ok).toBe(true);
    expect((await readProfile(jwtB))?.reverse_frozen_at).not.toBeNull();

    const ra = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_abort" });
    expect(ra.body.ok).toBe(true);
    const p = await readProfile(jwtB);
    expect(p?.reverse_in_progress).toBe(false);
    expect(p?.reverse_frozen_at).toBeNull(); // DES-congelado
    expect(p?.reverted_at).toBeNull(); // la reversa NO ocurrió

    // Idempotente: un 2º abort con rip ya false → ok.
    expect((await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_abort" })).body.ok).toBe(true);
  });

  it("18. acción inválida → 400 del Worker (nunca llega al RPC)", async () => {
    const r = await migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_nuke" });
    expect(r.status).toBe(400);
  });

  it("22. dos reverse_claim CONCURRENTES → exactamente uno ok:true, el otro 'other_leader' (CAS — asimetría CERRADA)", async () => {
    // Cierre de la ASIMETRÍA del review I11-3 (migración i11_reverse_claim_cas): pre-CAS, dos devices
    // reclamando a la vez podían recibir AMBOS ok:true (read-then-UPDATE). El golden FOUND-false
    // SECUENCIAL no es representable — el read y el UPDATE condicional viven dentro de la MISMA
    // llamada al RPC, y patchProfile solo puede pre-setear ANTES de la llamada. La carrera REAL vía
    // Promise.all (patrón del golden 1 de claim_account) sí lo es, y el assert es determinista
    // post-fix en AMBOS interleavings: carrera real → el CAS mata al perdedor (FOUND=false);
    // secuencial → el guard de lease vigente. Pre-fix, la carrera real daba 2 ok (flaky-caza-bug).
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: false,
        reverse_in_progress: false,
        leader_device_id: null,
        migrated_at: "2026-01-01T00:00:00Z", // cuenta migrada (autocontenido)
        reverse_frozen_at: null,
        reverted_at: null,
      }),
    ).toBeLessThan(300);

    const [r1, r2] = await Promise.all([
      migrationProgress(jwtB, { device_id: DEV_REV, action: "reverse_claim" }),
      migrationProgress(jwtB, { device_id: DEV_REV_OTHER, action: "reverse_claim" }),
    ]);
    expect(r1.status).toBe(200);
    expect(r2.status).toBe(200);
    const winners = [r1, r2].filter((r) => r.body.ok === true);
    const losers = [r1, r2].filter((r) => r.body.ok === false);
    expect(winners).toHaveLength(1); // JAMÁS dual-líder, ni transitorio
    expect(losers).toHaveLength(1);
    expect(losers[0].body.reason).toBe("other_leader");

    // El líder registrado es exactamente el device del ganador.
    const winnerDev = r1.body.ok ? DEV_REV : DEV_REV_OTHER;
    const p = await readProfile(jwtB);
    expect(p?.reverse_in_progress).toBe(true);
    expect(p?.leader_device_id).toBe(winnerDev);

    // Deja la fila estable (patrón de la suite).
    await patchProfile(jwtB, { reverse_in_progress: false, leader_device_id: null });
  });
});

// Enforcement del freeze en /sync/push (cierre del DIFERIDO de qa/cloud/README, §h.1). VIVEN AQUÍ y no
// en sync.goldens.test.ts A PROPÓSITO: vitest corre los archivos en PARALELO y estos tests congelan el
// profile de un usuario — hacerlo con sub A rompería los pushes concurrentes de sync.goldens (que pushea
// SOLO como A). Sub B se manipula ÚNICAMENTE en este archivo (secuencial) → sin race cross-file.

/** Push mínimo como en sync.goldens (columna `note`, safe field-level — sin grupo de coherencia). */
function hlcOf(ms: number): string {
  return `${new Date(ms).toISOString()}-0001-00000000000000bb`;
}
function txDelta(syncId: string, note: string, hlc: string): Record<string, unknown> {
  return {
    entity_type: "tx_items",
    sync_id: syncId,
    op: "upsert",
    fields: { note },
    field_hlcs: { note: hlc },
    hlc,
    client_mutation_id: crypto.randomUUID(),
  };
}
async function pushDeltas(jwt: string, deltas: unknown[]): Promise<{ status: number; body: unknown }> {
  const res = await app.fetch(
    new Request("https://gw.local/sync/push", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify({ deltas }),
    }),
    env,
  );
  return { status: res.status, body: await res.json() };
}
async function getSync(jwt: string, path: string): Promise<number> {
  const res = await app.fetch(
    new Request(`https://gw.local${path}`, { method: "GET", headers: { Authorization: `Bearer ${jwt}` } }),
    env,
  );
  return res.status;
}
async function rowExists(jwt: string, syncId: string): Promise<boolean> {
  const res = await fetch(`${URL}/rest/v1/tx_items?sync_id=eq.${syncId}&select=sync_id`, {
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}` },
  });
  return ((await res.json()) as unknown[]).length > 0;
}

/** Push de prefs (espejo mínimo de pushDeltas — /prefs/push, RPC apply_pref LWW por key). */
async function pushPrefs(jwt: string, prefs: unknown[]): Promise<{ status: number; body: unknown }> {
  const res = await app.fetch(
    new Request("https://gw.local/prefs/push", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify({ prefs }),
    }),
    env,
  );
  return { status: res.status, body: await res.json() };
}
async function prefExists(jwt: string, key: string): Promise<boolean> {
  const res = await fetch(`${URL}/rest/v1/user_preferences?key=eq.${key}&select=key`, {
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}` },
  });
  return ((await res.json()) as unknown[]).length > 0;
}

describe("Freeze enforcement · /sync/push + /prefs/push con reverse_frozen_at (staging real)", () => {
  const SID0 = crypto.randomUUID();
  const SID1 = crypto.randomUUID();
  const HLC0 = hlcOf(Date.UTC(2026, 6, 11, 12, 0, 0));
  const HLC1 = hlcOf(Date.UTC(2026, 6, 11, 12, 0, 1));
  // Keys frescas por corrida (las prefs no tienen tombstone; se acumulan como los sync_id de dominio).
  const KEY0 = `freeze-probe-0-${crypto.randomUUID()}`;
  const KEY1 = `freeze-probe-1-${crypto.randomUUID()}`;

  it("19. cuenta CONGELADA → push 409 'yala_account_reverting'; leak ACOTADO al delta[0], el 2º NO entra", async () => {
    // Precondición: B tiene fila de profiles (goldens previos); un PATCH sobre fila ausente sería un
    // 204 silencioso sin congelar nada → el assert de abajo lo delataría con un 200.
    expect(await readProfileId(jwtB)).not.toBeNull();
    expect(await patchProfile(jwtB, { reverse_frozen_at: new Date().toISOString() })).toBeLessThan(300);

    // El check de freeze corre EN LA SOMBRA del primer apply (costo cero de pared para el push normal)
    // → contrato: delta[0] puede aterrizar (benigno: idempotente, backend congelado jamás vuelve a ser
    // fuente de verdad), el gate corta ANTES del 2º delta, y la respuesta es 409 request-level.
    const r = await pushDeltas(jwtB, [txDelta(SID0, "frozen-leak", HLC0), txDelta(SID1, "frozen-blocked", HLC1)]);
    expect(r.status).toBe(409);
    const err = r.body as { error?: { type?: string } };
    expect(err.error?.type).toBe("yala_account_reverting");
    expect(await rowExists(jwtB, SID0)).toBe(true); // el leak documentado (delta[0])
    expect(await rowExists(jwtB, SID1)).toBe(false); // el gate corta antes del 2º delta

    // Caso 1-delta (el gate queda al FINAL): 409 igual — el cliente hace stop sin purgar.
    const r1 = await pushDeltas(jwtB, [txDelta(SID0, "frozen-leak", HLC0)]);
    expect(r1.status).toBe(409);
  });

  it("19-bis. prefs: cuenta CONGELADA → /prefs/push 409 'yala_account_reverting'; mismo contrato de leak", async () => {
    // Sigue congelada (estado del test 19). Mismo patrón que /sync/push: check en la sombra del primer
    // apply_pref → pref[0] puede aterrizar (LWW-idempotente, backend muerto), la 2ª key NO entra.
    const r = await pushPrefs(jwtB, [
      { key: KEY0, value: "leak", hlc: HLC0 },
      { key: KEY1, value: "blocked", hlc: HLC1 },
    ]);
    expect(r.status).toBe(409);
    const err = r.body as { error?: { type?: string } };
    expect(err.error?.type).toBe("yala_account_reverting");
    expect(await prefExists(jwtB, KEY0)).toBe(true); // el leak documentado (pref[0])
    expect(await prefExists(jwtB, KEY1)).toBe(false); // el gate corta antes de la 2ª key

    // Caso 1-pref (el gate queda al FINAL): 409 igual — el cliente NO purga su outbox (solo en completed).
    expect((await pushPrefs(jwtB, [{ key: KEY0, value: "leak", hlc: HLC0 }])).status).toBe(409);
  });

  it("20. la cuenta congelada NO bloquea pull/merkle ni prefs/pull (la reversa §h DEPENDE de leer)", async () => {
    // Sigue congelada (estado del test 19). El enforcement es PUSH-only: el re-drain de la reversa
    // (backend→local) y el sweep de zombies leen vía pull/merkle con el freeze YA estampado.
    expect(await getSync(jwtB, "/sync/pull?since=0&limit=1")).toBe(200);
    expect(await getSync(jwtB, "/sync/merkle")).toBe(200);
    expect(await getSync(jwtB, "/prefs/pull?since=0")).toBe(200);
  });

  it("21. DES-congelada → los MISMOS batches entran 200 (noop el leak, applied el bloqueado — sin falso positivo residual)", async () => {
    expect(await patchProfile(jwtB, { reverse_frozen_at: null })).toBeLessThan(300);
    const r = await pushDeltas(jwtB, [txDelta(SID0, "frozen-leak", HLC0), txDelta(SID1, "frozen-blocked", HLC1)]);
    expect(r.status).toBe(200);
    const body = r.body as { results: Array<{ status: string }> };
    expect(body.results.map((x) => x.status)).toEqual(["noop", "applied"]); // SID0 ya aterrizó en el leak
    expect(await rowExists(jwtB, SID1)).toBe(true);

    // Prefs: mismo contrato (KEY0 aterrizó en el leak con el MISMO hlc → noop; KEY1 entra fresca).
    const rp = await pushPrefs(jwtB, [
      { key: KEY0, value: "leak", hlc: HLC0 },
      { key: KEY1, value: "blocked", hlc: HLC1 },
    ]);
    expect(rp.status).toBe(200);
    const pbody = rp.body as { results: Array<{ status: string }> };
    expect(pbody.results.map((x) => x.status)).toEqual(["noop", "applied"]);
    expect(await prefExists(jwtB, KEY1)).toBe(true);
  });
});

// I14-pre — heartbeat del lease (§residual pendiente #3). Refresca SOLO migration_updated_at MIENTRAS un
// paso largo (upload/drain) progresa, para que el líder no quede usurpable a mitad. Usan sub B.
// REQUIEREN el deploy `i14_heartbeat_action` (RPC) + el redeploy del Worker: pre-deploy el edge devuelve
// 400 a `heartbeat` (protege al RPC viejo) y estos 4 goldens FALLAN RUIDOSO — es el rojo ESPERADO
// documentado en qa/cloud/README (sin gate silencioso por env var, lección d49d2e47). Ver
// qa/cloud/pending-heartbeat-action.sql para el injerto SQL.
const DEV_HB = "device-B-hb-leader";
const DEV_HB_OTHER = "device-hb-usurper";

describe("I14-pre goldens · /account/migration heartbeat (staging real, REQUIERE deploy i14_heartbeat_action + Worker)", () => {
  it("23. heartbeat es acción VÁLIDA en el edge (no 400) y sin run activo → ok:false 'not_in_progress'", async () => {
    // Sin migración ni reversa en curso.
    expect(
      await patchProfile(jwtB, { migration_in_progress: false, reverse_in_progress: false, leader_device_id: null }),
    ).toBeLessThan(300);
    const r = await migrationProgress(jwtB, { device_id: DEV_HB, action: "heartbeat" });
    expect(r.status).toBe(200); // no 400: la acción es válida en el set del Worker
    expect(r.body.ok).toBe(false);
    expect(r.body.reason).toBe("not_in_progress"); // heartbeat tardío/benigno idempotente
  });

  it("24. líder de la IDA + lease retrocedido → heartbeat ok:true y refresca migration_updated_at", async () => {
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        reverse_in_progress: false,
        leader_device_id: DEV_HB,
        migration_updated_at: "2000-01-01T00:00:00Z", // lease retrocedido a propósito
      }),
    ).toBeLessThan(300);
    const before = await readMigrationUpdatedAt(jwtB);

    const r = await migrationProgress(jwtB, { device_id: DEV_HB, action: "heartbeat" });
    expect(r.body.ok).toBe(true);
    const after = await readMigrationUpdatedAt(jwtB);
    expect(after).not.toBeNull();
    expect(new Date(after!).getTime()).toBeGreaterThan(new Date(before!).getTime()); // el lease se refrescó

    // Limpia el estado in-progress.
    await patchProfile(jwtB, { migration_in_progress: false, leader_device_id: null });
  });

  it("25. líder de la IDA + heartbeat de OTRO device → ok:false 'other_leader', el lease NO cambia", async () => {
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        reverse_in_progress: false,
        leader_device_id: DEV_HB,
        migration_updated_at: "2000-01-01T00:00:00Z",
      }),
    ).toBeLessThan(300);
    const before = await readMigrationUpdatedAt(jwtB);

    const r = await migrationProgress(jwtB, { device_id: DEV_HB_OTHER, action: "heartbeat" });
    expect(r.body.ok).toBe(false);
    expect(r.body.reason).toBe("other_leader");
    expect(await readMigrationUpdatedAt(jwtB)).toBe(before); // un no-líder NO refresca el lease

    await patchProfile(jwtB, { migration_in_progress: false, leader_device_id: null });
  });

  it("26. reverse-líder (reverse_claim sobre migrado) → heartbeat ok:true (sirve a la reversa por rip)", async () => {
    // Migra (patrón goldens 6-7) y reclama la reversa (patrón 13) → rip=true, líder=DEV_HB.
    expect(
      await patchProfile(jwtB, {
        migration_in_progress: true,
        leader_device_id: DEV_HB,
        migration_updated_at: new Date().toISOString(),
        migrated_at: null,
        reverse_in_progress: false,
        reverse_frozen_at: null,
        reverted_at: null,
      }),
    ).toBeLessThan(300);
    expect((await migrationProgress(jwtB, { device_id: DEV_HB, action: "cutover" })).body.ok).toBe(true);
    expect((await migrationProgress(jwtB, { device_id: DEV_HB, action: "complete" })).body.ok).toBe(true);
    expect((await migrationProgress(jwtB, { device_id: DEV_HB, action: "reverse_claim" })).body.ok).toBe(true);

    const r = await migrationProgress(jwtB, { device_id: DEV_HB, action: "heartbeat" });
    expect(r.body.ok).toBe(true); // el heartbeat late para reverse_in_progress igual que para migration_in_progress

    // Limpia: aborta la reversa y resetea la fila.
    await migrationProgress(jwtB, { device_id: DEV_HB, action: "reverse_abort" });
    await patchProfile(jwtB, { reverse_in_progress: false, leader_device_id: null });
  });
});

describe("g3_02 goldens · claim promociona fila LIGERA de grupos (staging real)", () => {
  // El claim LIGERO de create_group/join_group (G1) inserta profiles(id) sin vida personal
  // (personal_claimed_at NULL). g3_02: claim_account PROMOCIONA esa fila a 'created' — el camino
  // del usuario solo-grupos que activa Yala completo (antes: existing_stable → migración bloqueada).
  // AUTOSUFICIENTE: simula la fila ligera con patchProfile (RLS own-row) y el propio claim la
  // devuelve al estado reclamado — robusto en corridas repetidas, sin seed externo.
  it("claim sobre fila ligera → created (promoción, estampa personal_claimed_at) y re-claim → existing_stable", async () => {
    // Garantiza fila presente (si una limpieza previa la dejó ausente, este claim la crea).
    await claim(jwtA, { device_id: "g3-02-pre", provider: "apple" });
    // Simula la fila LIGERA del claim ligero de grupos (provider/leader/mip como los deja G1).
    expect(
      await patchProfile(jwtA, {
        personal_claimed_at: null,
        provider: null,
        leader_device_id: null,
        migration_in_progress: false,
        migration_updated_at: null,
      }),
    ).toBeLessThan(300);

    const r1 = await claim(jwtA, { device_id: "g3-02-dev", provider: "apple" });
    expect(r1.status).toBe(200);
    expect(r1.body.state).toBe("created"); // promoción: para lo PERSONAL la cuenta nace ahora

    const r2 = await claim(jwtA, { device_id: "g3-02-dev", provider: "apple" });
    expect(r2.status).toBe(200);
    expect(r2.body.state).toBe("existing_stable"); // idempotente post-promoción (pca estampado)

    // Restaura el estado estable de A (leader era NULL; provider quedó "apple" por el claim).
    await patchProfile(jwtA, { leader_device_id: null });
  });
});
