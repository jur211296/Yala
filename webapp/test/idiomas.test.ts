/**
 * Los 16 idiomas de la web (lote 2b).
 *
 * 1. Cada idioma carga y trae TODAS las claves del español, sin textos vacíos.
 * 2. Ninguno usa un nombre de sitio retirado por la decisión 51 de 2.3. Las listas son las de
 *    `YalaTests/DosNombresDeSitioTests.swift` (red 2 en los 16, red 3 con la expresión del español). Si esa prueba
 *    cambia sus listas, cámbialas aquí también.
 * 3. Un idioma que no es español no deja frases en español sin traducir (una palabra suelta puede coincidir; los textos
 *    que no cambian entre idiomas se nombran).
 * 4. El navegador elige bien: `es-PE` → es, `pt` → pt-BR, `en-AU` → en-GB, `zh-TW` → zh-Hans, `ko` → nada.
 */
import { describe, expect, it } from "vitest";
import { LANGS, loadLang, matchLang, type Lang, type Texts } from "../src/client/i18n";
import { ES } from "../src/client/i18n/es";

/** Todos los textos de un diccionario, con las funciones llamadas con valores de muestra. */
function strings(node: unknown, path = ""): [string, string][] {
  if (typeof node === "string") return [[path, node]];
  if (typeof node === "function") {
    const fn = node as (...a: unknown[]) => unknown;
    const out: [string, string][] = [];
    for (const args of [[1, "X"], [2, "X"], [7, "X"], ["X", "Y"]]) {
      let v: unknown;
      try {
        v = fn(...args);
      } catch {
        continue;
      }
      if (typeof v === "string") out.push([`${path}(${args.join(",")})`, v]);
    }
    return out;
  }
  if (node && typeof node === "object") {
    return Object.entries(node as Record<string, unknown>).flatMap(([k, v]) => strings(v, path ? `${path}.${k}` : k));
  }
  return [];
}

function keys(node: unknown, path = ""): string[] {
  if (node && typeof node === "object" && typeof node !== "function") {
    return Object.entries(node as Record<string, unknown>).flatMap(([k, v]) => keys(v, path ? `${path}.${k}` : k));
  }
  return [path];
}

const RETIRED: Record<string, string[]> = {
  es: ["iCloud privado", "Tu cuenta en la nube", "Activar la nube", "Migrar a la nube"],
  en: ["Private iCloud", "Your cloud account", "Turn on the cloud", "Move to the cloud"],
  de: ["Privates iCloud", "Dein Cloud-Konto", "Cloud aktivieren", "In die Cloud wechseln"],
  fr: ["iCloud privé", "Ton compte cloud", "Activer le cloud", "Passer au cloud"],
  it: ["iCloud privato", "Il tuo account nel cloud", "Attiva il cloud", "Passa al cloud"],
  ja: ["プライベート iCloud", "クラウドアカウント", "クラウドを有効化", "クラウドへ移行"],
  nl: ["Privé-iCloud", "Je cloud-account", "Cloud inschakelen", "Overstappen naar de cloud"],
  pl: ["Prywatny iCloud", "Twoje konto w chmurze", "Włącz chmurę", "Przenieś do chmury"],
  "pt-BR": ["iCloud privado", "Sua conta na nuvem", "Ativar a nuvem", "Migrar para a nuvem"],
  "pt-PT": ["iCloud privado", "A tua conta na nuvem", "Ativar a nuvem", "Migrar para a nuvem"],
  "zh-Hans": ["私有 iCloud", "你的云端账户", "启用云端", "迁移到云端"],
};

function retiredListOf(l: Lang): string[] {
  if (l.startsWith("es")) return RETIRED.es!;
  if (l.startsWith("en")) return RETIRED.en!;
  if (l === "pt") return RETIRED["pt-BR"]!;
  return RETIRED[l]!;
}

