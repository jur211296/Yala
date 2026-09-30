---
MODO AUTÓNOMO HASTA TERMINAR: sí
---
# Alinear CLAUDE.md y frank.md con ADR-054 (auto-merge / no esperar CI)

## Contexto
El 30-sep entró ADR-054 (casa): Yala tiene `allow_auto_merge`; `/cerrar-total` modo cola hace `gh pr merge --auto --merge` y cierra **sin esperar** al CI. GitHub mergea cuando pasan `tests` + `coverage-index`.

Hoy (mismo día) la sesión wipe-data se quedó en «Esperando al CI» porque `CLAUDE.md` y `.claude/agents/frank.md` aún dicen el tren viejo: PR → CI en verde → merge. El skill `~/.claude/skills/cerrar-total` §3 bis ya está bien; fallan las instructions del repo.

Fuente de verdad: `~/Claude/casa/decisions/0054-el-auto-merge-de-yala-entra-ya-con-el-ci-de-github-e.md` y `~/.claude/skills/cerrar-total/SKILL.md` §3 bis. No reimplementes el skill; solo alinea el texto del repo Yala.

## Qué se pide
1. En `CLAUDE.md` (sección merge / MODO AUTÓNOMO / Control de Ejecución): sustituye «CI en verde → merge» / «PR → CI → merge» por el flujo ADR-054: tras abrir el PR, `gh pr merge <n> --auto --merge`, verificar cola (`autoMergeRequest`), seguir `/cerrar-total` en **modo cola** (no esperar checks; no borrar rama remota; parte en el cuerpo del PR).
2. En `.claude/agents/frank.md`: mismo alineamiento (hoy dice «mergeas tú, con el CI en verde» y «`/cerrar-total`: gate, commit, PR, CI, merge»).
3. Busca otras menciones en `.claude/` de Yala (rules, agent-memory de frank) que manden esperar CI antes de mergear en autónomo; corrige o anota feedback corto si es memoria de hábito, sin inventar ADRs nuevos.
4. Gate mínimo de docs (sin suite iOS si no tocas `Yala/`). Commit + PR + **modo cola** auto-merge + `/cerrar-total`.

## Qué NO hay que tocar
Código de producto bajo `Yala/`. Workflows de CI. Ruleset de GitHub. El skill global `cerrar-total` (ya correcto). No reactivar runner propio ni pasar el repo a privado.

## Cómo se sabe que está bien
- Un grep en `CLAUDE.md` + `frank.md` ya no prescribe esperar CI verde antes de mergear en MODO AUTÓNOMO.
- El texto apunta a modo cola / `--auto` / ADR-054.
- PR en cola de auto-merge (o mergeado si docs saltan checks al instante) y sesión cerrada con `/cerrar-total` modo cola.
