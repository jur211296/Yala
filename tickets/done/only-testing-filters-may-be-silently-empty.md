---
id: only-testing-filters-may-be-silently-empty
status: done
priority: low
area: qa, testing
created: 2026-09-03
updated: 2026-11-04
source: descubierto al verificar un mutante (2026-09-02)
---

# Puede haber filtros de test que no ejecutan nada y salen en verde

## El hallazgo

`-only-testing:YalaTests/<X>` resuelve por el nombre del **TIPO** (el struct de la suite), no por el
del fichero. Y en este repo hay ficheros que declaran suites con nombres que no se parecen al suyo:
`YalaTests/Groups/GroupsOrganizerBranchTests.swift` declara `GroupsOrganizerGateTests`,
`GroupsOrganizerNoWriteTests`, `GroupsOrganizerFlowTests`, `GroupsOrganizerWiringTests` y
`WelcomeBackDestinationTests` — **ninguna se llama como el fichero**.

Cuando el filtro no casa, `xcodebuild` **no avisa** y la corrida termina en `** TEST SUCCEEDED **`.

## Lo MEDIDO (2026-09-02)

Pidiendo 3 suites salió `Test run with 15 tests in 2 suites passed`. Verde, exit 0, y **una de las
tres no se ejecutó** — precisamente la que contenía el source-scan escrito para cazar el mutante que
se estaba verificando en ese momento.

Es peor que su hermana ya documentada (nombrar un MÉTODO en `-only-testing`, que corre cero tests):
allí el conteo era 0 y saltaba a la vista; aquí **sí corren tests y sí hay conteo**, así que el verde
parece legítimo. Sólo lo delata el número de SUITES comparado con las que pediste.

## Qué hay que auditar

Todos los `-only-testing:` del repo, comprobando que cada nombre corresponde a un **tipo** real:

- `.github/workflows/qa.yml`
- `.claude/commands/*.md` (el `/gate` construye filtros a partir de los ficheros tocados — ése es
  justo el patrón de riesgo)
- `qa/scripts/*.sh` y cualquier script
- `docs/`

Y los `-skip-testing:` que apunten a nombres inexistentes: un skip que no casa es inofensivo, pero
delata el mismo malentendido y probablemente hay un `only-testing` hermano roto al lado.

**Ojo al construir el inventario**: los ids de este repo mezclan mayúsculas y minúsculas
(`rojo-heroBuckets-…`), así que un regex de sólo-minúsculas pierde filas. Ese error ya se cometió una
vez en esta misma sesión.

## Contexto

`docs/aprendizajes-tecnicos.md`, entrada «`-only-testing` con el nombre del FICHERO tampoco filtra».

## Medido en 2.1 (triage 2026-10-08)

- Inventario hecho: los `-only-testing:` vivos de `.github/workflows/qa.yml` (:443-491), `ci-sombra.yml` y `/l10n-check` nombran tipos que existen, uno por nombre. Los nombres que no casan (`DeadPointerSeedTests`, `GroupsIdentityPurgeGateTests`, `A`/`B`/`Spike`/`Ctx`) solo aparecen en ejemplos de documentación y en el banco de `ci-reintentar-rojos-test.sh`.
- Lo que queda es la receta del `/gate`: `.claude/commands/gate.md:38` sigue mapeando por `<Clase>Tests.swift`, es decir, por fichero. Y 53 ficheros de `YalaTests` declaran suites que no se llaman como el fichero.
- La red que sí hay: el gate exige comparar `Test run with N tests in M suites` con las suites pedidas (`gate.md:49`), y `.claude/rules/testing.md:178` manda resolver los nombres con `grep "@Suite"`. Falta que la receta del gate lo diga en su paso 2.

Triage 2026-10-08: abierto · medium → low · CI y `/l10n-check` filtran por tipos reales; queda que `gate.md:38` resuelva por tipo y no por fichero (53 ficheros no casan).

## Resuelto (2026-11-04, lote T5 · recetas del gate)

- Nuevo ayudante `qa/scripts/suites-de-fichero.py`: de un fichero de test a los TIPOS que `-only-testing` sabe filtrar (tipos de columna 0 con `@Suite` delante o algún `@Test` dentro; mira solo código, no comentarios ni cadenas). Banco: `qa/scripts/suites-de-fichero-test.sh` (12 casos, con mutantes comprobados), que corre en `coverage-index`.
- El paso 2 del `/gate` resuelve las suites con él, y suma los ficheros de test tocados (antes el mapeo los excluía). Criterio del conteo: `M ≥ suites pedidas`.
- Medido sobre `YalaTests` el 2026-11-04: 107 ficheros no declaran ninguna suite con su nombre y 201 declaran más de una. `grep "@Suite"` tampoco bastaba: `LocalizationParityTests.swift` declara tres suites sin `@Suite`.
- `YalaUITests`: sus 66 clases XCTest se llaman como su fichero, así que el paso 3 sigue pidiendo por el nombre del fichero; queda escrito en el gate.
- La regla de `.claude/rules/testing.md` (la del filtro por tipo) apunta ahora al ayudante.
