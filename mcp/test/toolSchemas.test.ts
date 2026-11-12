/**
 * El gateway ofrece estas mismas seis herramientas a Yala IA en modo nube (`gateway/src/ai/explore/tools.ts`), con su
 * esquema escrito en JSON Schema. Este test compara ese esquema con el de `zod` de aquí, campo a campo, para que
 * cambiar una herramienta en un lado sin el otro se vea en rojo.
 *
 * Dos diferencias declaradas, y solo esas: el gateway no ofrece `zona_horaria` (la pone él, desde el teléfono) y acota
 * `limite` de `buscar_movimientos` a 50 (cada movimiento son tokens que paga la pregunta).
 */
import { describe, expect, it } from "vitest";
import { z } from "zod";
import { INPUT_SCHEMAS, TOOLS } from "../src/tools";
import { EXPLORE_TOOL_SPECS } from "../../gateway/src/ai/explore/tools";

type Prop = { type?: string; enum?: string[]; minimum?: number; maximum?: number; maxLength?: number };

function zodJson(name: string): { properties?: Record<string, Prop>; required?: string[] } {
  return z.toJSONSchema(z.object(INPUT_SCHEMAS[name])) as { properties?: Record<string, Prop>; required?: string[] };
}

function zodProps(name: string): Record<string, Prop> {
  return zodJson(name).properties ?? {};
}

function shape(p: Prop): Prop {
  const out: Prop = {};
  if (p.type) out.type = p.type;
  if (p.enum) out.enum = [...p.enum];
  if (p.minimum !== undefined) out.minimum = p.minimum;
  if (p.maximum !== undefined) out.maximum = p.maximum;
  if (p.maxLength !== undefined) out.maxLength = p.maxLength;
  return out;
}

describe("esquemas de las herramientas: conector y gateway casan", () => {
  it("las mismas seis, en el mismo orden", () => {
    expect(EXPLORE_TOOL_SPECS.map((s) => s.name)).toEqual(TOOLS.map((t) => t.name));
  });

  for (const tool of TOOLS) {
    it(`${tool.name}: mismos campos y tipos (salvo las dos diferencias declaradas)`, () => {
      const spec = EXPLORE_TOOL_SPECS.find((s) => s.name === tool.name)!;
      const gw = (spec.parameters.properties ?? {}) as Record<string, Prop>;
      const mcp = zodProps(tool.name);
      expect(spec.takesTimeZone).toBe("zona_horaria" in mcp);
      const expected: Record<string, Prop> = {};
      for (const [k, v] of Object.entries(mcp)) {
        if (k === "zona_horaria") continue;
        expected[k] = shape(v);
      }
      if (tool.name === "buscar_movimientos") expected.limite = { ...expected.limite, maximum: 50 };
      const got: Record<string, Prop> = {};
      for (const [k, v] of Object.entries(gw)) got[k] = shape(v);
      expect(got).toEqual(expected);
      const required = (zodJson(tool.name).required ?? []).filter((k) => k !== "zona_horaria");
      expect(((spec.parameters.required ?? []) as string[]).slice().sort()).toEqual(required.slice().sort());
    });
  }

  it("control: el conector sí declara `zona_horaria` y `limite` hasta 200 (si no, las excepciones no prueban nada)", () => {
    expect(zodProps("buscar_movimientos").zona_horaria).toBeDefined();
    expect(zodProps("buscar_movimientos").limite?.maximum).toBe(200);
  });
});
