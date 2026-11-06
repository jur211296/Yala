import { describe, expect, it } from "vitest";
import { addDays, dayRange } from "../src/days";
import { int, people, peopleNum, usd, vsLastWeek, dec, pct } from "../src/format";
import { levelFor } from "../src/health";
import { renderPage } from "../src/render";
import type { MetricRow } from "../src/summarize";
import { buildView } from "../src/view";

const L = "2026-11-05";
const row = (day: string, metric: string, value: number, dim = "", devices: number | null = null): MetricRow => ({ day, metric, dim, value, devices });

function fixture(): MetricRow[] {
  const rows: MetricRow[] = [];
  // Semana actual: 15 activos/día; la anterior: 13.
  for (const d of dayRange(addDays(L, -6), L)) rows.push(row(d, "active", d === "2026-11-01" ? 20 : 15));
  for (const d of dayRange(addDays(L, -13), addDays(L, -7))) rows.push(row(d, "active", 13));
  rows.push(row(L, "active7", 35), row(L, "active30", 82));
  rows.push(row(L, "version7", 31, "2.1"), row(L, "version7", 3, "2.2"), row(L, "version7", 1, "2.0.5"));
  rows.push(row(L, "alta", 5, "local", 5), row(L, "alta", 3, "cloud", 3));
  rows.push(row(addDays(L, -8), "alta", 28, "local", 28));
  // El alta en la nube deja también su `register` local: no debe sumar.
  rows.push(row(L, "register", 8, "local|initial", 8), row(L, "register", 3, "cloud|bornCloud", 3));
  rows.push(row(L, "use7", 14, "registrarMovimiento", 14), row(L, "use7", 2, "exportar", 2));
  rows.push(row(L, "gw_canary", 26, "groupFanoutDelivered"));
  rows.push(row(L, "canary7", 34, "budgetFiltersAppearEmpty", 9), row(L, "canary7", 3066, "cloudkitExportSucceeded", 37));
  rows.push(row(L, "server", 4, "appstoreNotification|SUBSCRIBED|INITIAL_BUY|trial|Production"));
  rows.push(row(L, "server", 9, "appstoreNotification|SUBSCRIBED|INITIAL_BUY|trial|Sandbox")); // no cuenta
  rows.push(row(L, "server", 2, "appstoreNotification|SUBSCRIBED|INITIAL_BUY|paid|Production"));
  rows.push(row(L, "ai_calls", 6, "photo.read|openai|gpt-6-luna|ok"), row(L, "ai_cost_usd", 1.2, "photo.read|openai|gpt-6-luna|ok"));
  return rows;
}

const text = (v: ReturnType<typeof buildView>, id: string) => {
  const s = v.sections.find((x) => x.id === id);
  return s ? JSON.stringify(s) : "";
};
const lead = (v: ReturnType<typeof buildView>, id: string) =>
  v.sections.find((x) => x.id === id)?.lead.map((s) => s.t).join("") ?? "";

describe("format — números en español y privacidad", () => {
  it.each([
    [3050, "3.050"],
    [15, "15"],
    [1234567, "1.234.567"],
  ])("int(%d) = %s", (n, s) => expect(int(n)).toBe(s));
  it("decimales con coma, sin «,0»", () => {
    expect(dec(15.3)).toBe("15,3");
    expect(dec(15)).toBe("15");
  });
  it("menos de 3 personas no se pinta con su cifra", () => {
    expect(people(1, "persona", "personas")).toBe("menos de 3 personas");
    expect(people(2, "persona", "personas")).toBe("menos de 3 personas");
    expect(people(3, "persona", "personas")).toBe("3 personas");
    expect(people(0, "persona", "personas")).toBe("0 personas");
    expect(peopleNum(2)).toBe("< 3");
  });
  it("comparación con la semana anterior y porcentajes", () => {
    expect(vsLastWeek(15.3, 13)).toBe("2 más que la semana pasada");
    expect(vsLastWeek(8, 28)).toBe("20 menos que la semana pasada");
    expect(vsLastWeek(5, 5)).toBe("igual que la semana pasada");
    expect(pct(3050, 3081)).toBe("99 %");
    expect(pct(10, 10)).toBe("100 %");
    expect(usd(1.2)).toBe("US$ 1,20");
    expect(usd(0)).toBe("US$ 0,00");
  });
});

