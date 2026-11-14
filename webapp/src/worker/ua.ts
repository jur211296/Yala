/**
 * Navegador y sistema a partir del User-Agent, para la lista de sesiones («Chrome en Mac»). Solo nombres conocidos y
 * cortos: un User-Agent raro sale vacío y el cliente dice «Navegador»; nunca se guarda la cadena entera.
 *
 * El orden importa: Edge y Opera dicen también «Chrome», y Chrome dice también «Safari».
 */
export interface BrowserInfo {
  navegador: string;
  sistema: string;
}

const BROWSERS: [RegExp, string][] = [
  [/\bEdg(e|A|iOS)?\//, "Edge"],
  [/\bOPR\/|\bOpera\b/, "Opera"],
  [/\bSamsungBrowser\//, "Samsung Internet"],
  [/\bFirefox\/|\bFxiOS\//, "Firefox"],
  [/\bCriOS\/|\bChrome\//, "Chrome"],
  [/\bSafari\//, "Safari"],
];

const SYSTEMS: [RegExp, string][] = [
  [/\biPhone\b/, "iPhone"],
  [/\biPad\b/, "iPad"],
  [/\bAndroid\b/, "Android"],
  [/\bWindows\b/, "Windows"],
  [/\bMac OS X\b|\bMacintosh\b/, "Mac"],
  [/\bCrOS\b/, "ChromeOS"],
  [/\bLinux\b/, "Linux"],
];

export function describeBrowser(ua: string | null): BrowserInfo {
  const s = (ua ?? "").slice(0, 512);
  const navegador = BROWSERS.find(([re]) => re.test(s))?.[1] ?? "";
  const sistema = SYSTEMS.find(([re]) => re.test(s))?.[1] ?? "";
  return { navegador, sistema };
}

/** La ciudad que Cloudflare deduce de la IP. En las pruebas y en `wrangler dev` no hay: `null`. */
export function approximateCity(request: Request): string | null {
  const cf = (request as Request & { cf?: { city?: unknown } }).cf;
  const city = typeof cf?.city === "string" ? cf.city.trim() : "";
  return city ? city.slice(0, 60) : null;
}
