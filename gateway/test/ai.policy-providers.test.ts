/**
 * Card `buer`: la política de privacidad solo nombra a OpenAI como proveedor de IA, y el gateway tiene Gemini
 * preparado y apagado (`PREPARED_ROUTES`). Esta guarda se pone roja si una fila ACTIVA (`ROUTES` o
 * `LEGACY_OVERRIDES`) usa un proveedor que la política web no nombra en la lista de proveedores de los seis
 * idiomas. Encender otro proveedor exige antes actualizar la política (y el resto del paso 7: consentimiento en la
 * app, DPA, clave como secret): ver el docblock de `PREPARED_ROUTES` y `.claude/rules/ai-gateway.md`.
 *
 * Lee `Web/src/i18n/translations.ts` del repo, sin tocarlo (la web es de Lola). La política PUBLICADA sale de la
 * rama 1.0: esta guarda comprueba la copia de la rama en la que se enciende, que es la que irá a 1.0.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { LEGACY_OVERRIDES, PREPARED_ROUTES, ROUTES, type ProviderId, type Route } from "../src/ai/routes";

/** Cómo se llama cada proveedor en la política. Un proveedor nuevo en `ProviderId` necesita su nombre aquí. */
const POLICY_NAME: Readonly<Record<ProviderId, string>> = {
  openai: "OpenAI",
  gemini: "Google Gemini",
  anthropic: "Anthropic",
  workersai: "Workers AI",
  xai: "xAI",
};

function providerOf(route: Route): ProviderId {
  // Las filas passthrough solo admiten modelos de OpenAI (`allowedModels`).
  return route.mode === "passthrough" ? "openai" : route.provider;
}

function activeProviders(): Set<ProviderId> {
  const rows: Route[] = [...Object.values(ROUTES), ...(Object.values(LEGACY_OVERRIDES) as Route[])];
  return new Set(rows.map(providerOf));
}

function providerListsByLocale(): string[] {
  const src = readFileSync(new URL("../../Web/src/i18n/translations.ts", import.meta.url), "utf8");
  const lists = [...src.matchAll(/privacyProvidersText:\s*'((?:[^'\\]|\\.)*)'/g)].map((m) => m[1]);
  return lists;
}

describe("la política nombra a todo proveedor de IA activo", () => {
  it("se leen las listas de proveedores de los seis idiomas de la web", () => {
    expect(providerListsByLocale()).toHaveLength(6);
  });

  it("cada proveedor de una fila activa sale en la lista de proveedores de cada idioma", () => {
    const lists = providerListsByLocale();
    for (const provider of activeProviders()) {
      for (const [i, list] of lists.entries()) {
        expect(list, `${provider} falta en la política (idioma ${i})`).toContain(`**${POLICY_NAME[provider]}`);
      }
    }
  });

  it("la guarda discrimina: un proveedor preparado y apagado NO está en la política de hoy", () => {
    // Si este caso se pone rojo es que la política ya nombra a Gemini: entonces la guarda de arriba deja de
    // poder caer por él y este control se retira junto con el encendido.
    const prepared = new Set((Object.values(PREPARED_ROUTES) as Route[]).map(providerOf));
    expect(prepared.has("gemini")).toBe(true);
    for (const list of providerListsByLocale()) expect(list).not.toContain(`**${POLICY_NAME.gemini}`);
  });
});
