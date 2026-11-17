/**
 * Lote 2 de «Yala web como la app»: la tabla de SF Symbol a Lucide (`src/client/app/simbolos.ts`) cubre todo lo que la
 * app puede guardar como ícono. Las listas se leen del código Swift, no se copian: si la app suma un símbolo al selector,
 * a las categorías de fábrica o a las cuentas, este test lo dice antes de que la web pinte una etiqueta en su lugar.
 */
import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { Car, CreditCard, Landmark, Tag, Utensils } from "lucide-react";
import { COLOR_POR_DEFECTO, SIMBOLOS, colorSeguro, iconoLucide } from "../src/client/app/simbolos";

const swift = (path: string) => readFileSync(new URL(`../../${path}`, import.meta.url), "utf8");
const symbols = (src: string) => [...src.matchAll(/"([a-z0-9]+(?:\.[a-z0-9]+)*)"/g)].map((m) => m[1]!);

/** Los símbolos del selector de la app: el bloque `iconCategories` de `IconColorPickerSheet`. */
function pickerSymbols(): string[] {
  const src = swift("Yala/App/Views/Shared/IconColorPickerSheet.swift");
  const start = src.indexOf("private let iconCategories");
  const end = src.indexOf("private let colorColumns");
  expect(start).toBeGreaterThan(0);
  expect(end).toBeGreaterThan(start);
  return [...new Set(symbols(src.slice(start, end)))];
}

describe("tabla de SF Symbols a Lucide", () => {
  it("cubre los 187 símbolos del selector de la app", () => {
    const picker = pickerSymbols();
    expect(picker.length).toBe(187);
    expect(picker.filter((s) => !SIMBOLOS[s])).toEqual([]);
  });

  it("cubre los íconos de las categorías y subcategorías de fábrica", () => {
    const seed = swift("Yala/Seed/CategorySeed.swift");
    const icons = [...new Set([...seed.matchAll(/iconName: "([^"]+)"/g)].map((m) => m[1]!))];
    expect(icons.length).toBeGreaterThan(40);
    expect(icons.filter((s) => !SIMBOLOS[s])).toEqual([]);
  });

  it("cubre los íconos de cuenta: por tipo y los del editor de tarjeta", () => {
    const helpers = swift("Yala/App/Views/Shared/UIHelpers.swift");
    const byType = helpers.slice(helpers.indexOf("func iconName(for accountType"), helpers.indexOf("func displayIconName"));
    const card = swift("Yala/App/Logic/DisenoTarjeta/CardTemplateCatalog.swift");
    const cardIcons = card.slice(card.indexOf("static let icons"));
    const all = [...new Set([...symbols(byType), ...symbols(cardIcons)])];
    expect(all.length).toBeGreaterThan(20);
    expect(all.filter((s) => !SIMBOLOS[s])).toEqual([]);
  });

  it("cubre los que la app escribe sola en servicios y modelos (ajuste de saldo, «Otros», cuenta de Grupos…)", () => {
    // `iconName: "x"` o `iconName = "x"` en lo que crea filas. Las vistas y los cálculos de informes quedan fuera:
    // pintan símbolos que no se guardan.
    const roots = ["Yala/Services", "Yala/App/ViewModels", "Yala/Models"];
    const found = new Set<string>();
    for (const root of roots) {
      const dir = new URL(`../../${root}/`, import.meta.url);
      for (const f of readdirSync(dir, { recursive: true, encoding: "utf8" }).filter((x) => x.endsWith(".swift"))) {
        for (const m of readFileSync(new URL(f, dir), "utf8").matchAll(/iconName(?::| =) "([a-z0-9]+(?:\.[a-z0-9]+)*)"/g)) found.add(m[1]!);
      }
    }
    expect([...found]).toEqual(expect.arrayContaining(["plusminus", "questionmark.folder", "person.2.circle.fill"])); // control
    expect([...found].filter((s) => !SIMBOLOS[s])).toEqual([]);
  });

  it("un nombre heredado de `Object` («constructor», «tostring») no es un ícono", () => {
    expect(iconoLucide("constructor")).toBe(Tag);
    expect(iconoLucide("tostring")).toBe(Tag);
    expect(iconoLucide("valueof")).toBe(Tag);
  });

  it("traduce los de siempre al dibujo esperado", () => {
    expect(iconoLucide("fork.knife")).toBe(Utensils);
    expect(iconoLucide("car.fill")).toBe(Car);
    expect(iconoLucide("creditcard")).toBe(CreditCard);
    expect(iconoLucide("building.columns.fill")).toBe(Landmark);
  });

  it("sin símbolo, o con uno desconocido, sale la etiqueta de la app; con otro respaldo, ese", () => {
    expect(iconoLucide(null)).toBe(Tag);
    expect(iconoLucide("")).toBe(Tag);
    expect(iconoLucide("no.existe.fill")).toBe(Tag);
    expect(iconoLucide(undefined, "building.columns.fill")).toBe(Landmark);
  });

  it("un símbolo fuera de la tabla prueba sin «.fill» y sin «.circle»", () => {
    expect(iconoLucide("car.circle.fill")).toBe(Car);
    expect(iconoLucide("fork.knife.fill")).toBe(Utensils);
  });

  it("solo pinta colores «#RRGGBB»; lo demás cae al respaldo", () => {
    expect(colorSeguro("#22C55E", COLOR_POR_DEFECTO)).toBe("#22C55E");
    expect(colorSeguro(null, COLOR_POR_DEFECTO)).toBe(COLOR_POR_DEFECTO);
    expect(colorSeguro("red;background:url(x)", COLOR_POR_DEFECTO)).toBe(COLOR_POR_DEFECTO);
    expect(colorSeguro("#FFF", COLOR_POR_DEFECTO)).toBe(COLOR_POR_DEFECTO);
  });
});
