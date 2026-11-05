/**
 * `fetch` de los tests: undici 7 en HTTP/1, con conexiones en paralelo (card «Los goldens del gateway hacen en serie
 * las llamadas que el Worker lanza en paralelo», 2026-11-04).
 *
 * El `fetch` de Node 26 (undici 8.5 dentro) encola los POST que van a un mismo host: medido el 2026-11-04 contra
 * staging, 20 POST en `Promise.all` tardaban ~2,0 s, lo mismo que 20 en serie (~0,1 s cada uno). Darle al `fetch`
 * de Node un dispatcher HTTP/1 no lo arregla: lo ignora. Con el `fetch` de undici 7 y `allowH2: false`, los mismos
 * 20 tardan ~0,34 s, lo que tarda uno con su primera conexión, y los seriales no cambian. En el Worker real
 * (Cloudflare) nada de esto aplica: es el arnés de test en Node.
 *
 * Los tests que hacen `vi.stubGlobal("fetch", …)` siguen igual: `unstubAllGlobals` devuelve este.
 */
import { Agent, fetch as undiciFetch } from "undici";

const agent = new Agent({ allowH2: false });

type UndiciInit = NonNullable<Parameters<typeof undiciFetch>[1]>;

globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
  // Un `Request` de Node no es uno de undici 7: se pasa como URL + init para que no lo lea como texto.
  if (typeof input === "object" && !(input instanceof URL)) {
    const req = input as Request;
    const hasBody = req.method !== "GET" && req.method !== "HEAD" && req.body !== null;
    return (await undiciFetch(req.url, {
      method: req.method,
      headers: req.headers,
      ...(hasBody ? { body: req.body, duplex: "half" } : {}),
      redirect: req.redirect,
      signal: req.signal,
      ...(init as UndiciInit),
      dispatcher: agent,
    } as UndiciInit)) as unknown as Response;
  }
  return (await undiciFetch(input, { ...(init as UndiciInit), dispatcher: agent })) as unknown as Response;
}) as typeof fetch;
