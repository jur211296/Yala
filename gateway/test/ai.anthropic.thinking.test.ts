/**
 * El adaptador de Anthropic apaga el razonamiento como acepta cada modelo (2026-10-07, banco de chat y nota):
 * `between_tools` solo lo acepta Sonnet 5.5; Claude Haiku 5.5 lo rechaza con un 400 y se apaga con `disabled`.
 * Antes del arreglo, `none` en Haiku 5.5 mandaba `between_tools` y el banco no podía medirlo sin razonar.
 */
import { describe, expect, it } from "vitest";
import { buildAnthropicBody } from "../src/ai/providers/anthropic";
import type { ManagedRoute } from "../src/ai/routes";

const body = { messages: [{ role: "system", content: "s" }, { role: "user", content: "hola" }, { role: "assistant", content: "¿sí?" }, { role: "user", content: "y el mes pasado" }] };
const route = (model: string, reasoningEffort: ManagedRoute["params"]["reasoningEffort"]): ManagedRoute => ({
  mode: "managed",
  provider: "anthropic",
  model,
  params: { responseFormat: "text", reasoningEffort },
  retries: 0,
});

describe("anthropic: apagar el razonamiento", () => {
  it("Sonnet 5.5 con `none` → between_tools", () => {
    expect(buildAnthropicBody(body, route("claude-sonnet-5-5", "none")).thinking).toEqual({ type: "between_tools" });
  });

  it("Haiku 5.5 con `none` → disabled (between_tools da 400)", () => {
    const out = buildAnthropicBody(body, route("claude-haiku-5-5", "none"));
    expect(out.thinking).toEqual({ type: "disabled" });
    expect(out.output_config).toBeUndefined();
  });

  it("Haiku 5.5 con `low` → razonamiento adaptativo por defecto y esfuerzo bajo", () => {
    const out = buildAnthropicBody(body, route("claude-haiku-5-5", "low"));
    expect(out.thinking).toBeUndefined();
    expect(out.output_config).toEqual({ effort: "low" });
  });

  it("Haiku 4.5 con `none` sigue sin thinking", () => {
    expect(buildAnthropicBody(body, route("claude-haiku-4-5", "none")).thinking).toBeUndefined();
  });

  it("los turnos previos viajan en orden y el sistema aparte (multi-turno de chat.answer)", () => {
    const out = buildAnthropicBody(body, route("claude-haiku-5-5", "none"));
    expect(out.system).toBe("s");
    expect((out.messages as { role: string }[]).map((m) => m.role)).toEqual(["user", "assistant", "user"]);
  });
});
