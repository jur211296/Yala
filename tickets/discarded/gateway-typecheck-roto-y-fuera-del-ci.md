---
id: gateway-typecheck-roto-y-fuera-del-ci
status: discarded
priority: low
area: "gateway, ci, tooling"
created: 2026-09-07
updated: 2026-10-07
source: hallazgo lateral de groups-budget (2026-09-07)
---

# El `typecheck` del gateway falla, y nadie se entera porque el CI no lo corre

Why: Discarded 2026-10-07, con OK de Jürgen (2026-10-07, 21:50 Lima). El typecheck sale verde (`275822811`, 2026-10-07). Lo que queda, que el CI lo corra y bloquee, vive en `ci-no-corre-la-suite-del-gateway`.

## Qué pasa

`npm run typecheck` en `gateway/` termina con **3 errores de TypeScript**. Medido el 2026-09-07 en
el worktree de `groups-budget`, sobre ficheros que esa sesión **no tocó** (`git status` los daba
idénticos a HEAD), así que no son suyos:

```
test/groups.consent.test.ts(129,48): error TS2345: Argument of type '{ "Content-Type": string; }'
  is not assignable to parameter of type '{ Authorization: string; "Content-Type": string; }'.
  Property 'Authorization' is missing …
test/wrangler.forceupdate.test.ts(26,30): error TS2307: Cannot find module 'node:fs' …
test/wrangler.forceupdate.test.ts(29,67): error TS2339: Property 'url' does not exist on type 'ImportMeta'.
```

## Por qué no salta nadie

Dos causas, y las dos son del repo, no del entorno de quien lo corrió:

1. **`@types/node` no está declarado.** `gateway/package.json` lista cuatro devDependencies
   (`@cloudflare/workers-types`, `typescript`, `vitest`, `wrangler`) y ninguna trae los tipos de
   Node, así que `node:fs` e `import.meta.url` no resuelven en NINGUNA máquina — no es un
   `npm install` a medias de nadie.
2. **El CI no ejecuta `typecheck`.** `grep -n "typecheck" .github/workflows/*.yml` da cero
   resultados. El comando existe, está bien cableado como `pretypecheck` → `sync:manifest`, y no lo
   invoca ningún job.

⇒ el error puede llevar semanas ahí. `npm test` sí pasa (253 tests), así que nada lo delata.

## Por qué importa poco hoy y puede importar mañana

Hoy no rompe nada: los tres errores están en ficheros de TEST y `vitest` transpila sin comprobar
tipos, así que la suite corre igual y el Worker despliega igual (`deploy` no depende de
`typecheck`). Lo que se pierde es la red: un error de tipos en `src/` —donde sí vive el código que
se despliega— tampoco lo vería nadie, porque el comando que lo cazaría ya está en rojo y su rojo se
ha vuelto ruido de fondo.

## Qué habría que hacer

1. Añadir `@types/node` a devDependencies (y `"types": ["node"]` en el `tsconfig` si hace falta).
2. Arreglar el header de `groups.consent.test.ts:129` (le falta `Authorization`).
3. Meter `npm run typecheck` en el job del gateway del CI, **como bloqueante**: un typecheck que no
   bloquea es un typecheck que vuelve a ponerse rojo.

## Cómo se reproduce

```
cd gateway && npm install && npm run typecheck
```

## Nota de proceso

Sale de la sesión de `groups-budget`, que lo encontró al validar su propio cambio del manifest. Se
comprobó que **no era suyo** antes de abrir el ticket: los dos ficheros con error estaban sin
modificar respecto a HEAD, y la causa (`@types/node` ausente en `package.json`) es estructural del
repo, no del entorno de esa sesión.

## Re-medido el 2026-09-10: ahora son CINCO, y el punto 3 de arriba presupone algo que no existe

`wrangler-prod-onboarding-choice-percent-drift` añadió a `test/config.test.ts` un guard que lee
`wrangler.toml`, copiando el patrón de `wrangler.forceupdate.test.ts` —el precedente aceptado del
repo—. Con él llegan **dos errores más de la misma familia exacta**, no de una nueva:

```
test/config.test.ts(1,30):   error TS2307: Cannot find module 'node:fs'
test/config.test.ts(143,67): error TS2339: Property 'url' does not exist on type 'ImportMeta'
```

Total: **5 errores** (los 3 de este ticket + 2). Se dejaron a propósito en vez de arreglarlos de
paso: la salida limpia toca la política de tipos del proyecto —meter `"node"` en `types` mete todas
las APIs de Node en el ámbito del **Worker**, donde enmascararía un error real de `src/`— y eso es
esta decisión, no un arreglo de un test. Una alternativa más acotada, para cuando se retome: un
`tsconfig` separado para `test/` con `types: ["node"]`, que deja `src/` estricto.

**Corrección al punto 3:** dice «meter `npm run typecheck` en el job del gateway del CI». No hay job
del gateway — no existe ninguno, ni para `typecheck` ni para `npm test`. Crearlo es
`ci-no-corre-la-suite-del-gateway`, así que este ticket **depende** de aquél y no puede cerrarse
antes.


## 2026-10-07: el typecheck ya sale verde; queda el CI

Lo arregló la sesión `gpt-4-1-nano-shuts-down-on-october-23`, que necesitaba `npm run typecheck` verde.
Ese día eran **6** errores, todos de esta familia: los 5 de arriba, con la línea de `config.test.ts` en
otra coordenada, más el de `groups.consent.test.ts`. Se tomó la vía acotada que proponía este ticket, sin
`@types/node`:

- `tsconfig.json` ya solo incluye `src/`, con los tipos de Workers. Una sonda con `process` en `src/` da
  error, como debe.
- `tsconfig.test.json` extiende el anterior para `test/` y `bench/`, y añade `test/node-shim.d.ts`: los
  tipos mínimos de Node que usan los tests y el banco.
- `npm run typecheck` corre los dos.
- `groups.consent.test.ts`: el parámetro `headers` del helper `rpc` pasa a `Record<string, string>`.

**Sigue abierto el punto 3** (que el CI lo corra y bloquee). Depende de `ci-no-corre-la-suite-del-gateway`.
