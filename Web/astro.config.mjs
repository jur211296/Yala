// @ts-check
import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';
import vercel from '@astrojs/vercel';
import cloudflare from '@astrojs/cloudflare';

// Mudanza a Cloudflare Workers (docs/infra/web-a-cloudflare/): mientras dure, la misma rama tiene que poder
// desplegarse en los dos sitios. Vercel define `VERCEL=1` en sus builds y ahí sigue su adaptador; en cualquier
// otro sitio (local, `wrangler`) sale el Worker. Así la vuelta atrás es quitar la ruta del Worker, sin rebuild.
const enVercel = Boolean(process.env.VERCEL);

// https://astro.build/config
export default defineConfig({
  site: 'https://yala-app.pe',
  adapter: enVercel
    ? vercel()
    : cloudflare({
        // Envuelve el handler de Astro: redirección por idioma de la portada y cabeceras de seguridad,
        // lo que en Vercel hacía `vercel.json`.
        workerEntryPoint: { path: 'src/worker.ts' },
        // La web no usa `astro:assets`; sin esto el adaptador pediría el binding IMAGES.
        imageService: 'passthrough',
      }),
  integrations: [tailwind(), sitemap()]
});
