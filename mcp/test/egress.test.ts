import { describe, expect, it } from "vitest";
import { EgressDenied, guardSupabase } from "../src/egress";
import { makeEnv } from "./helpers";
import { SB_URL } from "./supabase-fake";

const env = makeEnv();

function guarded() {
  const seen: string[] = [];
  const f = guardSupabase(env, async (input, init) => {
    seen.push(`${init?.method ?? "GET"} ${String(input)}`);
    return new Response("{}");
  });
  return { f, seen };
}

describe("lista cerrada de salidas del Worker hacia Supabase", () => {
  it("deja pasar lo que el flujo necesita", async () => {
    const { f, seen } = guarded();
    const ok: [string, string][] = [
      ["GET", `${SB_URL}/rest/v1/tx_items?select=sync_id&deleted=is.false&limit=10`],
      ["POST", `${SB_URL}/auth/v1/token?grant_type=password`],
      ["GET", `${SB_URL}/auth/v1/oauth/authorizations/az_12345678`],
      ["POST", `${SB_URL}/auth/v1/oauth/authorizations/az_12345678/consent`],
      ["POST", `${SB_URL}/auth/v1/oauth/token`],
      ["GET", `${SB_URL}/auth/v1/user`],
      ["POST", `${SB_URL}/auth/v1/logout?scope=local`],
    ];
    for (const [method, url] of ok) await f(url, { method });
    expect(seen).toHaveLength(ok.length);
  });

  it("no deja salir ninguna escritura de la cuenta ni de la base, y no toca la red al negarla", async () => {
    const { f, seen } = guarded();
    const denied: [string, string][] = [
      ["PUT", `${SB_URL}/auth/v1/user`],
      ["PATCH", `${SB_URL}/auth/v1/user`],
      ["POST", `${SB_URL}/auth/v1/factors`],
      ["DELETE", `${SB_URL}/auth/v1/factors/abc`],
      ["POST", `${SB_URL}/auth/v1/logout?scope=global`],
      ["POST", `${SB_URL}/auth/v1/logout?scope=local&scope=global`],
      ["POST", `${SB_URL}/auth/v1/logout`],
      ["GET", `${SB_URL}/auth/v1/reauthenticate`],
      ["DELETE", `${SB_URL}/auth/v1/user/oauth/grants?client_id=x`],
      ["GET", `${SB_URL}/auth/v1/user/identities/authorize?provider=google`],
      ["DELETE", `${SB_URL}/auth/v1/user/identities/abc`],
      ["POST", `${SB_URL}/auth/v1/passkeys/registration/options`],
      ["POST", `${SB_URL}/auth/v1/token?grant_type=refresh_token`],
      ["POST", `${SB_URL}/auth/v1/token?grant_type=password&x=1`],
      ["POST", `${SB_URL}/auth/v1/oauth/clients/register`],
      ["GET", `${SB_URL}/auth/v1/admin/users`],
      ["POST", `${SB_URL}/rest/v1/accounts`],
      ["PATCH", `${SB_URL}/rest/v1/accounts?user_id=eq.x`],
      ["DELETE", `${SB_URL}/rest/v1/accounts`],
      ["GET", `${SB_URL}/rest/v1/rpc/delete_personal_account`],
      ["POST", `${SB_URL}/rest/v1/rpc/apply_delta`],
      ["GET", `${SB_URL}/auth/v1/%75ser`],
      ["GET", `${SB_URL}/auth/v1/user/../factors`],
      ["GET", `https://otro.supabase.co/rest/v1/accounts`],
      ["GET", `https://user:pw@proyecto.supabase.co/rest/v1/accounts`],
    ];
    for (const [method, url] of denied) {
      await expect(f(url, { method }), `${method} ${url}`).rejects.toBeInstanceOf(EgressDenied);
    }
    expect(seen).toEqual([]);
  });

  it("mira el método de un Request aunque no venga en init", async () => {
    const { f } = guarded();
    await expect(f(new Request(`${SB_URL}/auth/v1/user`, { method: "PUT" }))).rejects.toBeInstanceOf(EgressDenied);
  });
});
