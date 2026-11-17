/**
 * Lote 5 de «Yala web como la app»: Planificación, Estadísticas, Grupos, Bandeja y Ajustes.
 *
 * - El ícono y el color de una categoría se buscan por su nombre (`categorias.ts`, decisión D1): la API de Presupuestos,
 *   Pagos y Estadísticas solo manda el nombre.
 * - La cabecera de Grupos con una sola divisa enseña el neto, como `groups.hero.net*` de la app; con varias, no convierte.
 * - La barra de un presupuesto: el color de la categoría, ámbar en riesgo y rosa al pasarse (`BudgetProgressBar`).
 * - Los rótulos nuevos («Ajustes», «Bandeja de Entrada», «Te quedan», «Te deben en total · en S/»…) son los de la app en
 *   sus 16 idiomas: se leen de `Localizable.strings`.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { LANGS, loadLang, type Lang } from "../src/client/i18n";
import { colorBarra, resumenNeto, simboloPorNombre, type CategoriaConSimbolo } from "../src/client/app/pantallas";

const cats: CategoriaConSimbolo[] = [
  {
    id: "k1",
    nombre: "Comida",
    es_ingreso: false,
    oculta: false,
    icono: "fork.knife",
    color: "#F59E0B",
    subcategorias: [
      { id: "s1", nombre: "Cafetería", oculta: false, icono: "cup.and.saucer.fill", color: null },
      { id: "s2", nombre: "Comida", oculta: false, icono: "takeoutbag.and.cup.and.straw.fill", color: "#111111" },
    ],
  },
  { id: "k2", nombre: "Viejo", es_ingreso: false, oculta: true, icono: "car.fill", color: "#0EA5E9", subcategorias: [] },
];

describe("ícono y color por nombre", () => {
  it("una categoría por su nombre, sin distinguir mayúsculas", () => {
    const s = simboloPorNombre(cats, "comida");
    expect(s.sf).toBe("fork.knife");
    expect(s.color).toBe("#F59E0B");
  });

  it("una subcategoría sin color toma el de su categoría", () => {
    const s = simboloPorNombre(cats, "Cafetería", { primero: "subcategoria" });
    expect(s.sf).toBe("cup.and.saucer.fill");
    expect(s.color).toBe("#F59E0B");
  });

  it("con el mismo nombre, manda lo que se pide primero", () => {
    expect(simboloPorNombre(cats, "Comida").color).toBe("#F59E0B");
    expect(simboloPorNombre(cats, "Comida", { primero: "subcategoria" }).color).toBe("#111111");
  });

  it("sin coincidencia, oculta o sin categorías: el respaldo", () => {
    expect(simboloPorNombre(cats, "Viejo").sf).toBe("tag.fill");
    expect(simboloPorNombre(null, "Comida").sf).toBe("tag.fill");
    expect(simboloPorNombre(cats, null, { sf: "chart.pie.fill", color: "var(--fill)" })).toMatchObject({ sf: "chart.pie.fill", color: "var(--fill)" });
  });
});

describe("la cabecera de Grupos", () => {
  it("con una divisa, el neto de lo que te deben y lo que debes", () => {
    expect(resumenNeto({ teDeben: [{ divisa: "PEN", importe: 486.5 }], debes: [{ divisa: "PEN", importe: 120 }] })).toEqual({
      divisa: "PEN",
      teDeben: 486.5,
      debes: 120,
      neto: 366.5,
    });
  });

  it("con varias divisas no convierte: sin neto", () => {
    expect(resumenNeto({ teDeben: [{ divisa: "PEN", importe: 10 }], debes: [{ divisa: "USD", importe: 5 }] })).toBeNull();
  });

  it("sin deudas: sin divisa (todo saldado)", () => {
    expect(resumenNeto({ teDeben: [], debes: [] })).toEqual({ divisa: null, teDeben: 0, debes: 0, neto: 0 });
  });
});

describe("la barra de un presupuesto", () => {
  it("color de la categoría; ámbar en riesgo; rosa al pasarse", () => {
    expect(colorBarra({ estado: "en_camino" }, "#22C55E")).toBe("#22C55E");
    expect(colorBarra({ estado: "en_riesgo" }, "#22C55E")).toBe("var(--risk-fill)");
    expect(colorBarra({ estado: "excedido" }, "#22C55E")).toBe("var(--owe)");
  });
});

/** El valor de una clave en el `Localizable.strings` de la app para un idioma. */
function deLaApp(lproj: string, key: string): string {
  const txt = readFileSync(new URL(`../../Yala/Resources/${lproj}.lproj/Localizable.strings`, import.meta.url), "utf8");
  const m = new RegExp(`^"${key.replace(/\./g, "\\.")}"\\s*=\\s*"((?:[^"\\\\]|\\\\.)*)";`, "m").exec(txt);
  if (!m) throw new Error(`${lproj}: falta ${key}`);
  return m[1]!.replace(/\\"/g, '"');
}

/** La carpeta de la app de cada idioma de la web (es-419 y pt usan la base, como en la app). */
const LPROJ: Record<Lang, string> = { es: "es", "es-419": "es", "es-AR": "es-AR", "es-ES": "es-ES", en: "en", "en-GB": "en-GB", de: "de", fr: "fr", it: "it", ja: "ja", nl: "nl", pl: "pl", pt: "pt-BR", "pt-BR": "pt-BR", "pt-PT": "pt-PT", "zh-Hans": "zh-Hans" };

describe("los rótulos del lote 5 son los de la app", () => {
  for (const { code } of LANGS) {
    it(code, async () => {
      const t = await loadLang(code);
      const app = (k: string) => deLaApp(LPROJ[code], k);
      expect(t.app.configurar, "Ajustes").toBe(app("profile.title"));
      expect(t.app.bandejaTitulo).toBe(app("inbox.title"));
      expect(t.pre.teQuedan).toBe(app("budgets.l9.remainingLabel"));
      expect(t.pre.tePasastePor).toBe(app("budgets.l9.overLabel"));
      expect(t.pre.enElLimite).toBe(app("budgets.l9.atLimit"));
      expect(t.pre.tePasasteEstado).toBe(app("budgets.l9.overLimitWord"));
      expect(t.pre.deLimite("A", "B")).toBe(app("budgets.l9.spentOfLimit").replace("%1$@", "A").replace("%2$@", "B"));
      expect(t.pre.dias(1)).toBe(app("budgets.l9.days.one"));
      expect(t.pre.dias(15)).toBe(app("budgets.l9.days").replace("%@", "15"));
      expect(t.grp.netoTeDeben("S/")).toBe(app("groups.hero.netOwedToMe").replace("%@", "S/"));
      expect(t.grp.netoDebes("S/")).toBe(app("groups.hero.netIOwe").replace("%@", "S/"));
      expect(t.grp.netoAMano("S/")).toBe(app("groups.hero.netEven").replace("%@", "S/"));
      expect(t.grp.rotTeDeben).toBe(app("groups.summary.owedToMe"));
      expect(t.grp.rotDebes).toBe(app("groups.summary.iOwe"));
    });
  }

  it("las tres explicaciones del «?» existen en cada idioma y no se quedaron en español", async () => {
    const es = await loadLang("es");
    for (const { code } of LANGS) {
      const t = await loadLang(code);
      for (const v of [t.est.netoExplica, t.pag.porPagarExplica, t.grp.totalExplica]) expect(v.length, code).toBeGreaterThan(20);
      if (!code.startsWith("es")) expect(t.est.netoExplica, code).not.toBe(es.est.netoExplica);
    }
  });
});
