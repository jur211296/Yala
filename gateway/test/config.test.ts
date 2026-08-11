import { describe, expect, it } from "vitest";
import app from "../src/index";
import { parseRolloutPercent, parseMinBuild } from "../src/config";

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
    secondarySessionRolloutPercent: number;
  };
  forceUpdate: {
    minSupportedBuild: number;
  };
}

function getConfig(env: Record<string, string>): Response | Promise<Response> {
  return app.request("/config", { method: "GET" }, env);
}

describe("GET /config — shape y semántica fail-closed", () => {
  it("golden del shape: v=1 + los 4 percents + forceUpdate, con valores parseados del env", async () => {
    const res = await getConfig({
      CLOUD_MODE_ROLLOUT_PERCENT: "25",
      CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT: "0",
      GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
      SECONDARY_SESSION_ROLLOUT_PERCENT: "50",
      MIN_SUPPORTED_BUILD: "137",
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as ConfigBody;
    expect(body).toEqual({
      v: 1,
      flags: {
        cloudModeRolloutPercent: 25,
        cloudOnboardingChoiceRolloutPercent: 0,
        groupsBackendRolloutPercent: 100,
        secondarySessionRolloutPercent: 50,
      },
      forceUpdate: {
        minSupportedBuild: 137,
      },
    });
  });

  it("vars AUSENTES → 0 en los 4 percents + minSupportedBuild (fail-closed: nada enciende)", async () => {
    const body = (await (await getConfig({})).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(0);
    expect(body.flags.cloudOnboardingChoiceRolloutPercent).toBe(0);
    expect(body.flags.groupsBackendRolloutPercent).toBe(0);
    expect(body.flags.secondarySessionRolloutPercent).toBe(0);
    expect(body.forceUpdate.minSupportedBuild).toBe(0);
  });

  // El percent de la sesión secundaria es INDEPENDIENTE de los otros tres: hasta el chip M2 el feature
  // tomaba prestado el kill-switch de CLOUD_MODE, y el bug que eso escondía es que no había forma de
  // encenderlo sin encender también las superficies de alta. Este test es lo que impide volver a
  // atarlos: los dos valores se mueven por separado en la misma respuesta.
  it("el percent de la secundaria NO está atado al de CLOUD_MODE", async () => {
    const body = (await (
      await getConfig({ CLOUD_MODE_ROLLOUT_PERCENT: "100", SECONDARY_SESSION_ROLLOUT_PERCENT: "0" })
    ).json()) as ConfigBody;
    expect(body.flags.cloudModeRolloutPercent).toBe(100);
    expect(body.flags.secondarySessionRolloutPercent).toBe(0);

    const inverso = (await (
      await getConfig({ CLOUD_MODE_ROLLOUT_PERCENT: "0", SECONDARY_SESSION_ROLLOUT_PERCENT: "100" })
    ).json()) as ConfigBody;
    expect(inverso.flags.cloudModeRolloutPercent).toBe(0);
    expect(inverso.flags.secondarySessionRolloutPercent).toBe(100);
  });

  it("MIN_SUPPORTED_BUILD inválido → 0; número grande se PRESERVA (sin clamp, ≠ percents)", async () => {
    const invalid = (await (await getConfig({ MIN_SUPPORTED_BUILD: "garbage" })).json()) as ConfigBody;
    expect(invalid.forceUpdate.minSupportedBuild).toBe(0);
    const large = (await (await getConfig({ MIN_SUPPORTED_BUILD: "999999" })).json()) as ConfigBody;
    expect(large.forceUpdate.minSupportedBuild).toBe(999999);
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

describe("parseMinBuild — piso 0, sin techo (fail-closed)", () => {
  it("casos borde", () => {
    expect(parseMinBuild(undefined)).toBe(0);
    expect(parseMinBuild("")).toBe(0);
    expect(parseMinBuild("garbage")).toBe(0);
    expect(parseMinBuild("-5")).toBe(0); // piso 0
    expect(parseMinBuild("0")).toBe(0);
    expect(parseMinBuild("1")).toBe(1);
    expect(parseMinBuild("137")).toBe(137);
    expect(parseMinBuild("999999")).toBe(999999); // SIN clamp superior
    expect(parseMinBuild("137.9")).toBe(137); // parseInt trunca
  });
});
