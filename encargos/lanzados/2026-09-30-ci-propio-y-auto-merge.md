---
esfuerzo: high
---
# CI propio en la Mini, Yala privado y auto-merge — sin que la sesión espere al CI

> **PRIORIDAD (Jürgen, 29-sep):** este encargo va **antes que cualquier otro ticket de Yala**.
> La sesión de Yala que esté en curso termina; después no se lanza nada más de Yala hasta cerrar
> las fases 1 a 3. Las fases 4 a 7 dependen de pasos de Jürgen y del encargo de casa
> `2026-09-29-cierre-con-auto-merge`, así que pueden ir en sesiones posteriores.

## Por qué

Jürgen decidió el 29-sep (ADR-053 de casa, plan en `~/Claude/casa/docs/ci-propio-yala.md`) que lo
que más le frena es **esperar al CI**, no la máquina. Medido:

- CI de un PR ~27 min de mediana. `Build for testing` 11-17 min en GitHub y **3 min** en la Mini.
- Los pasos `Unit tests … advisory` (qa.yml, con `continue-on-error`) suman 11-22 min y la sesión los espera.
- `qa.yml` no declara `concurrency`: 145 de 239 ramas de PR tuvieron más de un run en 30 días.
- **El aviso del CI a Grok está caído desde el 16-sep**: la routine responde `HTTP 400` y los avisos
  se apilan en el issue #183 (291 comentarios). Los secretos `GROK_WEBHOOK_URL` y
  `GROK_WEBHOOK_SENDER_KEY` son del 9-sep. Un 401/403 sería la clave; un 400 apunta al cuerpo.
- `docs/ESTADO.md` mide 3.944 líneas en 136 secciones de sesión, con 75 «Lo que espera de Jürgen».
  El hook de arranque vuelca sus primeras ~45 líneas en cada sesión; solo 12 de 521 transcripts en
  14 días lo leyeron a propósito, y siempre la cabecera.

## Qué decidió Jürgen

- **La sesión no espera al CI**: push, PR con el parte, `gh pr merge --auto --merge` y cierre.
  Para **todo** Yala. Checks obligatorios: `tests` y `coverage-index`, sin exigir rama al día.
- **Avisos:** a Jürgen, solo «Implementado: …» al cerrar la sesión y, **al momento**, un rojo que
  bloquea (PR sin mergear, `2.1` roto, PR atascado). Los rojos *advisory* van solo al bot, que crea
  la tarjeta y encola el arreglo **si lo ve necesario**, detrás de la sesión en curso.
- **`docs/ESTADO.md` se retira.** Los avisos fijos de su cabecera van a `CLAUDE.md` o a
  `.claude/rules/`. Lo que espera de Jürgen va a tarjetas asignadas a `jurgen` (kanban del panel o
  tickets con dueño Jürgen, lo que ya use el repo). La crónica queda en el cuerpo de cada PR. El
  número de build de TestFlight no se escribe en ningún sitio: Jürgen lo mira al subir.
- **Runner propio en la Mini**, en un usuario de macOS aparte `ci`, y **Yala pasa a privado** con GitHub Pro.

## Fases (cada una se valida antes de la siguiente)

1. **Arreglar el aviso del CI a Grok.** Diagnosticar el `HTTP 400` (`.github/actions/avisar/action.yml`)
   y comprobar con un aviso de prueba que llega a la routine. Cerrar el issue #183 solo cuando llegue.
2. **`concurrency` solo para `pull_request`.** Forma segura:
   `group: ${{ github.event_name == 'pull_request' && format('qa-pr-{0}', github.event.pull_request.number) || format('qa-{0}', github.run_id) }}`,
   `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`. Reescribir el comentario de
   qa.yml ~L439-443, que se apoya en «este workflow no declara concurrency». Validar: `actionlint`;
   dos pushes seguidos a un PR (el primero se cancela y no sale `aviso`); un push a `2.1` con un
   `workflow_dispatch` corriendo (no se cancela ninguno). `nocturna-vigilante.yml` cuenta runs sin
   filtrar por conclusión (L106-108, L131-133): con el grupo por `run_id` no le afecta, compruébalo.
