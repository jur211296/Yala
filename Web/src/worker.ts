// Entrada del Worker de la web (yala-app.pe) en Cloudflare. Envuelve el handler del adaptador de Astro y hace
// lo que en Vercel resolvía `vercel.json` y un fichero estático no puede:
//   1. La portada `/` manda a `/en/`, `/de/`… según el PRIMER idioma de Accept-Language, salvo que haya cookie
//      `lang`. Es la misma regex que vercel.json, una por idioma, y el mismo 307.
//   2. Las cabeceras de seguridad también en lo que pinta el Worker (`/invite`, la 404). Lo estático las recibe
//      de `public/_headers`.
// Solo `/` pasa por el Worker antes que los assets (`run_worker_first` en wrangler.jsonc); el resto de lo
// estático lo sirve Cloudflare directamente y no cuenta como petición al Worker.
import type { SSRManifest } from 'astro';
import { App } from 'astro/app';
import { handle } from '@astrojs/cloudflare/handler';

const IDIOMAS_DE_PORTADA = ['en', 'de', 'fr', 'it', 'pt'] as const;

const CABECERAS_DE_SEGURIDAD: Record<string, string> = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'X-Frame-Options': 'SAMEORIGIN',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=()',
};

/** Idioma al que redirige la portada, o null si se queda en español. Exportada para el test. */
export function idiomaDePortada(acceptLanguage: string | null, cookie: string | null): string | null {
  if (!acceptLanguage) return null;
  if (cookie && /(?:^|;\s*)lang=/.test(cookie)) return null;
  for (const idioma of IDIOMAS_DE_PORTADA) {
    if (new RegExp(`^${idioma}(?:-[A-Za-z]+)?(?:[,;].*)?$`).test(acceptLanguage)) return idioma;
  }
  return null;
}

function conCabecerasDeSeguridad(response: Response): Response {
  const copia = new Response(response.body, response);
  for (const [clave, valor] of Object.entries(CABECERAS_DE_SEGURIDAD)) copia.headers.set(clave, valor);
  return copia;
}

type Contexto = { waitUntil(promise: Promise<unknown>): void };
type Env = { ASSETS: { fetch: (req: Request | string) => Promise<Response> }; [key: string]: unknown };

export function createExports(manifest: SSRManifest) {
  const app = new App(manifest);
  return {
    default: {
      async fetch(request: Request, env: Env, context: Contexto): Promise<Response> {
        const url = new URL(request.url);
        if (url.pathname === '/') {
          const idioma = idiomaDePortada(request.headers.get('accept-language'), request.headers.get('cookie'));
          if (idioma) {
            return conCabecerasDeSeguridad(
              new Response(null, { status: 307, headers: { Location: `${url.origin}/${idioma}/` } }),
            );
          }
        }
        // El handler tipa request y context con @cloudflare/workers-types, que este tsconfig no carga.
        const response = await handle(manifest, app, request as never, env, context as never);
        return conCabecerasDeSeguridad(response);
      },
    },
  };
}
