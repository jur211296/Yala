import { describe, expect, it } from "vitest";
import { limitsFor } from "../src/policy";

describe("política de cuota", () => {
  it("Pro tiene todas las categorías (chat 75/día como el límite histórico)", () => {
    expect(limitsFor("pro", "chat")?.daily).toBe(75);
    expect(limitsFor("pro", "vision")).not.toBeNull();
    expect(limitsFor("pro", "voice")).not.toBeNull();
    expect(limitsFor("pro", "insights")).not.toBeNull();
    expect(limitsFor("pro", "suggestions")).not.toBeNull();
    expect(limitsFor("pro", "rates")).not.toBeNull();
  });

  it("Free: chat/insights/suggestions → Pro requerido (null)", () => {
    expect(limitsFor("free", "chat")).toBeNull();
    expect(limitsFor("free", "insights")).toBeNull();
    expect(limitsFor("free", "suggestions")).toBeNull();
  });

  it("Free: voz/imagen tienen cuota de trial pequeña (no rompe el setup-checklist)", () => {
    expect(limitsFor("free", "vision")?.daily).toBe(5);
    expect(limitsFor("free", "voice")?.daily).toBe(5);
  });

  it("Free: tasas abiertas a cualquier device atestado", () => {
    expect(limitsFor("free", "rates")).not.toBeNull();
  });
});
