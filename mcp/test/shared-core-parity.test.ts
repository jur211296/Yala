/**
 * Paridad del núcleo compartido: el conector sigue igual después de mover su núcleo a `shared-core/`.
 *
 * La foto (`golden/shared-core-parity.json`) se sacó con el código de ANTES del movimiento, cuando el núcleo aún vivía
 * en `mcp/src/`. Recoge, para cada escenario del golden de la app y cada llamada de las seis herramientas, las
 * consultas exactas que la herramienta pidió a PostgREST y la respuesta que devolvió. Este test vuelve a correr las
 * mismas llamadas con el núcleo de `shared-core/` y exige lo mismo, byte a byte. Una consulta distinta también es un
 * cambio de comportamiento: puede leer otras filas en la base de verdad.
 *
 * Para regenerar la foto a propósito (un cambio de comportamiento querido): borrar el JSON y correr este test una vez
 * fuera del CI. Nunca para «arreglar» un rojo: un rojo aquí dice que el conector cambió.
 */
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import goldenJson from "./golden/app-parity.json";
import { TOOL_CORES, type ToolContext } from "../src/toolCore";
import { YalaReader, type Fetcher } from "../src/data";

interface Scenario {
  id: string;
  now: string;
  preferredCurrency: string;
  rows: Record<string, unknown[]>;
}

const scenarios = (goldenJson as unknown as { scenarios: Scenario[] }).scenarios;

/** Las llamadas de cada herramienta: la de por defecto y las variantes que cambian qué se lee o cómo se agrupa. */
const CALLS: Record<string, Record<string, unknown>[]> = {
  listar_cuentas: [{}, { incluir_archivadas: true }],
  listar_categorias: [{}, { incluir_ocultas: true }],
  buscar_movimientos: [{}, { limite: 3 }, { desde: "2026-01-01", hasta: "2026-12-31", texto: "a" }],
  resumen_periodo: [{ periodo: "mes_actual" }, { periodo: "mes_pasado" }, { periodo: "anio_actual", top: 3 }, { periodo: "rango", desde: "2026-01-01", hasta: "2026-12-31" }],
  estado_presupuestos: [{}, { solo_activos: false }],
  listar_recurrentes: [{}, { solo_activos: false }],
};

/**
 * Un PostgREST falso que responde la tabla entera (sin filtrar) y apunta cada consulta. Sin filtros a propósito: lo
 * que se compara es qué PIDE la herramienta y qué calcula con lo que recibe, no la base.
 */
function fakeRest(rows: Record<string, unknown[]>, log: string[]): Fetcher {
  return async (input) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    const table = url.pathname.replace("/rest/v1/", "");
    const params = [...url.searchParams.entries()].filter(([k]) => k !== "offset" && k !== "limit");
    const offset = Number(url.searchParams.get("offset") ?? 0);
    const limit = Number(url.searchParams.get("limit") ?? 1000);
    log.push(`${table}?${new URLSearchParams(params).toString()}&limit=${limit}&offset=${offset}`);
    const all = table === "user_preferences" ? [{ key: "defaultCurrencyCode", value: "PEN" }] : (rows[table] ?? []);
    return Response.json(all.slice(offset, offset + limit));
  };
}

const ENV = { SUPABASE_URL: "https://paridad.supabase.co", SUPABASE_ANON_KEY: "anon", DEFAULT_TIMEZONE: "America/Lima" };

async function runAll(cores: typeof TOOL_CORES): Promise<Record<string, unknown>> {
  const out: Record<string, unknown> = {};
  for (const s of scenarios) {
    vi.setSystemTime(new Date(s.now));
    for (const core of cores) {
      for (const [i, args] of (CALLS[core.name] ?? [{}]).entries()) {
        const log: string[] = [];
        const ctx: ToolContext = { reader: new YalaReader(ENV, "token", fakeRest(s.rows, log)), env: ENV, now: new Date(s.now) };
        let result: unknown;
        try {
          result = await core.run(ctx, args);
        } catch (err) {
          result = { lanzo: err instanceof Error ? `${err.name}: ${err.message}` : String(err) };
        }
        out[`${s.id} · ${core.name} · ${i}`] = { consultas: log, resultado: result };
      }
    }
  }
  return out;
}

describe("paridad del núcleo compartido", () => {
  beforeAll(() => {
    vi.useFakeTimers({ toFake: ["Date"] });
  });
  afterAll(() => {
    vi.useRealTimers();
  });

  it("las seis herramientas piden y devuelven lo mismo que antes del movimiento", async () => {
    expect(scenarios.length).toBeGreaterThanOrEqual(3); // control: hay escenarios que comparar
    const now = await runAll(TOOL_CORES);
    expect(Object.keys(now).length).toBe(scenarios.length * Object.values(CALLS).flat().length);
    await expect(JSON.stringify(now, null, 1) + "\n").toMatchFileSnapshot("./golden/shared-core-parity.json");
  });
});
