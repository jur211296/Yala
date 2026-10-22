---
esfuerzo: high
---
# CI propio · fases 4–7 con Jürgen al lado (guiado)

## Contexto
Las fases 1–3 ya están mergeadas (PR #307 + memoria PR #308). Jürgen (2026-09-30 ~10:51 Lima) dijo: **no encadenar Cola A**; quiere ayudarte ahora con las fases 4–7 y pidió **una sesión que lo guíe**.

Plan canónico: `~/Claude/casa/docs/ci-propio-yala.md` (ADR-053). Encargo original: `encargos/lanzados/2026-09-30-ci-propio-y-auto-merge.md` (y el pendiente hermano de casa `~/Claude/casa/encargos/pendientes/2026-09-29-cierre-con-auto-merge.md`).

Numeración de este encargo (la del plan de Yala / Frank):

| Fase | Qué | Quién hace qué |
|---|---|---|
| 4 | Runner en sombra (usuario macOS `ci`, LaunchAgent, DerivedData/trabajo en `/Volumes/ExtDev`; mientras el repo sea público **solo** `workflow_dispatch`) | Jürgen: crea usuario `ci` + token de registro (no por chat). Tú: montas runner, validas. |
| 5 | Yala a privado + CI al runner | Jürgen: GitHub Pro, confirma si cobran minutos de runner propio, cambia visibilidad. Tú: `runs-on` al runner. |
| 6 | Auto-merge (`allow_auto_merge`, `delete_branch_on_merge`, ruleset en `2.1` con `tests`+`coverage-index` obligatorios y **bypass admin**, vigilante de PRs atascados) | Tú, **después** de que el encargo de casa `2026-09-29-cierre-con-auto-merge` esté mergeado (si aún no, avísale a Frank/Jürgen y no inventes el `/cerrar-total` global). |
| (casa) | `/cerrar-total` en modo auto-merge + playbook de bots | Es de **casa**, no de este repo. No lo reescribas aquí. |

## Qué se pide
1. **Guía a Jürgen paso a paso** con AskUserQuestion / instrucciones concretas (comandos de Terminal, pantallas de GitHub, qué pegar dónde). Una fase validada antes de la siguiente.
2. Empieza por la **fase 4** (runner en sombra). No saltes a Pro/privado hasta que el runner valide con `workflow_dispatch`.
3. Token de registro del runner: **nunca** lo pidas por chat ni lo pegues en el transcript. Indícale dónde generarlo en GitHub y que lo pegue solo en el prompt local / Keychain / fichero que uses tú en la Mini sin eco.
4. Cuando una fase necesite algo solo suyo (contraseña de admin, Pro, cambiar visibilidad), **para y pregúntale** con opciones claras; no asumas.
5. Si el encargo de casa aún no está hecho y bloquea la fase 6, dilo en el parte y deja la fase 6 lista pero no mergees auto-merge a medias.
6. Documenta tiempos medidos del runner vs GitHub en el PR.

## Qué NO hay que tocar
- Cola A, adaptativo, tickets de producto.
- Visibilidad del repo / GitHub Pro / usuario macOS: solo Jürgen los ejecuta; tú guías.
- El skill global `/cerrar-total` y `docs/playbook-grokbots.md` de casa (encargo de casa).
- No `shutdown all` / `erase all` / `killall Simulator` de sims de otras colas.

## Cómo se sabe que está bien
- Fase 4: varias corridas `workflow_dispatch` con el mismo resultado que GitHub y tiempos medidos; sims arrancan en usuario `ci` sin primer plano.
- Fase 5: primer PR privado pasa entero en el runner (solo si Jürgen ya hizo Pro + privado).
- Fase 6: PR bueno mergea solo; uno roto no mergea y avisa; uno con conflicto lo detecta el vigilante — o queda explícito en el parte qué falta del encargo de casa.

## Paso 0 — decisiones (resueltas por Frank; Jürgen al lado, discutibles en el PR)

Medido al arrancar (2026-09-30): no existe el usuario `ci`; Yala es público, sin runners propios,
`allow_auto_merge` y `delete_branch_on_merge` en `false`; aprobación de PRs de fork en
`first_time_contributors`; la Mini tiene **solo Xcode 27.0 + runtime iOS 27.0**, y GitHub corre
`latest-stable` con **iOS 26.5**; 16 GB de RAM; ExtDev es USB, `Owners: Disabled`, 118 GB libres;
sin autologin; el encargo de casa `2026-09-29-cierre-con-auto-merge` sigue en `pendientes/`.

1. **La sombra es un workflow aparte (`ci-sombra.yml`), no un input de `qa.yml`.** Un
   `workflow_dispatch` de `qa.yml` es la nocturna (UI incluida) y lo cuenta `nocturna-vigilante`;
   mezclar la sombra ahí ensucia esa señal. La duplicación de pasos dura hasta la fase 5, que
   cambia `runs-on` de `qa.yml` y borra la sombra.
2. **LaunchDaemon con `UserName=ci`, no LaunchAgent.** El encargo dice LaunchAgent, pero un agente
   solo vive con `ci` con sesión iniciada, y tras un reinicio nadie la inicia. Si los simuladores
   no arrancan en el daemon, se cae al LaunchAgent + cambio rápido de usuario, y se dice.
3. **Una sola ejecución de sudo por Jürgen**: `qa/scripts/ci-runner/instalar.sh`. El token de
   registro lo pide el script con `gh` y lo pasa por entorno; nunca se imprime ni pasa por el
   chat. La contraseña de `ci` se genera y se guarda en el llavero de Jürgen en el mismo gesto.
4. **Todo en el disco interno, en el home de `ci`** (corregido tras medir). El plan era trabajo y
   DerivedData en ExtDev, pero macOS no deja a un LaunchDaemon entrar en un volumen externo
   (`Operation not permitted`) y el runner se quedaba offline. Abrirlo pide Acceso total al disco
   para un binario que se auto-actualiza. Coste: ~12 GB de los 34 libres. DerivedData fuera del
   checkout, para que sobreviva al `git clean` (build incremental, como el gate local).
5. **La sombra usa el Xcode 27 de la Mini, no un 26.x.** Es el que compila el gate local y el que
   sube a la App Store. «Mismo resultado» se mide como mismos veredictos y mismo conteo de tests;
   lo que cambie por iOS 27 se apunta como diferencia, no como fallo del runner.
6. **Asumido:** la sombra no espera a `sim-lock.sh` (otro usuario, otro juego de devices); antes de
   cada dispatch se mira que no haya Cola A viva. Enganchar el runner al lock es de la fase 5.
7. **Fase 6 bloqueada** por el encargo de casa: se deja escrito qué falta y no se activa nada.
8. **Decidido por Jürgen (AskUserQuestion):** `DevToolsSecurity -enable` + `ci` en `_developer`;
   aprobación de PRs de fork endurecida a `all_external_contributors` (hecho por API).
