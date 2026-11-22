/**
 * `worker.ts` es el `main` de wrangler: lo que no reexporta no existe en el Worker desplegado. El 22-nov el binding
 * `CONNECTOR_DRAFTS` del conector (`mcp/`) fallaba siempre porque `worker.ts` no publicaba `ConnectorDrafts`, aunque
 * `index.ts` sí. Este test lee los wrangler que apuntan al gateway (el propio, `mcp/` y `webapp/`) y exige que cada
 * Durable Object (`class_name`) y cada `entrypoint` de service binding salga de `worker.ts`, y que todo lo que
 * `index.ts` exporta también. Se lee el texto: `worker.ts` importa `cloudflare:workers`, que no existe en Node.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const read = (p: string) => readFileSync(new URL(`../${p}`, import.meta.url), "utf8");

function exportedNames(src: string): Set<string> {
  const names = new Set<string>();
  for (const m of src.matchAll(/^export\s+(?:default\s+)?(?:class|const|function)\s+(\w+)/gm)) names.add(m[1]);
  for (const m of src.matchAll(/^export\s*\{([^}]+)\}/gm))
    for (const part of m[1].split(",")) {
      const n = part.trim().split(/\s+as\s+/).pop()?.trim();
      if (n) names.add(n);
    }
  if (/^export\s+default\b/m.test(src)) names.add("default");
  return names;
}

/** Clases que otro Worker (o el propio gateway) espera encontrar en el gateway. */
function requiredFromWrangler(): Map<string, string> {
  const req = new Map<string, string>();
  for (const m of read("wrangler.toml").matchAll(/class_name\s*=\s*"(\w+)"/g)) req.set(m[1], "gateway/wrangler.toml");
  for (const f of ["../mcp/wrangler.toml", "../webapp/wrangler.toml"]) {
    const toml = read(f);
    for (const block of toml.split(/\n(?=\[)/)) {
      const service = block.match(/service\s*=\s*"([^"]+)"/)?.[1];
      const entry = block.match(/entrypoint\s*=\s*"(\w+)"/)?.[1];
      if (service?.startsWith("yala-gateway") && entry) req.set(entry, f.replace("../", ""));
    }
  }
  return req;
}

describe("worker.ts publica todo lo que usan los bindings", () => {
  const worker = exportedNames(read("src/worker.ts"));

  it("encuentra los bindings que conocemos (si no, el parser se rompió)", () => {
    const req = requiredFromWrangler();
    for (const n of ["RateLimiter", "ConnectorDrafts", "WebGroupsReader", "WebGroupsWriter"]) expect(req.has(n), n).toBe(true);
  });

  it("cada class_name y entrypoint sale de worker.ts", () => {
    const missing = [...requiredFromWrangler()].filter(([n]) => !worker.has(n)).map(([n, f]) => `${n} (${f})`);
    expect(missing).toEqual([]);
  });

  it("todo lo que exporta index.ts lo reexporta worker.ts", () => {
    const missing = [...exportedNames(read("src/index.ts"))].filter((n) => !worker.has(n));
    expect(missing).toEqual([]);
  });
});
