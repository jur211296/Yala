# La web de Yala (yala-app.pe) de Vercel a Cloudflare Workers

Medido el 2026-11-23. **Recomendación: mudar.** La web es estática salvo dos piezas que caben en un Worker, y el
corte se hace con una **ruta de Worker**, así que volver a Vercel es quitar esa ruta: segundos, sin DNS ni TTL.

Resumen visual para decidir: https://claude.ai/artifact/JH5f5cD9iTeRAYWP9vq83d (copia: `resumen.html` en esta carpeta).

## Qué hay hoy

| Punto | Estado | Fuente |
|---|---|---|
| Salida de Astro | Estática + 1 ruta SSR: `/invite` (`prerender = false`) | Verificado: `Web/src/pages/invite.astro` |
| Formularios, API, middleware | No hay | Verificado: `src/pages` sin endpoints ni `<form>`, sin `src/middleware` |
| Lógica en `vercel.json` | 4 cabeceras de seguridad, caché de `/_astro` e `/images`, JSON del AASA, `/privacy_content` → `/privacy`, portada → `/en/` `/de/` `/fr/` `/it/` `/pt/` según Accept-Language si no hay cookie `lang`, y 4 redirecciones por host | Verificado: `Web/vercel.json` |
| Proyecto Vercel `yala-app` | Astro, raíz `Web`, Node 24, Ignored Build Step por diff de `./` | Verificado: API `GET /v9/projects` |
| Rama de producción | `1.0` | Verificado: `link.productionBranch` |
| Previews | Todas las ramas salvo `encargo/**` | Verificado: `vercel.json` `git.deploymentEnabled` |
| Dominios en Vercel | `yala-app.pe`, `yala-pe.com` → yala-app.pe, `yala-app.com.pe` → yala-app.pe, `yala-app.vercel.app` | Verificado: API `GET /v9/projects/…/domains` |
| Variables de entorno | Solo `PUBLIC_DEEP_LINK_SCHEME` en preview (= `yaladev`); producción usa el valor por defecto `yala` | Verificado: API `GET /v10/projects/…/env` |
| Crons | Ninguno | Verificado: `crons.definitions: []` |
| DNS de `yala-app.pe` | Nameservers de Cloudflare (`kyle`, `becky`); el ápex está **proxied** (IPs de Cloudflare) y detrás responde Vercel (`x-vercel-id`) | Verificado: `dig NS`, `dig A`, `curl -I` |
| `www.yala-app.pe` | No existe (sin registro) | Verificado: `dig` |
| `app.yala-app.pe` | NO es de este proyecto: es el Worker `yala-web-production` (Yala web) | Verificado: `webapp/wrangler.toml`, sin `x-vercel-id` |
| Otros Workers en la zona | `mcp`, `mcp-staging`, `panel`, `app` y los del gateway, todos por `custom_domain` en su subdominio | Verificado en el repo (`*/wrangler.toml`); **inferido** que no hay más: el token disponible no lee la cuenta |
| Zona y Workers en el panel de Cloudflare | Sin leer | **Inferido**: el único token local (analytics) devuelve listas vacías y «Authentication error» en zona y Workers |
| `yala-pe.com`, `yala-app.com.pe` | DNS fuera de Cloudflare (GoDaddy y RCP), apuntan a Vercel `216.198.79.1` | Verificado: `dig NS` y `dig A` |
| Ahorro | ≈ USD 2,75 al mes de consumo en Vercel | **Inferido** del análisis de costes del 22-nov («Fase 2»); no se volvió a medir la factura |

## Cómo queda en Workers

- `Web/wrangler.jsonc`: Worker con assets estáticos (`./dist`) y el servidor de Astro (`@astrojs/cloudflare` 12.6.13,
  la última para Astro 5). Dos entornos: `yala-landing-preview` en workers.dev para verificar, y
  `yala-landing-production` con la ruta `yala-app.pe/*`.
- `Web/src/worker.ts`: la redirección de idioma de la portada (misma regex y mismo 307 que Vercel) y las cabeceras de
  seguridad en lo que pinta el Worker. Solo `/` pasa por el Worker antes que lo estático (`run_worker_first`).
- `Web/public/_headers` y `_redirects`: el resto de `vercel.json`.
- `Web/astro.config.mjs`: **adaptador doble**. Si el build corre en Vercel (`VERCEL=1`) usa el de Vercel; si no, el de
  Cloudflare. Así la misma rama sigue desplegando en Vercel mientras dura la mudanza y la vuelta atrás no pide rebuild.
- Las redirecciones por host (`yala-pe.com`, `yala-app.com.pe`) **se quedan en Vercel**: su DNS no está en Cloudflare.

