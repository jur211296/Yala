Yala
# Preparar la mudanza de la web de Yala (Astro) de Vercel a Cloudflare Workers, con plan de corte y de vuelta atrás
---
toca: Web/wrangler.jsonc,Web/astro.config.mjs,Web/package.json,Web/package-lock.json,Web/public/_headers,Web/public/_redirects,docs/infra/web-a-cloudflare/,tickets/backlog/2026-11-23-web-yala-a-cloudflare-workers.md,tickets/done/2026-11-23-web-yala-a-cloudflare-workers.md
esfuerzo: medium
cierre: cierra-sola
---

Pedido de Jürgen (23-nov, vía Dan, fase 2 de costes de Vercel): mudar yala-app, la web Astro en `Web/`, a Cloudflare Workers con assets estáticos, en la cuenta de Cloudflare de Yala (admin@yala-app.pe), que es la única donde va la web (confirmado por Jürgen el 23-nov). No uses la cuenta personal de Cloudflare: en la Mini, wrangler está logueado en la personal, así que no la uses para nada de esta web. El análisis está en la Mini, en `~/Claude/entregas/2026-11-22-vercel-costes-analisis/vercel-a-20.html`, sección «Fase 2». Estima 1 día de trabajo y unos USD 2,75 al mes menos de consumo en Vercel.

## Qué se pide
1. **Primero verifica el estado vigente; no lo supongas.** Revisa el repo (`Web/astro.config.mjs`, `Web/vercel.json`, adaptador, salida `static` o `server`, endpoints, middleware, formularios, redirecciones y headers). Revisa también Vercel con el conector o la CLI, solo lectura: el proyecto yala-app, sus dominios (yala-app.pe, www y app.yala-app.pe), qué rama es producción (se cree que 1.0), las previews de `encargo/*`, las variables de entorno, las funciones o rutas no estáticas, los crons y el consumo del último ciclo. Y revisa Cloudflare, solo lectura: la zona de yala-app.pe, los registros DNS actuales y a dónde apuntan, y los Workers que ya existen (por ejemplo yala-mcp-production en mcp.yala-app.pe) para no chocar con ellos.
2. Marca **cada punto como «verificado»** (con la fuente: archivo, comando o respuesta de la API) **o «inferido»** (con el motivo).
3. Si la web tiene partes no estáticas (formularios, API, SSR o el login de app.yala-app.pe), di cómo quedarían en Workers (Worker con assets más rutas, o dejarlas en Vercel) y cuánto cambia el ahorro. **Si con lo verificado no conviene mudar o el ahorro no da, dilo arriba de todo y no prepares la mudanza.**
4. Si conviene, deja en un PR contra 2.3 la configuración lista para desplegar: `Web/wrangler.jsonc` con assets, rutas y nombre del Worker, y los ajustes de Astro, headers y redirecciones equivalentes a `vercel.json`. Prueba el build en local y con `wrangler dev` o `wrangler deploy --dry-run`. **No despliegues nada ni toques el DNS de producción**: el despliegue lo hace Dan, y el corte del DNS necesita el OK de Jürgen. No borres ni cambies nada en Vercel.
5. Si la producción sigue la rama 1.0, indica qué hay que llevar a 1.0 (cherry-pick o merge) antes del corte y no lo hagas sin OK.

## Plan de corte y de vuelta atrás
- **Corte:** pasos ordenados. Primero Dan despliega el Worker en un subdominio de prueba o en workers.dev y se hace la verificación visual y de rutas contra producción. Después, con el OK de Jürgen, se cambia el DNS o las rutas del dominio, se ajusta el TTL antes y se comprueban SSL, www y redirecciones.
- **Vuelta atrás:** cómo volver a Vercel en minutos (registros DNS exactos de hoy, guardados en la guía), y qué no se apaga en Vercel hasta que pase una semana estable.
- Qué pasa con las previews de ramas después de la mudanza.

## Cómo entregar
- Un artifact visual de Claude (nunca Markdown ni PDF) para decidir rápido: recomendación en una línea, tabla de verificado o inferido, ahorro esperado, riesgos, plan de corte y plan de vuelta atrás. Déjalo también en `docs/infra/web-a-cloudflare/` con el link.
- Un PR sin firma de IA contra 2.3, con el auto merge activado. No cierres hasta ver el PR dentro de 2.3. Si hay un conflicto o el CI falla, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- En «Qué salió»: la recomendación, el link del artifact, el link del PR y lo exacto que Dan tiene que desplegar.
- No inventes credenciales ni accesos. Si una consulta de solo lectura a Vercel o Cloudflare falla por falta de acceso, márcala como «inferido» y sigue. Si es imprescindible, `BLOQUEANTE:`.
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión».
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones (resueltas en semi, sin consulta: ninguna es vital)

1. **¿Conviene mudar?** Sí. Lo no estático es poco y cabe en un Worker: `/invite` (SSR, `prerender = false`) y la redirección por idioma de la portada. Ni formularios, ni API, ni crons (verificado: `src/pages`, `crons.definitions: []`). `app.yala-app.pe` NO es de este proyecto: ya es el Worker `yala-web-production` (`webapp/wrangler.toml`).
2. **Adaptador:** doble, elegido por `process.env.VERCEL`. Si se cambia a secas, el merge de 2.3 a 1.0 rompería el despliegue de Vercel antes del corte y la vuelta atrás exigiría un rebuild.
3. **Versiones:** `@astrojs/cloudflare@12.6.13` (la última para Astro 5). No se sube Astro: fuera de alcance.
4. **Corte por ruta de Worker, no por DNS:** la zona yala-app.pe ya está en Cloudflare con el registro proxied hacia Vercel. Una ruta `yala-app.pe/*` intercepta antes del origen; volver atrás es quitar la ruta (segundos, sin TTL).
5. **Dominios viejos** (`yala-pe.com`, `yala-app.com.pe`): su DNS no está en Cloudflare. Se quedan redirigiendo desde Vercel; no se mudan.
6. **Barra final:** `auto-trailing-slash` (por defecto en Workers). `/privacy` pasa a redirigir a `/privacy/`, que es la canónica y la del sitemap.
7. **Nombres:** `yala-landing-preview` (workers.dev, para verificar) y `yala-landing-production` (con la ruta). No chocan con `yala-web-*`, `yala-mcp-*`, `yala-panel`, `yala-gateway-*`.
8. **Cloudflare, solo lectura:** el único token disponible (analytics) no lee zona ni Workers. Lo de Cloudflare queda «inferido» por `dig`, cabeceras HTTP y los `wrangler.toml` del repo. No se pide otro: no es imprescindible para preparar la config.
