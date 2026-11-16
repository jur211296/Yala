/**
 * La web en el móvil no se amplía sola (barrido final de 2.3, card vimy).
 *
 * Safari del iPhone amplía la página al tocar un campo con letra de menos de 16 px y la deja así al salir: toda la web
 * quedaba corrida a la derecha y cortaba importes. Dos causas, las dos en `app.css`: atajos `font: 600 13px inherit`,
 * que son inválidos (`inherit` no vale dentro del atajo) y el navegador tira enteros, y los campos de los formularios a
 * 14 px. Medido con el Chromium de Playwright a 390 pt y pantalla táctil: siete campos bajo 16 px antes, ninguno después.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const css = readFileSync(new URL("../src/client/app.css", import.meta.url), "utf8").replace(/\/\*[\s\S]*?\*\//g, "");
const rules = [...css.matchAll(/([^{}]+)\{([^{}]*)\}/g)].map((m) => ({ sel: m[1]!.trim(), body: m[2]! }));
const FIELD = /\b(input|select|textarea)\b|\.link-in/;

describe("Yala web en el móvil", () => {
  it("ninguna regla de un campo usa `font: … inherit` (inválido: el navegador la descarta entera)", () => {
    const bad = rules.filter((r) => FIELD.test(r.sel) && /(^|;)\s*font:\s*[^;]*\binherit\s*;/.test(r.body) && !/(^|;)\s*font:\s*inherit\s*;/.test(r.body));
    expect(bad.map((r) => r.sel)).toEqual([]);
  });

  it("en pantallas táctiles los campos de letra pequeña suben a 16 px", () => {
    const block = css.match(/@media \(hover: none\) and \(pointer: coarse\)\s*\{([\s\S]*?\})\s*\}/);
    expect(block, "falta el bloque táctil de app.css").toBeTruthy();
    const inner = block![1]!;
    expect(inner).toMatch(/font-size:\s*16px/);
    for (const sel of [".chips select", '.chips input[type="search"]', ".fld input", ".fld select", ".kv select", ".link-in"]) {
      expect(inner, sel).toContain(sel);
    }
  });
});