### Comprobado en local (`wrangler dev`, contra producción, 2026-11-23)

Igual que producción: `/`, `/privacy/`, `/terms/`, `/support/`, `/en/`, `/de/terms/`, la 404 (mismo título), el
sitemap, `robots.txt`, `llms.txt`, el AASA (`application/json`), `/invite` con parámetros y con un `%` suelto, el deep
link `yala://invite?…`, la portada con `en`, `de`, `fr`, `it`, `pt`, `es-PE` (se queda) y con cookie `lang`, las cuatro
cabeceras de seguridad y la caché inmutable de `/_astro`. `wrangler deploy --dry-run` pasa en los dos entornos
(891 KiB, 353 ficheros). El build con `VERCEL=1` sigue saliendo con el adaptador de Vercel.

**Una diferencia, a propósito:** `/privacy` (sin barra) hoy da 200 y en Workers da 307 a `/privacy/`, que es la URL
canónica y la del sitemap. La app enlaza `yala-app.pe/privacy` y `/terms` sin barra: el navegador sigue el 307 y llega.

## Qué hay que llevar a 1.0

Producción se publica desde `1.0`, y `2.3` trae cambios de la web que aún no salen (por ejemplo `/funciones`). El
Worker de producción tiene que compilarse con el contenido de `1.0`. Antes del corte hace falta **llevar a 1.0 solo
el commit de configuración** de esta mudanza (cherry-pick en un PR a `1.0`, CI verde), sin el resto de `2.3`.
**No se hace sin el OK de Jürgen.**

## Plan de corte

1. **Jürgen:** OK al cherry-pick del commit de configuración a `1.0` (PR a `1.0`).
2. **Dan, prueba:** desde `1.0` con ese commit, `cd Web && npm ci && npm run build && npx wrangler deploy` (sin
   `--env`). Sale en `https://yala-landing-preview.<subdominio>.workers.dev`.
3. **Verificación contra producción** (la tabla de arriba): portada en los 6 idiomas, `/privacy_content`, `/invite`
   con un enlace real de grupo, AASA, 404, cabeceras. En el iPhone: abrir un enlace de invitación con la app
   instalada (el universal link solo se prueba de verdad tras el corte, porque Apple lee el AASA de `yala-app.pe`).
4. **Jürgen:** OK al corte.
5. **Dan, corte:** `npx wrangler deploy --env production`. Crea la ruta `yala-app.pe/*` y el tráfico pasa al Worker en
   segundos. **No se toca el DNS**: el registro proxied del ápex se queda como está.
6. **Comprobar en caliente:** `curl -sI https://yala-app.pe/` deja de traer `x-vercel-id`; SSL sigue siendo el de
   Cloudflare (ya lo es hoy); `yala-pe.com/terms` sigue dando 308 a `yala-app.pe/terms` (Vercel); el AASA responde
   `application/json`; un enlace de invitación abre la app.

## Vuelta atrás

- **En segundos:** en Cloudflare → Workers → `yala-landing-production` → Settings → Domains & Routes, borrar la ruta
  `yala-app.pe/*` (o `npx wrangler delete --env production`). El tráfico vuelve al origen, que sigue siendo Vercel.
- **DNS de hoy, por si alguien lo hubiera tocado:** el ápex `yala-app.pe` resuelve a Cloudflare (proxied) y su origen es
  Vercel. El valor exacto del registro no se pudo leer (sin acceso a la zona); por el patrón de Vercel es un
  `A yala-app.pe 216.198.79.1` proxied o un `CNAME` a `cname.vercel-dns.com` — **Dan lo copia del panel aquí antes del
  corte.** Los otros dos dominios: `yala-pe.com A 216.198.79.1` (GoDaddy) y `yala-app.com.pe A 216.198.79.1` (RCP).
- **Lo que NO se apaga en Vercel hasta una semana estable:** el proyecto `yala-app`, su dominio `yala-app.pe` y sus
  despliegues de `1.0`. Y nunca mientras `yala-pe.com` y `yala-app.com.pe` apunten ahí: son sus redirecciones.
- Tras la semana, para dejar de pagar builds: apagar los despliegues por git del proyecto (`git.deploymentEnabled`
  a `false`) y conservar los dos dominios viejos con su redirección.

## Previews después de la mudanza

Vercel deja de ser la vista previa útil de la web en cuanto el Worker sirve producción. En Cloudflare, un preview es
`npx wrangler deploy` (entorno por defecto, en workers.dev) o `npx wrangler versions upload`, que da una URL por
versión sin tocar producción. No hay previews automáticos por rama hasta que alguien conecte Workers Builds al repo:
eso queda fuera de este encargo.
