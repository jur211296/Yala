import { describe, expect, it } from "vitest";
import type { RawData } from "../src/ae";
import { summarize, supabaseRows, type MetricRow } from "../src/summarize";

const empty = (): RawData => ({ pings: [], registers: [], uses: [], canaries: [], gatewayCanaries: [], serverEvents: [], ai: [] });
const pick = (rows: MetricRow[], metric: string, day: string, dim = "") => rows.find((r) => r.metric === metric && r.day === day && r.dim === dim);

describe("summarize — activos", () => {
  it("activos del día, de 7 y de 30 días son personas DISTINTAS, no sumas", () => {
    const raw = empty();
    // A abre 3 días seguidos; B, un día; C abrió hace 20 días.
    for (const day of ["2026-11-03", "2026-11-04", "2026-11-05"]) raw.pings.push({ day, install: "A", app: "2.1" });
    raw.pings.push({ day: "2026-11-05", install: "B", app: "2.2" });
    raw.pings.push({ day: "2026-10-16", install: "C", app: "2.0.5" });
    const rows = summarize(raw, ["2026-11-05"], "2026-11-05");
    expect(pick(rows, "active", "2026-11-05")?.value).toBe(2);
    expect(pick(rows, "active7", "2026-11-05")?.value).toBe(2);
    expect(pick(rows, "active30", "2026-11-05")?.value).toBe(3);
  });

  it("versión en uso: la ÚLTIMA con la que abrió cada instalación en la semana", () => {
    const raw = empty();
    raw.pings.push({ day: "2026-11-01", install: "A", app: "2.1" }, { day: "2026-11-04", install: "A", app: "2.2" });
    raw.pings.push({ day: "2026-11-02", install: "B", app: "2.1" });
    const rows = summarize(raw, ["2026-11-05"], "2026-11-05");
    expect(pick(rows, "version7", "2026-11-05", "2.2")?.value).toBe(1);
    expect(pick(rows, "version7", "2026-11-05", "2.1")?.value).toBe(1);
  });
});

describe("summarize — uso de funciones y canarios", () => {
  it("use7 cuenta personas distintas por función en la ventana", () => {
    const raw = empty();
    raw.uses.push(
      { day: "2026-11-01", install: "A", fn: "panel" },
      { day: "2026-11-05", install: "A", fn: "panel" },
      { day: "2026-11-05", install: "B", fn: "panel" },
      { day: "2026-10-20", install: "C", fn: "panel" }, // fuera de la semana
    );
    const rows = summarize(raw, ["2026-11-05"], "2026-11-05");
    expect(pick(rows, "use7", "2026-11-05", "panel")?.value).toBe(2);
    expect(pick(rows, "use", "2026-11-05", "panel")?.value).toBe(2);
  });

  it("canarios: veces y aparatos, del día y de 7/30 días", () => {
    const raw = empty();
    raw.canaries.push(
      { day: "2026-11-05", install: "A", name: "cloudkitExportFailed", n: 3 },
      { day: "2026-11-04", install: "B", name: "cloudkitExportFailed", n: 1 },
      { day: "2026-10-10", install: "C", name: "cloudkitExportFailed", n: 9 },
    );
    const rows = summarize(raw, ["2026-11-05"], "2026-11-05");
    expect(pick(rows, "canary", "2026-11-05", "cloudkitExportFailed")).toMatchObject({ value: 3, devices: 1 });
    expect(pick(rows, "canary7", "2026-11-05", "cloudkitExportFailed")).toMatchObject({ value: 4, devices: 2 });
    expect(pick(rows, "canary30", "2026-11-05", "cloudkitExportFailed")).toMatchObject({ value: 13, devices: 3 });
  });
});

describe("summarize — altas por persona", () => {
  it("un alta en la nube (cloud|bornCloud + local|initial) cuenta UNA, como nube; migrar y activar completo no son altas", () => {
    const raw = empty();
    raw.registers.push(
      { day: "2026-11-05", install: "N", kind: "cloud", mode: "bornCloud", n: 1 },
      { day: "2026-11-05", install: "N", kind: "local", mode: "initial", n: 1 },
      { day: "2026-11-05", install: "P", kind: "local", mode: "initial", n: 1 },
      { day: "2026-11-05", install: "M", kind: "cloud", mode: "migration", n: 1 },
      { day: "2026-11-05", install: "G", kind: "local", mode: "fullActivation", n: 1 },
    );
    const rows = summarize(raw, ["2026-11-05"], "2026-11-05");
    expect(pick(rows, "alta", "2026-11-05", "cloud")?.value).toBe(1);
    expect(pick(rows, "alta", "2026-11-05", "local")?.value).toBe(1);
    expect(pick(rows, "cohort_size", "2026-11-05")?.value).toBe(2);
  });

  it("el alta cuenta el PRIMER día: el aviso local que llega al día siguiente no suma otra", () => {
    const raw = empty();
    raw.registers.push(
      { day: "2026-11-04", install: "N", kind: "cloud", mode: "bornCloud", n: 1 },
      { day: "2026-11-05", install: "N", kind: "local", mode: "initial", n: 1 },
    );
    const rows = summarize(raw, ["2026-11-04", "2026-11-05"], "2026-11-05");
    expect(pick(rows, "alta", "2026-11-04", "cloud")?.value).toBe(1);
    expect(pick(rows, "alta", "2026-11-05", "local")).toBeUndefined();
  });
});

