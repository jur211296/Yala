/**
 * Captura por foto: la IA reconoce el comercio (decisión 75 de Jürgen, encargo del 2026-11-22). La lectura de la foto
 * devuelve `merchantKind`, a qué se dedica el comercio según lo que la IA sabe de él, de una lista cerrada que es el
 * `enum VisionMerchantKind` de la app. El teléfono la traduce a una subcategoría del usuario: ningún nombre de categoría
 * viaja. Si el esquema, el prompt y el `enum` dejan de coincidir, la palabra que devuelve el modelo no elige nada.
 */
import { describe, expect, it } from "vitest";
import { PHOTO_MERCHANT_KINDS, TASK_SCHEMAS } from "../src/ai/routes";
import { photoSystemPrompt, visionMerchantKinds } from "../bench/lib/appRequests";

type Field = { type: string[]; enum?: (string | null)[] };
type Schema = {
  schema: {
    properties: {
      transactions: { items: { required: string[]; properties: Record<string, Field>; additionalProperties: boolean } };
    };
  };
};

const items = (TASK_SCHEMAS["photo.read"] as unknown as Schema).schema.properties.transactions.items;

describe("photo.read: el tipo de comercio", () => {
  it("el esquema pide `merchantKind`, texto o null, y sigue cerrado", () => {
    expect(items.additionalProperties).toBe(false);
    expect(items.required).toContain("merchantKind");
    expect(items.properties.merchantKind?.type).toEqual(["string", "null"]);
  });

  it("la lista del esquema es la del `enum` de la app, en el mismo orden, y admite null", () => {
    const swift = visionMerchantKinds();
    expect(swift.length).toBeGreaterThan(20);
    expect([...PHOTO_MERCHANT_KINDS]).toEqual(swift);
    expect(items.properties.merchantKind?.enum).toEqual([...swift, null]);
  });

  it("los campos de antes siguen ahí (una app instalada no se rompe)", () => {
    for (const field of ["amount", "date", "merchant", "note", "currency", "payment", "account"]) {
      expect(items.required).toContain(field);
    }
  });

  it("el prompt de la app (leído del Swift) pide el campo, enseña la lista entera y su ejemplo es coherente", () => {
    const prompt = photoSystemPrompt("2026-11-22");
    expect(prompt).toContain("- MerchantKind:");
    expect(prompt).toContain(visionMerchantKinds().join(", "));
    expect(prompt).toContain('"merchant": "Starbucks"');
    expect(prompt).toContain('"merchantKind": "restaurant"');
    // Pide el nombre comercial conocido, no la razón social.
    expect(prompt).toMatch(/known trade name/);
  });

  it("la petición de la foto no lleva categorías del usuario: el prompt no tiene sitio para ellas", () => {
    const prompt = photoSystemPrompt("2026-11-22");
    expect(prompt).not.toMatch(/subcategor/i);
  });
});