3. **Retirar `ESTADO.md`.** `/abrir` pasa a leer los últimos PRs mergeados (`gh pr list --state merged`,
   con su «Necesita de ti»), `tickets/in-progress/` y lo asignado a Jürgen. Migrar los «Lo que espera de
   Jürgen» que sigan abiertos; los resueltos se quedan en git. Decisión escrita en `docs/DECISIONS.md`.
   Validar: un `/abrir` en seco da el mismo briefing útil que hoy, sin el fichero. `/cerrar`, `/idea`,
   `/backlog`, `/higiene`, `CLAUDE.md` y `README.md` dejan de nombrarlo.
4. **Runner en sombra.** Necesita a Jürgen: crear el usuario `ci` y el token de registro (no por chat).
   Runner como LaunchAgent del usuario `ci`, DerivedData y trabajo en `/Volumes/ExtDev`. **Mientras
   el repo sea público, solo por `workflow_dispatch`**: con `pull_request` correría el código de
   cualquier PR en la Mini. Validar: que los simuladores arrancan en ese usuario sin estar en primer
   plano, y varias corridas con el mismo resultado que en GitHub, con tiempos medidos.
5. **Privado.** Jürgen contrata Pro, confirma si GitHub cobra por minuto de runner propio y cambia la
   visibilidad. Entonces `runs-on` pasa al runner, también los jobs de Linux si caben. Validar: el
   primer PR en privado pasa entero en el runner.
6. **Auto-merge.** `allow_auto_merge`, `delete_branch_on_merge`, ruleset en `2.1` con `tests` y
   `coverage-index` obligatorios y **bypass del admin** (las sesiones pushean como `jur211296`, admin;
   sin bypass se bloquean los push directos). Un job saltado cuenta como pasado, pero un check que no
   llega a dispararse (conflicto, YAML roto, id renombrado) cuelga el PR: hace falta un vigilante de
   PRs con auto-merge atascados que avise. Validar: un PR correcto que mergea solo, uno roto a
   propósito que no mergea y avisa, y uno con conflicto que el vigilante detecta.

## Qué NO tocar

- El `/cerrar-total` global y el playbook de los bots: los cambia el encargo de casa
  `2026-09-29-cierre-con-auto-merge`. La fase 6 espera a que ese esté mergeado.
- La visibilidad del repo, GitHub Pro y el usuario de macOS: son de Jürgen.

## Cómo se sabe que está bien

Fases 1-3 mergeadas y validadas como dicen arriba. Las 4-7, cada una con su validación escrita en el PR.

Orden de Jürgen 2026-09-30: esta sesión es la siguiente obligatoria; no encadenar Cola A ni adaptativo hasta cerrar fases 1–3.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Alcance de esta sesión: fases 1 a 3. Las 4-7 esperan a Jürgen y al encargo de casa.

**Hechos medidos antes de decidir (30-sep).** El `HTTP 400` no es la clave ni el cuerpo: el
webhook contesta `{"success":false,"error":"Automation 439b5c38-… is disabled"}` (log del ping
36625092126). La routine «Avisos CI Yala» está **desactivada en Cursor**. El ping diario pasa de
verde (16-sep) a rojo (17-sep) y sigue así. En Chrome no hay sesión de Cursor.

**D1 · ¿Cómo se arregla el aviso?** → Jürgen reactiva la automation en el panel de Cursor; yo no
entro en su cuenta. Mientras, la action nombra el motivo `disabled` en vez de «respuesta
inesperada», para que la próxima vez el diagnóstico salga del propio log.
Por qué: la causa está en Cursor, no en el repo. Alternativa descartada: reapuntar los secretos a la
routine de Frank, que está viva. El playbook lo prohíbe: mezclar los dos circuitos deja al bot sin
poder distinguir un push de una sesión parada.

**D2 · ¿Se toca qué avisa `avisar-grok-push-principal.yml`?** → No. Al reactivar, cada push a
`2.1` (merges incluidos) vuelve a despertar al bot, como antes del 16-sep. ADR-053 dice que un merge
verde no avisa a nadie, pero rediseñar qué avisa es parte de las fases 6-7 y del encargo de casa.
Se anota como hallazgo. Alternativa descartada: filtrar ya los merges. Cambiaría el circuito antes
de que exista el auto-merge que lo justifica.

