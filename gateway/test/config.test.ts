import { describe, expect, it } from "vitest";
import app from "../src/index";
import { parseRolloutPercent } from "../src/config";

/**
 * GET /config (DIFERIDOS #34) — remote-config pública de flags de rollout (§j.1/§j.2).
 * Sin auth, sin bindings: el env se pasa directo a app.request. Fail-closed: ausente/inválido → 0.
 */

interface ConfigBody {
  v: number;
  flags: {
    cloudModeRolloutPercent: number;
    cloudOnboardingChoiceRolloutPercent: number;
    groupsBackendRolloutPercent: number;
  };
}

function getConfig(env: Record<string, string>): Promise<Response> {
  return app.request("/config", { method: "GET" }, env);
}

describe("GET /config — shape y semántica fail-closed", () => {
  it("golden del shape: v=1 + los 3 percents, con valores parseados del env", async () => {
    const res = await getConfig({
      CLOUD_MODE_ROLLOUT_PERCENT: "25",
      CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT: "0",
      GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as ConfigBody;
    expect(body).toEqual({
      v: 1,
      flags: {
        cloudModeRolloutPercent: 25,
        cloudOnboardingChoiceRolloutPercent: 0,
        groupsBackendRolloutPercent: 100,
      },
    });
  });

  it("vars AUSENTES → 0 en los 3 (fail-closed: un env sin configurar jamás enciende nada)", async () => {
    const body = (await (await getConfig({})).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(0);
    expect(body.flags.cloudOnboardingChoiceRolloutPercent).toBe(0);
    expect(body.flags.groupsBackendRolloutPercent).toBe(0);
  });

  it("var INVÁLIDA → 0 (no NaN, no crash)", async () => {
    const body = (await (await getConfig({ CLOUD_MODE_ROLLOUT_PERCENT: "garbage" })).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(0);
  });

  it("clamp a [0,100]: 150 → 100, -5 → 0", async () => {
    const body = (await (
      await getConfig({ CLOUD_MODE_ROLLOUT_PERCENT: "150", GROUPS_BACKEND_ROLLOUT_PERCENT: "-5" })
    ).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(100);
    expect(body.flags.groupsBackendRolloutPercent).toBe(0);
  });

  it("cache pública corta (el edge absorbe el fan-out; un flip propaga en ≤ max-age)", async () => {
    const res = await getConfig({});
    expect(res.headers.get("cache-control")).toBe("public, max-age=300");
    expect(res.headers.get("content-type")).toContain("application/json");
  });

  it("sin auth ni attest: responde 200 sin Authorization (config pre-sesión)", async () => {
    const res = await getConfig({ CLOUD_MODE_ROLLOUT_PERCENT: "100" });
    expect(res.status).toBe(200);
  });
});

describe("parseRolloutPercent — tabla fail-closed", () => {
  it("casos borde", () => {
    expect(parseRolloutPercent(undefined)).toBe(0);
    expect(parseRolloutPercent("")).toBe(0);
    expect(parseRolloutPercent("0")).toBe(0);
    expect(parseRolloutPercent("1")).toBe(1);
    expect(parseRolloutPercent("99")).toBe(99);
    expect(parseRolloutPercent("100")).toBe(100);
    expect(parseRolloutPercent("101")).toBe(100);
    expect(parseRolloutPercent("-1")).toBe(0);
    expect(parseRolloutPercent("garbage")).toBe(0);
    expect(parseRolloutPercent("50.9")).toBe(50); // parseInt trunca — entero siempre
  });
});