describe("buildView — frases de plantilla con las cifras", () => {
  const v = buildView(fixture(), []);

  it("Uso: media de la semana contra la anterior y el mejor día", () => {
    expect(v.week).toMatchObject({ from: "2026-10-30", to: L });
    // (6×15 + 20) / 7 = 15,7 → «16 personas al día», 3 más que 13.
    expect(lead(v, "uso")).toBe("Esta semana abrieron Yala 16 personas al día de media, 3 más que la semana pasada.");
    expect(text(v, "uso")).toContain("El mejor día fue el domingo 1 de noviembre, con 20 personas.");
    expect(text(v, "uso")).toContain("Casi todos ya están en la 2.1");
  });

  it("Uso: función con 2 personas sale como «< 3»", () => {
    const uso = v.sections.find((s) => s.id === "uso");
    const card = uso?.cards.find((c) => c.title === "Lo que más se usa");
    expect(card?.bars?.find((b) => b.label === "Exportar")?.display).toBe("< 3");
    expect(card?.say).toBe("Registrar un movimiento es lo más usado: 14 personas en 7 días.");
  });

  it("Registro: local, nube y la semana anterior", () => {
    expect(lead(v, "registro")).toBe("Esta semana se dieron de alta 8 personas: 5 sin cuenta y 3 con cuenta en la nube. La anterior fueron 28.");
  });

  it("Registro: embudo del alta con el paso donde más se pierde, y fuera de «Lo que más se usa»", () => {
    const rows = fixture();
    rows.push(
      row(L, "use7", 10, "alta.bienvenida", 10),
      row(L, "use7", 9, "alta.paso.name", 9),
      row(L, "use7", 5, "alta.paso.currencyName", 5),
      row(L, "use7", 4, "alta.termina", 4),
      row(L, "use7", 7, "alta.camino.privada", 7),
      row(L, "use7", 3, "alta.camino.nube", 3),
    );
    const v2 = buildView(rows, []);
    const registro = v2.sections.find((s) => s.id === "registro");
    const funnel = registro?.cards.find((c) => c.title.startsWith("Dónde abandonan"));
    // purpose, accountType: nadie los marcó pero 5 llegaron más allá ⇒ cuentan 5, no 0.
    expect(funnel?.bars?.map((b) => b.value)).toEqual([10, 9, 5, 5, 5, 4, 4, 4, 4]);
    expect(funnel?.say).toBe("Se pierden 6 de cada 10 antes de terminar; donde más, en «Elige para qué la usa».");
    expect(registro?.cards.find((c) => c.title.startsWith("Qué camino"))?.say).toBe("Privada (sin cuenta) es el camino más elegido en la bienvenida.");
    const usos = v2.sections.find((s) => s.id === "uso")?.cards.find((c) => c.title === "Lo que más se usa");
    expect(JSON.stringify(usos)).not.toContain("alta");
  });

  it("Pro: solo cuentan los avisos de Production", () => {
    expect(lead(v, "pro")).toBe("Esta semana empezaron 4 pruebas de Pro y hubo menos de 3 compras.");
  });

  it("Grupos sin conteos de la base: lo dice, no inventa", () => {
    expect(lead(v, "grupos")).toBe("Esta semana se entregaron 26 avisos de gastos compartidos sin un solo fallo.");
    expect(text(v, "grupos")).toContain("Sin datos de la base todavía");
  });

  it("IA: un costo por persona minúsculo no dice «0 centavos»", () => {
    const rows = fixture().filter((r) => r.metric !== "ai_cost_usd");
    rows.push(row(L, "ai_cost_usd", 0.01, "photo.read|openai|gpt-6-luna|ok"));
    expect(JSON.stringify(buildView(rows, []).sections.find((s) => s.id === "ia"))).toContain("menos de un centavo por persona activa");
  });

  it("IA: costo por persona activa", () => {
    expect(text(v, "ia")).toContain("La IA costó US$ 1,20 esta semana, unos 3,4 centavos por persona activa.");
  });

  it("Salud: los informativos no cuentan como señal; el resto se colorea por aparatos", () => {
    expect(lead(v, "salud")).toBe("1 aviso interno dio señal esta semana; 1 pasa su umbral rojo.");
    expect(levelFor("cloudkitExportSucceeded", 37)).toBe("info");
    expect(levelFor("budgetFiltersAppearEmpty", 9)).toBe("bad");
    expect(levelFor("budgetFiltersAppearEmpty", 1)).toBe("warn");
    expect(levelFor("cloudkitExportFailed", 2)).toBe("ok");
  });

  it("sin días resumidos: página vacía que lo dice", () => {
    expect(buildView([], []).hasData).toBe(false);
    expect(renderPage(buildView([], []), { throughDay: null, lastRun: "", generatedAt: "" })).toContain("Todavía no hay ningún día resumido");
  });
});

describe("renderPage — escapa lo que viene de datos", () => {
  it("un nombre de canario con HTML sale escapado", () => {
    const rows = fixture();
    rows.push(row(L, "canary7", 99, "<script>x</script>", 9));
    const html = renderPage(buildView(rows, []), { throughDay: L, lastRun: "ok", generatedAt: "ahora" });
    expect(html).not.toContain("<script>x</script>");
    expect(html).toContain("&lt;script&gt;");
  });
});
