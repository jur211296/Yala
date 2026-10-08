---
id: cerrar-total-para-ante-un-check-rojo-que-no-bloquea
status: discarded
priority: medium
area: "proceso, ci"
created: 2026-09-09
updated: 2026-10-08
source: medido al arreglar el avisador de rojos del CI (PR #123)
---

Why: Discarded 2026-10-08. Premisa superada por ADR-054 de casa: 2.1 tiene ruleset (tests + coverage-index) y Yala cierra en modo cola con auto-merge, donde decide GitHub.

# `/cerrar-total` para ante un check rojo que en realidad no bloquea nada

## Qué pasa

El ticket del avisador decía que un rojo del paso de aviso «impedía mergear el PR». Medido el
2026-09-09, eso es cierto en efecto pero **la causa no es GitHub**:

```
gh api repos/jur211296/Yala/branches/2.1/protection  → 404 Branch not protected
gh api repos/jur211296/Yala/rulesets                 → []
```

`2.1` no tiene protección de rama ni rulesets, así que **no hay checks requeridos**: GitHub no
bloquea ningún merge por un check en rojo. Lo que para es nuestra propia `/cerrar-total`, cuyo
paso 0 dice «El PR no está mergeable, o hay conflictos → Para. Resuélvelo primero, no fuerces»
y cuyo paso 1 lee `gh pr view --json state,mergeable,mergeStateStatus`.

Con cualquier check rojo no requerido, `mergeStateStatus` vale `UNSTABLE` — que significa
«mergeable, pero hay checks fallando», no «bloqueado». La skill no distingue `UNSTABLE` de
`BLOCKED`/`DIRTY`, así que un check rojo **de cualquier cosa** detiene el cierre de la sesión.

## Por qué importa

Los tests de este repo son advisory **a propósito**: la razón es que un flaky conocido no frene
el trabajo. Si cualquier check rojo detiene el cierre, esa decisión queda anulada por la puerta
de atrás — el repo se comporta como si todo fuera bloqueante, pero solo cuando algo falla.

Y en la dirección contraria: tratar todo rojo como «para» empuja a saltarse la comprobación
entera cuando se vuelve rutinaria, que es peor que no tenerla.

## Lo que hay que decidir

- [ ] Distinguir en `~/.claude/skills/cerrar-total/SKILL.md` los estados que sí son bloqueo real
      (`DIRTY` = conflictos, `BLOCKED` = falta una review o un check requerido, `BEHIND`) de
      `UNSTABLE`, que solo dice que hay checks rojos no requeridos.
- [ ] Con `UNSTABLE`, la conducta correcta probablemente no es «para» ni «sigue», sino **mirar
      qué check está rojo y decidirlo con nombre**: `tests` en rojo no es lo mismo que un check
      de aviso o un preview de Vercel. Eso ya no es un `mergeStateStatus`, es una lista.
- [ ] Es una skill global (`~/.claude/skills/`), no de este repo. El ticket vive aquí porque el
      efecto medido fue aquí.

## Medido en 2.1 (triage 2026-10-08)

- `gh api repos/jur211296/Yala/rulesets` → «2.1 exige tests y coverage-index» (activo); `allow_auto_merge` = `true`.
- `~/.claude/skills/cerrar-total/SKILL.md:23` manda a Yala al modo cola (§3 bis, `:65`): `gh pr merge --auto` y la sesión no espera al CI, así que no lee un `UNSTABLE` al cerrar.
- Residual fuera de Yala: la fila `:24` («no está mergeable → para») sigue sin distinguir `UNSTABLE` en repos sin auto-merge. Es de la skill global, no de este repo.

Triage 2026-10-08: descartado · medium → — · premisa superada por ADR-054 de casa: `2.1` tiene ruleset (`tests` + `coverage-index`) y Yala cierra en modo cola, donde GitHub, no la skill, decide si un rojo bloquea.
