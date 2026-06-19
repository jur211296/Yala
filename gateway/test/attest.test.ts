import { describe, expect, it } from "vitest";
import type { Env } from "../src/env";
import { issueChallenge, verifyChallenge } from "../src/attest/challenge";
import { issueSessionToken, verifySessionToken } from "../src/attest/session";

const env = { JWT_SIGNING_SECRET: "test-secret-please-change-0123456789" } as Env;

describe("challenge (HMAC stateless)", () => {
  it("issue → verify roundtrip", async () => {
    const { challenge, ttlMs } = await issueChallenge(env);
    expect(ttlMs).toBeGreaterThan(0);
    expect(await verifyChallenge(env, challenge)).toBe(true);
  });

  it("rechaza MAC manipulado", async () => {
    const { challenge } = await issueChallenge(env);
    const [payload] = challenge.split(".");
    expect(await verifyChallenge(env, `${payload}.AAAA`)).toBe(false);
  });

  it("rechaza payload manipulado", async () => {
    const { challenge } = await issueChallenge(env);
    const [, mac] = challenge.split(".");
    expect(await verifyChallenge(env, `AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA.${mac}`)).toBe(false);
  });

  it("rechaza con otro secret", async () => {
    const { challenge } = await issueChallenge(env);
    const other = { JWT_SIGNING_SECRET: "distinto-secret" } as Env;
    expect(await verifyChallenge(other, challenge)).toBe(false);
  });

  it("rechaza formato inválido", async () => {
    expect(await verifyChallenge(env, "sin-punto")).toBe(false);
  });
});

describe("session JWT (HS256)", () => {
  it("issue → verify preserva keyId y tier", async () => {
    const { token, expMs } = await issueSessionToken(env, { keyId: "abc", tier: "pro" });
    expect(expMs).toBeGreaterThan(Date.now());
    const claims = await verifySessionToken(env, token);
    expect(claims).toEqual({ keyId: "abc", tier: "pro" });
  });

  it("tier free se preserva", async () => {
    const { token } = await issueSessionToken(env, { keyId: "k2", tier: "free" });
    expect((await verifySessionToken(env, token))?.tier).toBe("free");
  });

  it("rechaza token de otro secret", async () => {
    const { token } = await issueSessionToken(env, { keyId: "k", tier: "pro" });
    const other = { JWT_SIGNING_SECRET: "otro" } as Env;
    expect(await verifySessionToken(other, token)).toBeNull();
  });

  it("rechaza basura", async () => {
    expect(await verifySessionToken(env, "no.es.jwt")).toBeNull();
  });
});
