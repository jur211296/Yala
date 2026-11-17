/**
 * Lote 4 de «Yala web como la app»: Panel, Registros y Nuevo registro (`registro.ts` y los textos).
 *
 * - Lo gastado de cada día sigue la cabecera de día de la app (`DailySpendingCalculator.dayTotals(...).expense`): solo
 *   gastos, con signo (una devolución resta), en la divisa preferida; sin cifra si algún gasto no tiene conversión.
 * - La píldora de necesidad sale donde la app la pone: en un gasto con subcategoría.
 * - Los rótulos nuevos («Tu saldo hoy», «Te queda», «¿Cuánto gastaste?»…) son los de la app en sus 16 idiomas: se leen
 *   de `Localizable.strings`, así que si la app cambia uno, esta prueba lo dice.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { LANGS, loadLang, type Lang } from "../src/client/i18n";
import { gastadoDelDia, muestraNecesidad, tituloDe, type RegistroBase } from "../src/client/app/registro";

const mov = (over: Partial<RegistroBase>): RegistroBase => ({
  importe_en_divisa_preferida: -10,
  nota: null,
  tipo: "gasto",
  categoria: "Comida",
  subcategoria: "Cafetería",
  cuenta: "Cuenta Principal",
  necesidad: "opcional",
  ...over,
});

describe("lo gastado en un día", () => {
  it("suma los gastos en la divisa preferida y deja fuera ingresos, transferencias y ajustes", () => {
    const dia = [
      mov({ importe_en_divisa_preferida: -38.5 }),
      mov({ importe_en_divisa_preferida: -12.9 }),
      mov({ tipo: "ingreso", importe_en_divisa_preferida: 8500 }),
      mov({ tipo: "transferencia", importe_en_divisa_preferida: -300 }),
      mov({ tipo: "ajuste_de_saldo", importe_en_divisa_preferida: -50 }),
    ];
    expect(gastadoDelDia(dia)).toBe(51.4);
  });

  it("una devolución en una categoría de gasto resta (suma con signo, como la app)", () => {
    expect(gastadoDelDia([mov({ importe_en_divisa_preferida: -100 }), mov({ importe_en_divisa_preferida: 30 })])).toBe(70);
  });

  it("no enseña cifra sin gastos, con 0 o con un gasto sin conversión", () => {
    expect(gastadoDelDia([mov({ tipo: "ingreso", importe_en_divisa_preferida: 100 })])).toBeNull();
    expect(gastadoDelDia([mov({ importe_en_divisa_preferida: -20 }), mov({ importe_en_divisa_preferida: 20 })])).toBeNull();
    expect(gastadoDelDia([mov({ importe_en_divisa_preferida: -20 }), mov({ importe_en_divisa_preferida: null })])).toBeNull();
  });
});

describe("la fila de un registro", () => {
  it("la píldora de necesidad solo en un gasto con subcategoría", () => {
    expect(muestraNecesidad(mov({}))).toBe(true);
    expect(muestraNecesidad(mov({ tipo: "ingreso" }))).toBe(false);
    expect(muestraNecesidad(mov({ subcategoria: null }))).toBe(false);
    expect(muestraNecesidad(mov({ tipo: "transferencia" }))).toBe(false);
  });

  it("el título es la nota y, sin nota, la subcategoría o la categoría", () => {
    expect(tituloDe(mov({ nota: "Almuerzo" }))).toBe("Almuerzo");
    expect(tituloDe(mov({}))).toBe("Cafetería");
    expect(tituloDe(mov({ subcategoria: null }))).toBe("Comida");
  });
});

/** El valor de una clave en el `Localizable.strings` de la app para un idioma. */
function deLaApp(lproj: string, key: string): string {
  const txt = readFileSync(new URL(`../../Yala/Resources/${lproj}.lproj/Localizable.strings`, import.meta.url), "utf8");
  const m = new RegExp(`^"${key.replace(/\./g, "\\.")}"\\s*=\\s*"((?:[^"\\\\]|\\\\.)*)";`, "m").exec(txt);
  if (!m) throw new Error(`${lproj}: falta ${key}`);
  return m[1]!.replace(/\\"/g, '"');
}

const CLAVES: [keyof Awaited<ReturnType<typeof loadLang>>["app"], string][] = [
  ["saldoHoy", "panel.hero.haveToday"],
  ["porQueMonto", "panel.liveAnchorEducation.whyQuestion"],
  ["saldoExplica", "panel.saldo.info.balanceBody"],
  ["tusFinanzas", "panel.panorama.title"],
  ["teQueda", "panel.hero.leftNow"],
  ["teQuedo", "panel.hero.leftPast"],
  ["cuantoGastaste", "l2d.amount.question.expense"],
  ["cuantoRecibiste", "l2d.amount.question.income"],
  ["descripcionEj", "l2d.note.example"],
];
const NECESIDADES: [string, string][] = [
  ["esencial", "need.essential"],
  ["prioritaria", "need.priority"],
  ["opcional", "need.optional"],
  ["sin_clasificacion", "need.unclassified"],
];
/** La carpeta de la app de cada idioma de la web (es-419 y pt usan la base, como en la app). */
const LPROJ: Record<Lang, string> = { es: "es", "es-419": "es", "es-AR": "es-AR", "es-ES": "es-ES", en: "en", "en-GB": "en-GB", de: "de", fr: "fr", it: "it", ja: "ja", nl: "nl", pl: "pl", pt: "pt-BR", "pt-BR": "pt-BR", "pt-PT": "pt-PT", "zh-Hans": "zh-Hans" };

describe("los rótulos del lote 4 son los de la app", () => {
  for (const { code } of LANGS) {
    it(code, async () => {
      const t = await loadLang(code);
      for (const [web, app] of CLAVES) expect(t.app[web], `${code} ${String(web)}`).toBe(deLaApp(LPROJ[code], app));
      for (const [web, app] of NECESIDADES) expect(t.app.necesidades[web], `${code} ${web}`).toBe(deLaApp(LPROJ[code], app));
    });
  }
});
