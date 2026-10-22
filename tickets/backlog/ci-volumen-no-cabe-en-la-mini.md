---
id: ci-volumen-no-cabe-en-la-mini
status: backlog
priority: very-low
area: platform
created: 2026-09-30
source: PR #309 (CI propio fase 4, r2) — decisión de Jürgen de aparcar el runner
updated: 2026-10-08
---

# El volumen de CI de hoy no cabe en la Mini

El runner local solo compensa si Yala pasa a privado. En público, GitHub es gratis y tarda lo
mismo: 25–38 min allí y 31 en la Mini, medido con `gh run list` el 2026-09-30. Jürgen aparcó el
runner ese día.

Si algún día se pasa a privado, hay un bloqueo antes de cambiar `runs-on`. El plan de casa
(`~/Claude/casa/docs/ci-propio-yala.md`) mide **≈30.500 min de macOS en 30 días**. Eso son unas
17 h de CI al día, en una máquina que Jürgen usa a la vez. Con los candados de `guardia.sh`, el CI
cede y se quedaría horas en cola. Sin ellos, pasa lo del 2026-09-30: la suite, Time Machine y
Spotlight a la vez llevaron la carga a ~37 y tumbaron las sesiones.

## Qué hay que medir y recortar

- Cuántos minutos salen de push a `2.1`, de PR y de la nocturna con UI (122 min por corrida).
- Si el `concurrency` de la fase 2 ya recortó el volumen, y cuánto.
- Qué entra en el CI que no hace falta: diffs de solo documentación o de solo `.github/`.

## Hecho cuando

Hay una cifra de minutos al día que la Mini absorbe sin pasar de la carga que fija
`guardia.sh`, y un plan para bajar hasta ella. Solo tiene sentido si Jürgen decide pasar a
privado.

## Medido en 2.1 (triage 2026-10-08)

- `qa.yml` sigue corriendo en `ubuntu-latest` y `macos-26` de GitHub; el runner de la Mini solo lo usa `ci-sombra.yml`, a mano. No hay decisión de pasar a privado.

Triage 2026-10-08: abierto · low → very-low · solo tiene sentido si Jürgen decide pasar Yala a privado, y no lo ha decidido: tooling lejano.
