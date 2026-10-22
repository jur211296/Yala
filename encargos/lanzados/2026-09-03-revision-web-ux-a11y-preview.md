---
modelo: fable
esfuerzo: high
---

# Revisar la web de Yala (UX, engagement, a11y) e implementar mejoras en preview

## Contexto
Jürgen pidió (2026-09-03) que analices la web de Yala como usuario, mires best practices y páginas de alto engagement en apps financieras similares, encuentres oportunidades, asegures criterios de accesibilidad bien documentados, implementes los cambios que consideres razonables y dejes todo revisable en otra rama o preview — no en producción. Al cerrar, un documento formal de reporte.

La web está en `Web/` (Astro 5 + Tailwind + i18n es/en/de/fr/it/pt, deploy Vercel). Producción es `yala-app.pe`. Hay contexto reciente en `Web/REDISENO-WEB-2.0.md` y `Web/CAMBIOS-LEGALES-2.0-DRAFT.md`; úsalos, no los trates como dogma.

`marketing/` es de Lola (App Store / capturas): no la toques. Esta sesión cierra con PR desde worktree, como siempre.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key viven en fichero local, no en git; no las escribas en el repo) cuando (1) te bloquees esperando a Jürgen, (2) dejes listo PR / preview / artifact, o (3) falle build / CI. No avises al cerrar (`/cerrar`).

## Qué se pide
1. Recorre la web como usuario (home, pricing, Yala IA, Grupos, soporte, legales, invite si aplica) en al menos un idioma principal y un segundo.
2. Investiga best practices y páginas de alto engagement de apps de finanzas personales comparables (YNAB, Fintonic, Wallet, Spendee, Monarch, etc.). Hecho ≠ hipótesis: cita fuentes o ejemplos concretos.
3. Lista oportunidades priorizadas (impacto × esfuerzo).
4. Documenta criterios de accesibilidad aplicables (WCAG 2.2 AA como piso) y audita la web contra ellos.
5. Implementa los cambios que consideres claros y de alto valor dentro de `Web/` (copy, estructura, a11y, performance percibida, CTAs, etc.).
6. Despliega en rama/preview de Vercel — nunca a producción ni al dominio `yala-app.pe`.
7. Deja un documento formal de reporte en el repo (p. ej. bajo `Web/` o `docs/`) con: hallazgos, qué se implementó (con enlaces a preview/PR), qué queda pendiente y por qué.

## Qué NO hay que tocar
- Producción / dominio vivo `yala-app.pe` (ni promover preview a prod).
- `marketing/` (Lola).
- App iOS (`Yala/`), gateway, CloudKit, secrets, `.env*`.
- No inventes métricas ni cites secretos.
- No cambies el sistema i18n de rutas sin necesidad; si tocas copy, mantén las 6 locales o documenta el gap.

## Como se sabe que está bien
- PR abierto desde worktree con los cambios de `Web/` + el reporte formal.
- Preview de Vercel viva (URL en el PR / reporte); build verde.
- El reporte lista hallazgos, implementado y pendientes con criterios a11y documentados.
- Frank recibe ping de webhook al dejar listo PR/preview (no al `/cerrar`).
