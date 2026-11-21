/**
 * La cuenta sola al leer (2026-11-20, parte 1 del ticket `2026-11-20-captura-cuenta-automatica-y-reglas`): la lectura
 * de la foto devuelve también el medio de pago (`payment`) y la cuenta que cree la IA (`account`, copiada de la lista
 * que manda la app con la cuenta en la nube). El esquema cerrado de `photo.read` los admite, y el prompt de la app los
 * pide: si uno de los dos lados los pierde, la otra mitad deja de servir.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { TASK_SCHEMAS } from "../src/ai/routes";
import { photoSystemPrompt } from "../bench/lib/appRequests";

type Schema = {
  schema: {
    properties: {
      transactions: { items: { required: string[]; properties: Record<string, { type: string[] }>; additionalProperties: boolean } };
    };
  };
};

const items = (TASK_SCHEMAS["photo.read"] as unknown as Schema).schema.properties.transactions.items;

describe("photo.read: medio de pago y cuenta", () => {
  it("el esquema admite `payment` y `account` como texto o null, y sigue cerrado", () => {
    expect(items.additionalProperties).toBe(false);
    for (const field of ["payment", "account"]) {
      expect(items.properties[field]?.type).toEqual(["string", "null"]);
      expect(items.required).toContain(field);
    }
  });

  it("los campos de siempre no cambian", () => {
    for (const field of ["amount", "date", "merchant", "note", "currency"]) expect(items.required).toContain(field);
  });

  it("el prompt de la app (leído del Swift) pide los dos y su ejemplo los deja en null", () => {
    const prompt = photoSystemPrompt("2026-11-20");
    expect(prompt).toContain("- Payment:");
    expect(prompt).toContain("- Account:");
    expect(prompt).toContain('"payment": null, "account": null');
  });

  it("la lista de cuentas viaja con nombre, clase y moneda, y sin sitio para números", () => {
    const swift = readFileSync(new URL("../../Yala/App/Logic/CuentaSolaAlLeer/CuentaSolaAlLeerPeticion.swift", import.meta.url), "utf8");
    const struct = swift.slice(swift.indexOf("struct Cuenta"), swift.indexOf("}", swift.indexOf("struct Cuenta")));
    expect(struct).toContain("let name: String");
    expect(struct).toContain("let kind:");
    expect(struct).toContain("let currencyCode: String");
    expect(struct).not.toMatch(/accountNumber|last4|balance/);
  });
});
