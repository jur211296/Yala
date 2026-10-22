import { describe, expect, it } from "vitest";
import { accessTtlFor, GRANT_IDLE_SECONDS, GRANT_MAX_AGE_SECONDS, grantTtlFor, UPSTREAM_MARGIN_SECONDS } from "../src/tokens";

describe("caducidades", () => {
  const t0 = 1_800_000_000;

  it("el token de Claude caduca un minuto antes que el de Supabase, entre 60 s y 1 h", () => {
    expect(accessTtlFor(t0 + 3600, t0)).toBe(3600 - UPSTREAM_MARGIN_SECONDS);
    expect(accessTtlFor(t0 + 121, t0)).toBe(61);
    expect(accessTtlFor(t0 + 120, t0)).toBe(60);
    expect(accessTtlFor(t0 + 119, t0)).toBe(60);
    expect(accessTtlFor(t0 + 10_000, t0)).toBe(3600);
  });

  it("la conexión dura 30 días deslizantes y nunca más de 90 desde la autorización", () => {
    expect(grantTtlFor(t0, t0)).toBe(GRANT_IDLE_SECONDS);
    // A 61 días quedan 29: manda el máximo, no los 30 deslizantes.
    expect(grantTtlFor(t0, t0 + 61 * 86_400)).toBe(29 * 86_400);
    expect(grantTtlFor(t0, t0 + 60 * 86_400)).toBe(GRANT_IDLE_SECONDS);
    expect(grantTtlFor(t0, t0 + 60 * 86_400 - 1)).toBe(GRANT_IDLE_SECONDS);
    // Los vecinos del límite de 90 días: el llamador corta por debajo de 60 s.
    expect(grantTtlFor(t0, t0 + GRANT_MAX_AGE_SECONDS - 61)).toBe(61);
    expect(grantTtlFor(t0, t0 + GRANT_MAX_AGE_SECONDS - 60)).toBe(60);
    expect(grantTtlFor(t0, t0 + GRANT_MAX_AGE_SECONDS - 59)).toBe(59);
  });
});
