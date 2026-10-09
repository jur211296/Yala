# El CI no ejecuta ningún test del gateway, ni los que impiden un deploy que inutiliza la app

## Contexto
Card del tablero `tablero-el-ci-no-ejecuta-ningun-test-del-gateway-y15g` (lista para lanzar → en curso, prioridad high, vence 2026-10-12). Ticket: `tickets/backlog/ci-no-corre-la-suite-del-gateway.md` (triage medium 2026-10-08, PR #403).

Hoy un cambio en `gateway/` no corre vitest en el CI del PR: ni el guard de `MIN_SUPPORTED_BUILD` (un deploy mal puesto inutilizaría todas las instalaciones), ni los percents de rollout de producción, ni el 401 que lee el cliente iOS, ni el fan-out de avisos a los admins. Tampoco `deploy:production` los corre. El job `mcp` de `.github/workflows/qa.yml` es el molde.

Encargo escrito en `~/Claude/tmp-frank/ci-no-corre-la-suite-del-gateway.md`. Sesión anterior: banco Claude PR #407 en auto-merge a 2.1 (no depende de ella).

## Que se pide
1. Añadir un job `gateway` en `.github/workflows/qa.yml` con la forma del job `mcp` (Ubuntu, Node 22, `npm ci` y `npm test` con `working-directory: gateway`). Dispararlo cuando el diff toque `gateway/**`, o en cada push si sale igual de barato que `mcp`. Hoy `gateway/*` solo está en la allowlist que salta la suite iOS.
2. Comprobar `gateway/package.json`: `test` = `vitest run`, `pretest` = `sync:manifest`. Los tests que hablan con staging (`USER_A_PASS`, `GROUPS_ENC_KEY`, `PUSH_ROLE_JWT`) deben saltarse solos sin secretos, no fallar.
3. Dejar cubiertos al menos: `gateway/test/wrangler.forceupdate.test.ts`, `gateway/test/config.test.ts`, `gateway/test/groups.attest401.test.ts`, `gateway/test/push.fanout.unit.test.ts`, `gateway/test/manifest.sync.test.ts`.
4. Control rojo en una rama de prueba: cambiar un percent de `[env.production.vars]` o el `MIN_SUPPORTED_BUILD` del `wrangler.toml` pone el job en rojo; luego revertir.
5. Opcional: si el ruleset de `2.1` debe exigir el check nuevo (ADR-054 de casa), déjalo propuesto — eso es acceso de Jürgen, no lo fuerces.
6. Sin simulador iOS: este encargo es solo CI/gateway. No abras sims. Limpia DerivedData/cachés de worktrees retirados al lanzar y al cerrar si toca.
7. Gate tras el CI del PR anterior: arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR #407 (banco Claude) u otro PR en cola sigue en CI. Si sigue, espera a que entre y rebasa una sola vez. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue.
8. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-el-ci-no-ejecuta-ningun-test-del-gateway-y15g` a «done» asignada a frank si no queda nada para Jürgen, o a «in qa» asignada a jurgen si hace falta que él meta el check en el ruleset, con `tablero mover` / `tablero asignar --agente frank`.

## Que NO hay que tocar
- Suite iOS / macOS del CI (salvo la allowlist si hace falta para no pagar minutos de más).
- `deploy:production` más allá de documentar que sigue sin tests si no entra en el alcance mínimo.
- marketing/, Web/, app Swift.
- Secretos de staging: no los inventes ni los pidas; los tests online deben skippear.

## Como se sabe que esta bien
- Un PR que solo toca `gateway/` muestra el check `gateway` con ~250 tests offline en verde y los de staging en `skipped`.
- El control rojo del paso 4 funciona y queda revertido.
- Un PR que no toca `gateway/` no paga minutos de macOS por este job.
- PR a 2.1 en auto-merge, card movida, Mini limpia (sin sims de esta sesión).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (2026-10-08, este worktree, `env -i` sin secretos): `npm test` en `gateway/` da
**449 verdes, 84 skipped, 4 ficheros en rojo** en 2 s. Los 4 rojos son los goldens de staging
(`account.goldens`, `groups.goldens`, `push.fanout`, `sync.goldens`): su `beforeAll` **lanza** «Falta
USER_A_PASS» en vez de saltarse. Así el job saldría rojo siempre. `npm run typecheck` sale verde.

**D1 · ¿El job corre siempre o solo si el diff toca `gateway/**`?** → Siempre, como `mcp`.
Por qué: es Ubuntu y ~1 min, no paga macOS; y un check filtrado por ruta no se puede exigir en el ruleset
(se queda «pendiente» en los PR que no tocan `gateway/`). Alternativa descartada: depender del job `changes`,
que añade acoplamiento y bloquea D6.

**D2 · ¿Cómo se saltan los goldens de staging sin secretos?** → Puerta común `test/staging.ts`: si no hay
**ninguna** credencial (`USER_A/B/C_PASS`, `GROUPS_ENC_KEY`, `PUSH_ROLE_JWT`), sus `describe` van con
`skipIf`. Con alguna puesta y otra no, siguen lanzando como hoy.
Por qué: un entorno a medias en la Mac es un error de quien lanza y merece el rojo; un entorno vacío es el CI.
Alternativa descartada: `exclude` en `vitest.config.ts` (desaparecen del informe en vez de salir `skipped`, y
es una lista más que mantener).

**D3 · ¿Typecheck también?** → Sí, `npm run typecheck` antes de `npm test`, como el molde `mcp`.
Por qué: hoy está verde y cuesta segundos; sin él un tipo roto en `src/` solo lo ve el deploy.

**D4 · ¿Se toca la allowlist de `changes`?** → No. `gateway/*` sigue saltando la suite iOS, que es lo correcto;
`encargos/*` y `qa/coverage-index.json` son del ticket `encargos-markdown-triggers-the-whole-ios-suite`.

**D5 · ¿`deploy:production` corre tests?** → No se toca (fuera de alcance por el encargo). Queda documentado en
el PR como hueco abierto.

**D6 · ¿Exigir `gateway` en el ruleset de `2.1`?** → Recomendado, pero es acceso de Jürgen: se propone en el PR
y la card va a «in qa» asignada a él.

**D7 · ¿Dónde el control rojo?** → Local primero (mutar `MIN_SUPPORTED_BUILD` y un percent, ver rojo) y luego
en CI con un PR borrador desde una rama `prueba/…` que se cierra sin mergear y se borra.
Por qué: el historial del PR real queda limpio y el rojo se ve en GitHub, que es lo que se pide.
