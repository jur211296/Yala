/**
 * Lote 1 de «Yala web como la app» (base visual).
 *
 * 1. `Monto` dibuja el mismo texto que `money()` de antes, en los 16 idiomas: copiar, buscar y los lectores de pantalla
 *    no cambian. La referencia es una copia literal del `money()` anterior al lote.
 * 2. El tema se guarda en el navegador y se pone en `<html>`; sin almacenamiento, «Como el sistema».
 * 3. Los colores: cada tema define TODAS las variables (si a uno le falta una, hereda la del claro y sale un texto
 *    oscuro sobre fondo oscuro), y `app.css` no tiene colores por sistema que ignoren el tema elegido en Ajustes.
 * 4. Los nombres de los temas existen en los 16 idiomas.
 */
import { readFileSync } from "node:fs";
import { afterEach, describe, expect, it } from "vitest";
import { LANGS, loadLang, loadTexts, locale } from "../src/client/i18n";
import { money, moneyParts } from "../src/client/app/format";
import { aplicarTema, guardarTema, temaElegido, temaEsOscuro, TEMAS } from "../src/client/tema";

/** Un `localStorage` en memoria. */
function memStorage() {
  const m = new Map<string, string>();
  return {
    getItem: (k: string) => m.get(k) ?? null,
    setItem: (k: string, v: string) => void m.set(k, v),
    removeItem: (k: string) => void m.delete(k),
  };
}
const g = globalThis as { localStorage?: unknown; document?: unknown };
afterEach(() => {
  delete g.localStorage;
  delete g.document;
});

