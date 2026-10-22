import { readRepoFile } from "./swift";

/**
 * Lo que la app SIEMBRA y cómo lo nombra en cada idioma, leído del repo en vez de copiado:
 * - las categorías y subcategorías por defecto (`Yala/Seed/CategorySeed.swift`), con su naturaleza;
 * - su nombre en cada `.lproj` (`L10n.swift` da la clave, el `.strings` el texto);
 * - el símbolo de cada divisa (`CurrencyCode.symbol` en `Yala/Utils/CurrencyUtils.swift`).
 *
 * Por qué: los casos del banco (las subcategorías que recibe `text.parse`, los nombres del contexto de
 * `chat.answer`) tienen que llevar los nombres que un usuario real tiene en su teléfono. Copiarlos a mano
 * envejece en cuanto alguien renombra una subcategoría en la app.
 */

export type Need = "essential" | "priority" | "optional" | "unclassified";

export interface SeedSubcategory {
  /** Clave del seed (`restaurants`, `salary`…): estable entre idiomas. */
  key: string;
  need: Need;
}

export interface SeedCategory {
  key: string;
  isIncome: boolean;
  subcategories: SeedSubcategory[];
}

const NEED: Record<string, Need> = { esencial: "essential", prioritaria: "priority", opcional: "optional", sin_clasificacion: "unclassified" };

let seedCache: SeedCategory[] | null = null;

/** Las categorías del seed por defecto, en el orden en que la app las crea. */
export function seedCategories(): SeedCategory[] {
  if (seedCache) return seedCache;
  const src = readRepoFile("Yala/Seed/CategorySeed.swift");
  const start = src.indexOf("private func defaultCategorySeedDefinitions()");
  const end = src.indexOf("\n}\n", start);
  if (start < 0 || end < 0) throw new Error("appCatalog: no encuentro defaultCategorySeedDefinitions()");
  const body = src.slice(start, end);
  const blocks = body.split("CategorySeedDefinition(").slice(1);
  const out: SeedCategory[] = [];
  for (const b of blocks) {
    const cat = b.match(/name:\s*L10n\.Category\.(\w+)/);
    const inc = b.match(/isIncome:\s*(true|false)/);
    if (!cat || !inc) throw new Error("appCatalog: bloque de categoría sin nombre o sin isIncome");
    const subs = [...b.matchAll(/L10n\.Subcategory\.(\w+),\s*natureRawValue:\s*"(\w+)"/g)].map((m) => ({ key: m[1], need: NEED[m[2]] ?? "unclassified" }));
    out.push({ key: cat[1], isIncome: inc[1] === "true", subcategories: subs });
  }
  if (out.length < 8) throw new Error(`appCatalog: el seed tiene ${out.length} categorías, ¿cambió el formato?`);
  seedCache = out;
  return out;
}

const l10nCache = new Map<string, string>();

/** `L10n.<Enum>.<prop>` → clave del `.strings`, restringida al prefijo de la clave (`category.` / `subcategory.`). */
function l10nKey(prop: string, prefix: "category." | "subcategory."): string {
  const id = `${prefix}${prop}`;
  const hit = l10nCache.get(id);
  if (hit) return hit;
  const src = readRepoFile("Yala/Utils/L10n.swift");
  const re = new RegExp(`static var ${prop}: String \\{ ls\\("(${prefix.replace(".", "\\.")}[^"]+)"`);
  const m = src.match(re);
  if (!m) throw new Error(`appCatalog: L10n sin ${id}`);
  l10nCache.set(id, m[1]);
  return m[1];
}

const stringsCache = new Map<string, Map<string, string>>();

/** Lee un `Localizable.strings` (`"clave" = "valor";`). */
export function localizable(lproj: string): Map<string, string> {
  const hit = stringsCache.get(lproj);
  if (hit) return hit;
  const src = readRepoFile(`Yala/Resources/${lproj}.lproj/Localizable.strings`);
  const map = new Map<string, string>();
  for (const m of src.matchAll(/^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";/gm)) map.set(m[1], m[2].replace(/\\"/g, '"').replace(/\\n/g, "\n"));
  stringsCache.set(lproj, map);
  return map;
}

/** Variante → `.lproj` de la app: `es-PE` y `es-MX` usan `es-419`; `zh-Hans-CN` usa `zh-Hans`. */
export function lprojFor(locale: string): string {
  const exact = ["es-ES", "es-AR", "en-GB", "pt-BR", "pt-PT", "zh-Hans"];
  for (const e of exact) if (locale === e || locale.startsWith(`${e}-`)) return e;
  const base = locale.split(/[-_]/)[0];
  if (base === "es") return "es-419";
  if (base === "pt") return "pt-BR";
  if (base === "zh") return "zh-Hans";
  return base;
}

function localized(lproj: string, key: string): string {
  const v = localizable(lproj).get(key) ?? localizable("en").get(key);
  if (v === undefined) throw new Error(`appCatalog: «${key}» no está en ${lproj} ni en en`);
  return v;
}

export function categoryName(lproj: string, categoryKey: string): string {
  return localized(lproj, l10nKey(categoryKey, "category."));
}

export function subcategoryName(lproj: string, subKey: string): string {
  return localized(lproj, l10nKey(subKey, "subcategory."));
}

/** La categoría del seed a la que pertenece una subcategoría (`restaurants` → `food`). */
export function seedCategoryOf(subKey: string): SeedCategory {
  const c = seedCategories().find((x) => x.subcategories.some((s) => s.key === subKey));
  if (!c) throw new Error(`appCatalog: «${subKey}» no está en el seed`);
  return c;
}

export function needOf(subKey: string): Need {
  return seedCategoryOf(subKey).subcategories.find((s) => s.key === subKey)!.need;
}

/**
 * Los nombres de subcategoría visibles que `DraftBuilder.fetchVisibleSubcategoryNames` daría a un usuario
 * recién sembrado en ese idioma: gasto (todas las categorías no de ingreso, «Otros» incluida) e ingreso.
 */
export function seedSubcategoryNames(lproj: string): { expense: string[]; income: string[] } {
  const expense: string[] = [];
  const income: string[] = [];
  for (const c of seedCategories()) for (const s of c.subcategories) (c.isIncome ? income : expense).push(subcategoryName(lproj, s.key));
  return { expense, income };
}

let symbolCache: Map<string, string> | null = null;

/** `CurrencyCode(rawValue:)?.symbol` de la app (`PEN` → `S/`, `PLN` → `zł`). Sin entrada, el código. */
export function currencySymbol(code: string): string {
  if (!symbolCache) {
    const src = readRepoFile("Yala/Utils/CurrencyUtils.swift");
    const start = src.indexOf("var symbol: String {");
    const end = src.indexOf("var localizedName", start);
    symbolCache = new Map([...src.slice(start, end).matchAll(/case \.(\w+): return "([^"]*)"/g)].map((m) => [m[1].toUpperCase(), m[2]]));
  }
  return symbolCache.get(code.toUpperCase()) ?? code;
}
