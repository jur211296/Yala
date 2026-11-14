/**
 * Idiomas de Yala web: los 16 de la app (lote 2b; antes, español e inglés, decisión D12). El idioma es el que la persona
 * eligió en Configurar (se guarda en este navegador) o, si no eligió, el primero de su navegador que Yala tenga; si no
 * tiene ninguno, español.
 *
 * Un fichero por idioma en `i18n/`. El español es la base y su forma (`Texts`) es el contrato: si a un idioma le falta una
 * clave, no compila. Como en la app, tres variantes son diferencias sobre su base (es-AR y es-ES sobre el español, en-GB
 * sobre el inglés), y es-419 y pt usan la base de su idioma (en la app son iguales a es y a pt-BR).
 *
 * `loadTexts()` se espera ANTES de importar la página (`main.tsx`): cada pantalla lee `texts()` al cargarse. Así solo
 * viaja el idioma que se usa.
 */
import { ES, type Texts } from "./i18n/es";

export type { Texts };

export type Lang =
  | "es"
  | "es-419"
  | "es-AR"
  | "es-ES"
  | "en"
  | "en-GB"
  | "de"
  | "fr"
  | "it"
  | "ja"
  | "nl"
  | "pl"
  | "pt"
  | "pt-BR"
  | "pt-PT"
  | "zh-Hans";

/** Los 16, con su nombre en su propio idioma (así se reconoce aunque la página esté en otro). */
export const LANGS: { code: Lang; name: string }[] = [
  { code: "es", name: "Español" },
  { code: "es-419", name: "Español (Latinoamérica)" },
  { code: "es-AR", name: "Español (Argentina)" },
  { code: "es-ES", name: "Español (España)" },
  { code: "en", name: "English" },
  { code: "en-GB", name: "English (UK)" },
  { code: "de", name: "Deutsch" },
  { code: "fr", name: "Français" },
  { code: "it", name: "Italiano" },
  { code: "ja", name: "日本語" },
  { code: "nl", name: "Nederlands" },
  { code: "pl", name: "Polski" },
  { code: "pt", name: "Português" },
  { code: "pt-BR", name: "Português (Brasil)" },
  { code: "pt-PT", name: "Português (Portugal)" },
  { code: "zh-Hans", name: "简体中文" },
];

const CODES = new Set<string>(LANGS.map((l) => l.code));

/** Un objeto parcial de `Texts`: lo que una variante cambia de su base. */
export type TextsPatch<T = Texts> = {
  [K in keyof T]?: T[K] extends (...args: never[]) => unknown ? T[K] : T[K] extends object ? TextsPatch<T[K]> : T[K];
};

/** La base con la variante encima, clave a clave. */
export function applyPatch<T>(base: T, patch: TextsPatch<T>): T {
  const out = { ...base } as Record<string, unknown>;
  for (const [k, v] of Object.entries(patch as Record<string, unknown>)) {
    const b = out[k];
    out[k] = v && typeof v === "object" && b && typeof b === "object" ? applyPatch(b, v as TextsPatch<typeof b>) : v;
  }
  return out as T;
}

const LOADERS: Record<Lang, () => Promise<Texts>> = {
  es: async () => ES,
  "es-419": async () => ES,
  "es-AR": async () => applyPatch(ES, (await import("./i18n/es-AR")).ES_AR),
  "es-ES": async () => applyPatch(ES, (await import("./i18n/es-ES")).ES_ES),
  en: async () => (await import("./i18n/en")).EN,
  "en-GB": async () => {
    const [{ EN }, { EN_GB }] = await Promise.all([import("./i18n/en"), import("./i18n/en-GB")]);
    return applyPatch(EN, EN_GB);
  },
  de: async () => (await import("./i18n/de")).DE,
  fr: async () => (await import("./i18n/fr")).FR,
  it: async () => (await import("./i18n/it")).IT,
  ja: async () => (await import("./i18n/ja")).JA,
  nl: async () => (await import("./i18n/nl")).NL,
  pl: async () => (await import("./i18n/pl")).PL,
  pt: async () => (await import("./i18n/pt-BR")).PT_BR,
  "pt-BR": async () => (await import("./i18n/pt-BR")).PT_BR,
  "pt-PT": async () => (await import("./i18n/pt-PT")).PT_PT,
  "zh-Hans": async () => (await import("./i18n/zh-Hans")).ZH_HANS,
};

const LANG_KEY = "yala-web-idioma";
/** Países donde iOS cae en el inglés británico si la app lo tiene. */
const EN_GB_REGIONS = new Set(["GB", "IE", "AU", "NZ", "IN", "ZA", "SG", "HK"]);