/** La red 3 de `DosNombresDeSitioTests`, tal cual. */
const SPANISH_FORBIDDEN =
  /iCloud privado|modo privado|modo nube|nube de Yala|cuenta (en|de) la nube|cuenta Yala en la nube|\bmigr(ar|aría)\b|activar la nube|(sigue|sigues|seguir|seguirás) (usando )?(en )?la nube|desvincular tu cuenta/i;

/**
 * Textos que pueden quedar iguales que en español en cualquier idioma: nombres propios, siglas, símbolos y los textos
 * de prueba. Se comparan por su ruta.
 */
const SAME_AS_SPANISH = new Set([
  "app.beta",
  "app.ia",
  "app.origen.applePay",
  "app.origen.siri",
  "app.origen.web",
  "app.descripcionPh",
  "app.panel",
  "app.temaLiquid",
]);

const ALL: Lang[] = LANGS.map((l) => l.code);

describe("los 16 idiomas de Yala web", () => {
  it("son los 16 de la app", () => {
    expect(ALL.sort()).toEqual(["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl", "pt", "pt-BR", "pt-PT", "zh-Hans"]);
  });

  it.each(ALL)("%s trae todas las claves del español y ningún texto vacío", async (l) => {
    const tx: Texts = await loadLang(l);
    expect(keys(tx).sort()).toEqual(keys(ES).sort());
    const empty = strings(tx).filter(([, v]) => v.trim() === "");
    expect(empty).toEqual([]);
  });

  it.each(ALL)("%s no usa los nombres de sitio retirados por la decisión 51", async (l) => {
    const tx = await loadLang(l);
    const old = retiredListOf(l).map((s) => s.toLocaleLowerCase());
    const offenders = strings(tx).filter(([, v]) => old.some((o) => v.toLocaleLowerCase().includes(o)));
    expect(offenders).toEqual([]);
    if (l.startsWith("es")) expect(strings(tx).filter(([, v]) => SPANISH_FORBIDDEN.test(v))).toEqual([]);
  });

  it.each(ALL.filter((l) => !l.startsWith("es")))("%s no deja textos en español sin traducir", async (l) => {
    const tx = await loadLang(l);
    const es = new Map(strings(ES));
    const same = strings(tx).filter(([k, v]) => {
      const base = k.replace(/\(.*\)$/, "");
      // Una palabra suelta puede coincidir de verdad («Nota», «Saldo», «Total»): solo se marcan frases.
      return !SAME_AS_SPANISH.has(base) && es.get(k) === v && /[a-záéíóúñ]{4,}/i.test(v) && /\s/.test(v.trim());
    });
    expect(same).toEqual([]);
  });

  it("el navegador elige el idioma como iOS", () => {
    expect(matchLang("es-PE")).toBe("es");
    expect(matchLang("es-419")).toBe("es-419");
    expect(matchLang("es-AR")).toBe("es-AR");
    expect(matchLang("es-ES")).toBe("es-ES");
    expect(matchLang("es-MX")).toBe("es");
    expect(matchLang("en-US")).toBe("en");
    expect(matchLang("en-AU")).toBe("en-GB");
    expect(matchLang("en_GB")).toBe("en-GB");
    expect(matchLang("pt")).toBe("pt-BR");
    expect(matchLang("pt-PT")).toBe("pt-PT");
    expect(matchLang("zh-TW")).toBe("zh-Hans");
    expect(matchLang("zh-Hans-CN")).toBe("zh-Hans");
    expect(matchLang("de-AT")).toBe("de");
    expect(matchLang("ko-KR")).toBeNull();
  });

  it("las variantes cambian de verdad algo de su base", async () => {
    const [es, ar, esp, en, gb] = await Promise.all([loadLang("es"), loadLang("es-AR"), loadLang("es-ES"), loadLang("en"), loadLang("en-GB")]);
    const diff = (a: Texts, b: Texts) => {
      const mb = new Map(strings(b));
      return strings(a).filter(([k, v]) => mb.get(k) !== v).length;
    };
    expect(diff(ar, es)).toBeGreaterThan(10);
    expect(diff(esp, es)).toBeGreaterThan(5);
    expect(diff(gb, en)).toBeGreaterThan(0);
  });
});
