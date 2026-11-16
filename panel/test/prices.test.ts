import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { PRICED_OUTSIDE_TOKENS, PRICES } from "../src/prices";

describe("precios de la IA", () => {
  it("todo modelo de las filas del gateway tiene precio (o se cobra fuera de tokens)", () => {
    const sources = ["../../gateway/src/ai/routes.ts", "../../gateway/src/mail/read.ts"].map((p) => readFileSync(new URL(p, import.meta.url), "utf8"));
    const models = new Set(sources.flatMap((s) => [...s.matchAll(/model: "([^"]+)"/g)].map((m) => m[1])));
    expect(models.size).toBeGreaterThan(0);
    for (const m of models) expect(m in PRICES || PRICED_OUTSIDE_TOKENS.has(m), m).toBe(true);
  });
});
