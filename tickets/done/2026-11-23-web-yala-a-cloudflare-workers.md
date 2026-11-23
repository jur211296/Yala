---
id: 2026-11-23-web-yala-a-cloudflare-workers
status: done
priority: medium
area: "web, infra"
created: 2026-11-23
updated: 2026-11-23
source: "Jürgen vía Dan, fase 2 del análisis de costes de Vercel (22-nov)"
---

# La web de yala-app.pe, lista para pasar de Vercel a Cloudflare Workers

Preparar la mudanza de la web pública (Astro, `Web/`) a un Worker con assets estáticos en la cuenta de Cloudflare de
Yala, con plan de corte y de vuelta atrás. Sin desplegar ni tocar DNS: el despliegue es de Dan y el corte, con OK de
Jürgen.

## Hecho cuando

La configuración está en `2.3`, compila, pasa `wrangler dev` con el mismo comportamiento que producción y el
`wrangler deploy --dry-run` de los dos entornos; la guía con lo verificado, el corte y la vuelta atrás está en
`docs/infra/web-a-cloudflare/`.

## Resolución (2026-11-23)

Hecho. Recomendación: mudar. Guía: `docs/infra/web-a-cloudflare/README.md`; resumen visual:
https://claude.ai/artifact/JH5f5cD9iTeRAYWP9vq83d.

Lo que sigue no es de este ticket: llevar el commit de configuración a `1.0` (OK de Jürgen), el despliegue de prueba
en workers.dev (Dan) y el corte con `wrangler deploy --env production` (OK de Jürgen).