**D3 · Fase 2, ¿qué forma y cómo se valida?** → La forma literal del encargo, a nivel de workflow.
Validación: `actionlint`; dos pushes seguidos al PR de este encargo (el primero cancelado, sin job
`aviso`); tras el merge, un `workflow_dispatch` sobre `2.1` a la vez que el run del push del merge
(no se cancela ninguno). `nocturna-vigilante.yml` cuenta runs de `schedule` y `workflow_dispatch`,
que caen en un grupo por `run_id` y nunca se cancelan: no le afecta.
Alternativa descartada: `concurrency` por job. Deja el job `aviso` fuera del grupo y avisaría de un
run sustituido.

**D4 · ¿Adónde va «lo que espera de Jürgen»?** → Al kanban (`tablero`, proyecto `Yala`,
`--asignado jurgen`), que el repo ya usa para Yala. Una tarjeta por decisión o tarea abierta. Los
device-QA cuyo ticket ya está en `tickets/qa/` no se duplican uno a uno: el ticket ya es su
registro. Van en **una** tarjeta paraguas que apunta a `tickets/qa/`.
Por qué: cincuenta tarjetas que repiten cincuenta tickets son dos superficies para lo mismo.
Alternativa descartada: un campo `owner:` nuevo en los tickets. El schema de `docs/TICKETS.md` no
lo tiene y nadie lo leería.

**D5 · ¿Qué lee `/abrir` en lugar de `ESTADO.md`?** → Los últimos PRs mergeados a `2.1` con su
«Necesita de ti» (`gh pr list --state merged`), los commits directos a `2.1` sin PR,
`tickets/in-progress/` y las tarjetas de Yala asignadas a `jurgen`.
Por qué: son las tres fuentes que ya se escriben solas al trabajar. Alternativa descartada: que
`/cerrar` escriba un resumen en otro fichero. Es el mismo fichero compartido con otro nombre, y
chocaría igual con el auto-merge.

**D6 · ¿Qué pasa con el fichero?** → Se borra (`git rm`). Git conserva la historia. Los avisos fijos
de su cabecera que sigan siendo hechos del entorno pasan a `CLAUDE.md`. Lo que es de un ticket va a
ese ticket.
Alternativa descartada: dejar un stub de tres líneas. El hook de arranque lo seguiría volcando como
fichero de estado, y en su ausencia ya dice «si es deliberado, debería estar escrito». Lo estará, en
`CLAUDE.md`.

**D7 · ¿Dónde queda la crónica de una sesión en el árbol principal, sin PR?** → En el cuerpo del
commit a `2.1`, y `/abrir` la lee con `git log`.
Por qué: ADR-053 manda la crónica al cuerpo del PR, y sin PR su equivalente es el commit.

**D8 · ¿Qué referencias se tocan?** → Las que dan instrucciones hoy: `/abrir`, `/cerrar`, `/idea`,
`/backlog`, `/higiene`, `CLAUDE.md`, `README.md` (con `indice_readme.py`) y `docs/HANDOFF.md`. No se
tocan: los encargos lanzados, los tickets cerrados y las memorias, que son registro;
`scripts/indice_readme.py` y `qa/scripts/ci-allowlist-test.sh`, donde `docs/ESTADO.md` es un
candidato genérico o una ruta de ejemplo; `marketing/`, que es de Lola; y `~/.claude`, que es de casa.

**D9 · ¿Hace falta ADR nuevo?** → No en casa: es ADR-053. Sí una entrada en `docs/DECISIONS.md` de
Yala, como pide el encargo, que diga dónde vive ahora cada cosa.

**D10 · Entrega.** → Worktree, así que va por rama y PR. Sesión en bypass: mergeo yo con el CI en
verde. `/gate` antes del commit, aunque no haya Swift. La fase 1 no se cierra hasta que un ping
llegue a la routine. El issue #183 se cierra solo entonces.
