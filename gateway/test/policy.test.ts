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

  it("Free: voz/imagen son un CUPO DE PRUEBA de 5 en total, sin reposición diaria (sesión 2, opción B)", () => {
    expect(limitsFor("free", "vision")).toMatchObject({ trial: 5 });
    expect(limitsFor("free", "voice")).toMatchObject({ trial: 5 });
    expect(limitsFor("free", "vision")?.daily).toBeUndefined();
    expect(limitsFor("free", "voice")?.daily).toBeUndefined();
  });

  it("Pro sigue con cuota diaria (el cupo de prueba es solo del plan free)", () => {
    expect(limitsFor("pro", "voice")?.trial).toBeUndefined();
    expect(limitsFor("pro", "vision")?.trial).toBeUndefined();
  });

  it("Free: tasas abiertas a cualquier device atestado", () => {
    expect(limitsFor("free", "rates")).not.toBeNull();
  });
});
