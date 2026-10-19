---
id: branch-2-2-merges-without-waiting-for-ci
status: backlog
priority: high
area: "ci, proceso"
created: 2026-10-18
updated: 2026-10-18
source: barrido de QA 2.2 y arreglo del CI de 2.2 (PR #555), 2026-10-18
---

# La rama 2.2 mergea sin esperar al CI

## Qué pasa

`2.1` tiene un ruleset (`24270515`) que exige `tests` y `coverage-index`; `2.2` no tiene ninguno ni protección de rama
(`gh api repos/jur211296/Yala/branches/2.2/protection` → 404 «Branch not protected»). Con el auto-merge de las sesiones
autónomas (ADR-054 de casa), `gh pr merge --auto` no tiene checks que esperar y mergea en el acto.

## Medido

El PR #554 entró en 2.2 el 2026-10-19 02:35 UTC con el job `tests` en **FAILURE**: el CI de 2.2 llevaba roto desde el
#552 (Xcode 26.6 frente a las APIs de iOS 27). El #555 lo arregla y su corrida verde incluía el código del #554, así que
esta vez no entró nada roto. Fue suerte, no red.

## Qué haría falta

Añadir `refs/heads/2.2` al ruleset de `2.1`, o crear uno igual para `2.2`. Es un cambio de reglas del repositorio: lo
decide Jürgen.
