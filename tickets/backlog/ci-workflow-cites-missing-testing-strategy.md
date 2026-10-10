---
id: ci-workflow-cites-missing-testing-strategy
status: backlog
priority: very-low
area: ci
created: 2026-09-07
updated: 2026-10-10
source: medido de camino en el-job-de-tests-del-ci-no-tiene-timeout
---

# El workflow del CI manda tres veces a un documento que no está en el repo

## Qué se midió

`.github/workflows/qa.yml` cita **`TESTING-STRATEGY.md`** tres veces, y las tres como el sitio
donde está el detalle que el comentario no cuenta:

- «Por (2) — flaky crash que ALCANZA al subset pure-logic — los 3 pasos siguen ADVISORY. […]
  Detalle en TESTING-STRATEGY.md.»
- «Volver a bloqueante exige resolver ese crash primero (TESTING-STRATEGY.md).»
- «no bloquean por el insert-trap flaky de SwiftData en el runner de CI. Plan de migración en
  TESTING-STRATEGY.md.»

**Ese fichero no existe en el repo.** Comprobado el 2026-09-07 sobre este árbol:

```
find . -iname "*testing*strateg*"                        → vacío
git log --all --diff-filter=AD -- '**/TESTING-STRATEGY.md'
    4b66061f  A  .planning/TESTING-STRATEGY.md
    f0bb2866  D  .planning/TESTING-STRATEGY.md   ← "remove .planning/ sync"
```

Vivía en `.planning/`, que era un espejo del vault de Obsidian, y se borró al retirar ese espejo.
Hoy el original está en `$VAULT/planning/TESTING-STRATEGY.md` — así lo referencia
`.claude/rules/testing.md:44`, que sí da la ruta completa.

## Por qué importa

No es sólo un enlace roto. `CLAUDE.md` dice, literal: «La SSOT de proceso y tickets es **este
repo**. No uses Obsidian / YalaWiki como fuente de verdad.» Así que el CI manda a buscar la
justificación de su decisión más importante —por qué los tres pasos de test son advisory y qué
haría falta para volverlos bloqueantes— a una fuente que el propio repo declara no-SSOT, y con un
nombre que ni siquiera dice dónde está.

El coste real es para quien llegue a preguntarse por qué el CI no bloquea: busca el fichero, no lo
encuentra, y o bien se queda sin el porqué o bien decide por su cuenta. La «Lista Negra» que citan
otros seis sitios del repo tiene el mismo problema.

## Qué hacer

Elegir una de las dos, no las dos:

1. **Traer al repo lo que el CI necesita citar.** No el documento entero: el bloque de por-qué-
   advisory y el plan de volver a bloqueante, en `.claude/rules/testing.md`, que ya es la superficie
   durable de esa área y ya se carga sola al tocar tests. Las citas del workflow apuntarían ahí.
2. **Dejarlo en el vault y decirlo bien**: cambiar las tres citas por la ruta completa
   (`$VAULT/planning/TESTING-STRATEGY.md`), como ya hace `.claude/rules/testing.md:44`. Más barato,
   pero deja el porqué del CI fuera del repo, que es justo lo que `CLAUDE.md` desaconseja.

Barrer de paso las otras citas sin ruta: `tickets/backlog/unit-suite-nondeterministic-reds.md:90`,
`.claude/rules/testing.md:45` y `:54`, `.claude/commands/cerrar.md:41`.

## Distinto de

- `el-job-de-tests-del-ci-no-tiene-timeout` — de donde salió esto. Ése iba del tiempo sin tope y de
  mover la UI a una nocturna; no tocó ninguna de las tres citas.
- `ci-warns-but-does-not-block` — ése discute **si** los pasos deben bloquear. Éste sólo pide que el
  motivo escrito esté donde el workflow dice que está.

## Acceptance Criteria

- [ ] Las tres citas de `TESTING-STRATEGY.md` en `.github/workflows/qa.yml` resuelven a algo que
      existe desde el repo.
- [ ] Decidido cuál de las dos vías, y escrito el porqué en el propio ticket.
- [ ] Las otras cuatro citas sin ruta, barridas con el mismo criterio.

## Medido en 2.1 (triage 2026-10-08)

- Las tres citas siguen en `.github/workflows/qa.yml:250`, `:412` y `:453`.
- Las otras citas sin ruta se movieron: `.claude/rules/testing.md:62` y `:90`, `.claude/commands/cerrar.md:39`. `unit-suite-nondeterministic-reds` ya está en `tickets/done/`.

Triage 2026-10-08: abierto · low → very-low · las citas rotas siguen, pero es documentación de mantenimiento que no ciega al CI.

## 2026-10-10 · las tres citas de `qa.yml` ya no están

`ci-warns-but-does-not-block` promovió los unit a bloqueantes y reescribió los tres comentarios: el
porqué vive ahora en el propio `qa.yml` («LOS UNIT BLOQUEAN», sobre el job `tests`) y en
`.claude/rules/ci-qa.md`. `grep -c TESTING-STRATEGY .github/workflows/qa.yml` da 0. Queda el barrido
de las otras citas sin ruta (`.claude/rules/testing.md` y `.claude/commands/cerrar.md`).