describe("summarize — cohortes de alta", () => {
  it("la tasa a 7 días solo se escribe con la ventana cerrada, y cuenta quien volvió entre C+7 y C+13", () => {
    const raw = empty();
    const C = "2026-10-20";
    raw.registers.push({ day: C, install: "A", kind: "local", mode: "full", n: 1 }, { day: C, install: "B", kind: "cloud", mode: "bornCloud", n: 1 });
    raw.pings.push({ day: "2026-10-28", install: "A", app: "2.1" }); // C+8: vuelve
    raw.pings.push({ day: "2026-10-22", install: "B", app: "2.1" }); // C+2: no cuenta como «vuelve a la semana»
    const abierta = summarize(raw, ["2026-11-01"], "2026-11-01"); // C+12: ventana sin cerrar
    expect(pick(abierta, "cohort_size", C)?.value).toBe(2);
    expect(pick(abierta, "cohort_r7", C)).toBeUndefined();
    const cerrada = summarize(raw, ["2026-11-02"], "2026-11-02"); // C+13
    expect(pick(cerrada, "cohort_r7", C)).toMatchObject({ value: 1, devices: 2 });
  });
});

describe("summarize — IA", () => {
  it("costo con el precio del modelo; modelo sin precio va aparte; la transcripción no cuenta como «sin precio»", () => {
    const raw = empty();
    raw.ai.push(
      { day: "2026-11-05", task: "photo.read", provider: "openai", model: "gpt-6-luna", ok: true, n: 2, inputTokens: 1_000_000, cachedTokens: 0, outputTokens: 0 },
      { day: "2026-11-05", task: "chat.answer", provider: "openai", model: "modelo-nuevo", ok: true, n: 3, inputTokens: 10, cachedTokens: 0, outputTokens: 10 },
      { day: "2026-11-05", task: "voice.transcribe", provider: "openai", model: "gpt-transcribe", ok: true, n: 4, inputTokens: 0, cachedTokens: 0, outputTokens: 0 },
    );
    const rows = summarize(raw, ["2026-11-05"], "2026-11-05");
    expect(pick(rows, "ai_cost_usd", "2026-11-05", "photo.read|openai|gpt-6-luna|ok")?.value).toBeCloseTo(0.1);
    expect(pick(rows, "ai_unpriced", "2026-11-05", "chat.answer|openai|modelo-nuevo|ok")?.value).toBe(3);
    expect(rows.some((r) => r.metric === "ai_unpriced" && r.dim.includes("gpt-transcribe"))).toBe(false);
    expect(pick(rows, "ai_calls", "2026-11-05", "voice.transcribe|openai|gpt-transcribe|ok")?.value).toBe(4);
  });
});

describe("privacidad del resumen", () => {
  it("ninguna fila lleva un identificador de instalación", () => {
    const raw = empty();
    raw.pings.push({ day: "2026-11-05", install: "a1b2c3d4e5f60718", app: "2.1" });
    raw.registers.push({ day: "2026-11-05", install: "a1b2c3d4e5f60718", kind: "local", mode: "full", n: 1 });
    raw.uses.push({ day: "2026-11-05", install: "a1b2c3d4e5f60718", fn: "panel" });
    raw.canaries.push({ day: "2026-11-05", install: "a1b2c3d4e5f60718", name: "x", n: 1 });
    expect(JSON.stringify(summarize(raw, ["2026-11-05"], "2026-11-05"))).not.toContain("a1b2c3d4e5f60718");
  });

  it("supabaseRows guarda solo números", () => {
    expect(supabaseRows("2026-11-05", { groups_total: 4, raro: "texto", nan: Number.NaN })).toEqual([
      { day: "2026-11-05", metric: "sb", dim: "groups_total", value: 4, devices: null },
    ]);
  });
});