/** El almacén del navegador, si lo hay (también compila con los tipos del Worker, donde lo leen las pruebas). */
function storage(): { getItem(k: string): string | null; setItem(k: string, v: string): void; removeItem(k: string): void } | undefined {
  return (globalThis as { localStorage?: ReturnType<typeof storage> }).localStorage;
}

let current: Texts = ES;
let currentLang: Lang = "es";

/** El idioma elegido en Configurar, si lo hay. En una ventana privada o con el almacenamiento bloqueado, ninguno. */
export function chosenLang(): Lang | null {
  try {
    const v = storage()?.getItem(LANG_KEY) ?? null;
    return v && CODES.has(v) ? (v as Lang) : null;
  } catch {
    return null;
  }
}

/** Guarda el idioma elegido (`null`: el del navegador). La página se vuelve a cargar con él. */
export function setChosenLang(v: Lang | null): void {
  try {
    if (v) storage()?.setItem(LANG_KEY, v);
    else storage()?.removeItem(LANG_KEY);
  } catch {
    // Sin almacenamiento, se queda el del navegador.
  }
}

/** El idioma de Yala para una etiqueta del navegador (`es-PE`, `pt`, `zh-TW`…), o `null` si Yala no lo tiene. */
export function matchLang(tag: string): Lang | null {
  const parts = tag.trim().replace(/_/g, "-").split("-");
  const base = (parts[0] ?? "").toLowerCase();
  const region = parts.find((p, i) => i > 0 && /^([A-Za-z]{2}|\d{3})$/.test(p))?.toUpperCase() ?? "";
  switch (base) {
    case "es":
      if (region === "ES") return "es-ES";
      if (region === "AR") return "es-AR";
      if (region === "419") return "es-419";
      return "es";
    case "en":
      return EN_GB_REGIONS.has(region) ? "en-GB" : "en";
    case "pt":
      return region === "PT" || region === "AO" || region === "MZ" ? "pt-PT" : "pt-BR";
    case "zh":
      return "zh-Hans";
    case "de":
    case "fr":
    case "it":
    case "ja":
    case "nl":
    case "pl":
      return base;
    default:
      return null;
  }
}

function detect(): Lang {
  const chosen = chosenLang();
  if (chosen) return chosen;
  const tags = navigator.languages?.length ? navigator.languages : [navigator.language || "es"];
  for (const tag of tags) {
    const m = matchLang(tag);
    if (m) return m;
  }
  return "es";
}

/** Los textos de un idioma (lo usan `loadTexts` y las pruebas). */
export function loadLang(l: Lang): Promise<Texts> {
  return LOADERS[l]();
}

/** Carga los textos del idioma de esta visita. Si el fichero no llega (red), se queda en español. */
export async function loadTexts(): Promise<void> {
  const l = detect();
  try {
    current = await loadLang(l);
    currentLang = l;
  } catch {
    current = ES;
    currentLang = "es";
  }
}

export function lang(): Lang {
  return currentLang;
}

export function texts(): Texts {
  return current;
}

/** Para formatear importes y fechas con `Intl`. El español base sigue en `es-PE`: soles con «S/», como en la app. */
export function locale(): string {
  switch (currentLang) {
    case "es":
      return "es-PE";
    case "en":
      return "en-US";
    case "de":
      return "de-DE";
    case "fr":
      return "fr-FR";
    case "it":
      return "it-IT";
    case "ja":
      return "ja-JP";
    case "nl":
      return "nl-NL";
    case "pl":
      return "pl-PL";
    case "pt":
      return "pt-BR";
    case "zh-Hans":
      return "zh-Hans-CN";
    default:
      return currentLang;
  }
}

/** La política de privacidad en el idioma más cercano que tiene la web de Yala (español, inglés, alemán, francés, italiano y portugués). */
export function privacyUrl(): string {
  const base = currentLang.slice(0, 2);
  if (base === "es") return "https://yala-app.pe/privacy";
  if (base === "de" || base === "fr" || base === "it" || base === "pt") return `https://yala-app.pe/${base}/privacy`;
  return "https://yala-app.pe/en/privacy";
}

/** El código de idioma que entiende Turnstile para el desafío anti-bots. */
export function turnstileLang(): string {
  if (currentLang === "zh-Hans") return "zh-cn";
  if (currentLang.startsWith("pt")) return "pt-br";
  return currentLang.slice(0, 2);
}