/** El `money()` de antes del lote, copiado tal cual. */
function moneyAntes(amount: number | null | undefined, currency: string | null | undefined, opts: { sign?: boolean } = {}): string {
  if (amount == null || !Number.isFinite(amount)) return "—";
  const code = currency && /^[A-Z]{3}$/.test(currency) ? currency : null;
  const abs = Math.abs(amount);
  let s: string;
  try {
    if (code) {
      const parts = new Intl.NumberFormat(locale(), { style: "currency", currency: code, currencyDisplay: "narrowSymbol", minimumFractionDigits: 2, maximumFractionDigits: 2 }).formatToParts(abs);
      s = parts
        .map((p) => (p.type === "currency" && code === "PEN" ? "S/" : p.value))
        .join("")
        .replace(/^S\/(?=\d)/, "S/ ");
    } else {
      s = new Intl.NumberFormat(locale(), { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(abs);
    }
  } catch {
    s = `${abs.toFixed(2)} ${code ?? ""}`.trim();
  }
  if (amount < 0) return `−${s}`;
  return opts.sign && amount > 0 ? `+${s}` : s;
}

const IMPORTES = [0, 0.5, 12.9, -1420.3, 55997.65, 1234567.891, -0.004];
const DIVISAS = ["PEN", "USD", "EUR", "JPY", "BRL", "GBP", "MXN", null, "xx"];

describe("Monto: mismo texto que antes", () => {
  it.each(LANGS.map((l) => l.code))("en %s", async (code) => {
    g.localStorage = memStorage();
    (g.localStorage as ReturnType<typeof memStorage>).setItem("yala-web-idioma", code);
    await loadTexts();
    for (const imp of IMPORTES) {
      for (const div of DIVISAS) {
        for (const sign of [false, true]) {
          expect(money(imp, div, { sign }), `${imp} ${div} ${sign}`).toBe(moneyAntes(imp, div, { sign }));
        }
      }
    }
    expect(money(null, "PEN")).toBe("—");
    expect(money(Number.NaN, "PEN")).toBe("—");
  });

  it("separa símbolo, entero y decimales como la app", async () => {
    g.localStorage = memStorage();
    (g.localStorage as ReturnType<typeof memStorage>).setItem("yala-web-idioma", "es");
    await loadTexts();
    // `Intl` separa «S/» con un espacio duro en es-PE.
    const sol = moneyParts(55997.65, "PEN");
    expect({ ...sol, antes: sol?.antes.replace(/\s/g, " ") }).toEqual({ signo: "", antes: "S/ ", entero: "55,997", decimales: ".65", despues: "" });
    expect(moneyParts(-12.5, "PEN")).toMatchObject({ signo: "−", entero: "12", decimales: ".50" });
    (g.localStorage as ReturnType<typeof memStorage>).setItem("yala-web-idioma", "de");
    await loadTexts();
    const de = moneyParts(1234.5, "EUR");
    expect(de).toMatchObject({ antes: "", entero: "1.234", decimales: ",50" });
    expect(de?.despues.trim()).toBe("€");
  });
});

describe("el tema", () => {
  it("por defecto es «Como el sistema», también sin almacenamiento", () => {
    expect(temaElegido()).toBe("sistema");
    g.localStorage = memStorage();
    expect(temaElegido()).toBe("sistema");
    g.localStorage = {
      getItem: () => {
        throw new Error("bloqueado");
      },
    };
    expect(temaElegido()).toBe("sistema");
    expect(() => guardarTema("claro")).not.toThrow();
  });

  it("se guarda, se lee y descarta lo que no es un tema", () => {
    const st = memStorage();
    g.localStorage = st;
    for (const t of TEMAS) {
      guardarTema(t);
      expect(temaElegido()).toBe(t);
    }
    guardarTema("sistema");
    expect(st.getItem("yala-web-tema")).toBeNull();
    st.setItem("yala-web-tema", "rosa");
    expect(temaElegido()).toBe("sistema");
  });

  it("pone data-tema en <html> y el color de la barra del navegador, y lo devuelve al sistema", () => {
    const metas = [
      { content: "#fafbff", dataset: {} as Record<string, string | undefined> },
      { content: "#000000", dataset: {} as Record<string, string | undefined> },
    ];
    const doc = { documentElement: { dataset: {} as Record<string, string | undefined> }, querySelectorAll: () => metas };
    aplicarTema("oscuro", doc);
    expect(doc.documentElement.dataset.tema).toBe("oscuro");
    expect(metas.map((m) => m.content)).toEqual(["#000000", "#000000"]);
    aplicarTema("liquid", doc);
    expect(doc.documentElement.dataset.tema).toBe("liquid");
    aplicarTema("claro", doc);
    expect(metas.map((m) => m.content)).toEqual(["#fafbff", "#fafbff"]);
    aplicarTema("sistema", doc);
    expect("tema" in doc.documentElement.dataset).toBe(false);
    expect(metas.map((m) => m.content)).toEqual(["#fafbff", "#000000"]);
  });

  it("sin documento (en el Worker) no hace nada", () => {
    expect(() => aplicarTema("claro")).not.toThrow();
  });
});

describe("los colores de cada tema", () => {
  const styles = readFileSync(new URL("../src/client/styles.css", import.meta.url), "utf8");
  const app = readFileSync(new URL("../src/client/app.css", import.meta.url), "utf8");

  /** Las variables que declara el bloque que empieza en `selector {`. */
  function vars(selector: string): string[] {
    const i = styles.indexOf(`${selector} {`);
    expect(i, selector).toBeGreaterThanOrEqual(0);
    const body = styles.slice(i, styles.indexOf("}", i));
    return [...body.matchAll(/(--[a-z0-9-]+):/g)].map((m) => m[1]!).sort();
  }

  it("los cuatro bloques definen las mismas variables", () => {
    // El claro es el primer `:root {` con `--bg`.
    const all = [...styles.matchAll(/:root \{([^}]*)\}/g)].map((m) => m[1]!).find((b) => b.includes("--bg:"));
    expect(all).toBeDefined();
    const claro = [...all!.matchAll(/(--[a-z0-9-]+):/g)].map((m) => m[1]!).sort();
    expect(claro.length).toBeGreaterThan(20);
    expect(vars(":root:not([data-tema])")).toEqual(claro);
    expect(vars(':root[data-tema="liquid"]')).toEqual(claro);
    expect(vars(':root[data-tema="oscuro"]')).toEqual(claro);
  });

  it("el oscuro por sistema es el «Oscuro» de Ajustes, no Liquid Glass", () => {
    const bloque = (sel: string) => {
      const i = styles.indexOf(`${sel} {`);
      return styles
        .slice(styles.indexOf("{", i) + 1, styles.indexOf("}", i))
        .split("\n")
        .map((l) => l.trim())
        .filter(Boolean);
    };
    expect(bloque(":root:not([data-tema])")).toEqual(bloque(':root[data-tema="oscuro"]'));
    expect(bloque(":root:not([data-tema])")).not.toEqual(bloque(':root[data-tema="liquid"]'));
  });

  it("app.css y la entrada no deciden colores por el sistema", () => {
    expect(app).not.toMatch(/prefers-color-scheme/);
    // En styles.css solo el bloque del oscuro por sistema mira al sistema.
    expect(styles.match(/prefers-color-scheme/g)).toHaveLength(1);
  });

  it("cada tema lleva el logo oficial de su fondo, y los dos están en public/", () => {
    const logo = (sel: string) => {
      const i = sel === "claro" ? styles.indexOf(":root {\n  --bg:") : styles.indexOf(`${sel} {`);
      return styles.slice(i, styles.indexOf("}", i)).match(/--logo: url\("\/([^"]+)"\)/)?.[1];
    };
    expect(logo("claro")).toBe("logo-claro.png");
    for (const sel of [":root:not([data-tema])", ':root[data-tema="oscuro"]', ':root[data-tema="liquid"]']) expect(logo(sel), sel).toBe("logo-oscuro.png");
    for (const f of ["logo-claro.png", "logo-oscuro.png", "favicon-32.png", "apple-touch-icon.png"]) {
      expect(() => readFileSync(new URL(`../public/${f}`, import.meta.url))).not.toThrow();
    }
  });

  it("la letra de las cifras cae en Nunito, servida desde aquí", () => {
    expect(styles).toMatch(/--round: ui-rounded, "SF Pro Rounded", Nunito,/);
    for (const m of styles.matchAll(/url\("(\.\/fonts\/[^"]+)"\)/g)) {
      expect(m[1]!.startsWith("./fonts/")).toBe(true);
      expect(() => readFileSync(new URL(`../src/client/${m[1]!.slice(2)}`, import.meta.url))).not.toThrow();
    }
  });
});

describe("los nombres de los temas", () => {
  it.each(LANGS.map((l) => l.code))("en %s", async (code) => {
    const tx = await loadLang(code);
    for (const k of ["temaValor", "temaClaro", "temaOscuro", "temaLiquid"] as const) {
      expect(tx.app[k].trim().length, k).toBeGreaterThan(0);
    }
    expect(new Set([tx.app.temaValor, tx.app.temaClaro, tx.app.temaOscuro, tx.app.temaLiquid]).size).toBe(4);
  });
});

describe("si la página se ve en oscuro", () => {
  const g = globalThis as { matchMedia?: unknown };
  afterEach(() => delete g.matchMedia);

  it("un tema forzado manda; «Como el sistema» pregunta al sistema", () => {
    expect(temaEsOscuro("claro")).toBe(false);
    expect(temaEsOscuro("oscuro")).toBe(true);
    expect(temaEsOscuro("liquid")).toBe(true);
    expect(temaEsOscuro("sistema")).toBe(false); // sin matchMedia (el Worker), claro
    g.matchMedia = () => ({ matches: true });
    expect(temaEsOscuro("sistema")).toBe(true);
    g.matchMedia = () => ({ matches: false });
    expect(temaEsOscuro("sistema")).toBe(false);
  });
});
