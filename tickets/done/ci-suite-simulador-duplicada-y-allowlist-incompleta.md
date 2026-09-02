---
id: ci-suite-simulador-duplicada-y-allowlist-incompleta
status: done
priority: high
area: platform
created: 2026-09-01
updated: 2026-09-01
---
# El CI corre la suite de simulador dos veces por commit, y la corre para cambios que no compila nadie

`.github/workflows/qa.yml` encola el runner `macos-26` **dos veces por el mismo commit**, y
además lo encola para diffs que no son input de `xcodebuild`. Cada corrida de esa suite cuesta
**~100 minutos de reloj**. No es un problema de cobertura: es tiempo de runner tirado y feedback
que llega tarde.

El origen es una pregunta de Jürgen el 2026-09-01 («¿era necesario correr toda la tanda?»). La
respuesta corta fue que **el filtro ya existe y funciona** —el job `changes` con su allowlist—,
pero tiene dos agujeros medibles.

## Medido el 2026-09-01 (no inferido)

**Duración real de los runs de `qa.yml`** (`gh run list --workflow=qa.yml --status=completed`):

| Run | Evento | Duración | Qué hizo |
|---|---|---|---|
| 33558950499 | `push` | **97,4 min** | corrió la suite |
| 33558938104 | `pull_request` | **102,4 min** | corrió la suite |
| 33556874800 | `push` | **0,3 min** | la saltó (allowlist) |
| 33556115336 | `pull_request` | **0,3 min** | la saltó (allowlist) |

Los dos primeros son **el mismo commit**: ~200 min de runner macOS donde debería haber ~100.

**Duplicación confirmada** sobre el commit del PR #58
(`gh run list --commit <sha>`): dos runs de `QA`, uno `event=push` y otro `event=pull_request`,
los dos ejecutando el job `tests` completo.

**`gateway/` y `qa/` NO son input de `xcodebuild`** — comprobado contra el árbol con el mismo
método que el propio workflow exige en su comentario («repetir la comprobación, no asumirla»):

```
grep -c "gateway"        Yala.xcodeproj/project.pbxproj   → 0
grep -cE "path = qa|qa/" Yala.xcodeproj/project.pbxproj   → 0
```

## Trabajo

**1 · Quitar la duplicación push/PR.** Hoy los triggers son `on: push` y `on: pull_request` sin
filtro de rama, así que toda rama de ticket dispara los dos. Acotar el `push` a las ramas que de
verdad hay que vigilar:

```yaml
on:
  push:
    branches: [2.1, "1.0"]
  pull_request:
```

**Ahorro ~100 min de runner macOS por PR, sin perder una línea de cobertura**: el commit que se
mergea lo vuelve a cubrir el `push` sobre `2.1`. Riesgo bajo; es el patrón estándar.

**2 · Ampliar la allowlist del job `changes` con las rutas medidas como inertes.** Añadir a la
lista de rutas que no disparan la suite:

```
gateway/*   qa/cloud/*
```

**Acotado a `qa/cloud/`, NO a `qa/` entero**: `qa/scripts/*.sh` y `qa/validate-coverage.*` sí
deciden **cómo se verifica** el proyecto, y el propio `/gate` los trata como disparadores por esa
razón. Meter `qa/*` sería el error.

Ojo al implementarlo: el `case` del job usa patrones de shell con `|` (`docs/*|tickets/*|…`), no
globs de `paths-ignore`. Seguir esa forma.

**3 · NO tocar el deny-by-default.** El fail-closed («1,5 h de más sale más barato que un verde
que no probó nada») está razonado y es correcto: si el diff llega vacío, la API corta la lista o
el evento es inesperado, la suite debe correr. Este ticket recorta lo que sobra, no la red.

## Comprobación al cerrar

- Un PR que toque **solo** `gateway/**` debe dar `run_tests=false` y cerrar en ~0,3 min.
- Un PR que toque `gateway/**` **y** `Yala/**` debe correr la suite igual — el deny-by-default ya
  lo cubre (basta un fichero fuera de la allowlist), pero conviene verificarlo y no asumirlo.
- Una rama de ticket debe producir **un** run de `QA`, no dos.

## Fuera de alcance

Los tres pasos de test siguen **advisory** (`continue-on-error: true`) por el `EXC_BREAKPOINT`
flaky de SwiftData in-memory; el gate duro es `coverage-index`. Este ticket no cambia esa
estrategia — eso es el TODO(@jur, 2026-07-15) que sigue vivo en el propio workflow.

## Implementación (2026-09-01)

**1 · Duplicación.** `on: push` pasa a `branches: ["2.1", "1.0"]`. Una rama de ticket ya no
dispara run de `push`; el PR sigue disparando el suyo, y el commit que aterriza lo cubre el push
sobre `2.1`.

**Un fallo cazado al validar, que merece quedar escrito:** la primera versión ponía
`branches: [2.1, "1.0"]` y **YAML parsea `2.1` sin comillas como el número 2.1**, no como la
cadena `"2.1"`. Habría dejado el trigger de push sin casar nunca con la rama principal — es
decir, el CI dejando de correr en `2.1` **en silencio**, que es peor que el problema que este
ticket viene a resolver. Lo cazó validar el YAML y mirar el tipo, no leerlo. Va con comillas.

**2 · Allowlist.** Añadidas `gateway/*` y `qa/cloud/*`, con la medición repetida y anotada
dentro del propio workflow, como su comentario exige. **`qa/scripts/` y `qa/validate-coverage.*`
se quedan fuera a propósito**: deciden cómo se verifica el proyecto.

**3 · El deny-by-default no se tocó.**

### Verificado

- **`qa/scripts/ci-allowlist-test.sh`** (nuevo): **12/12**. No copia el `case` del workflow, lo
  **extrae**, así que el test no puede divergir de lo que se ejecuta. Cubre las dos rutas nuevas,
  los vecinos que deben seguir corriendo (`qa/scripts/` el primero), el deny-by-default con un
  fichero mezclado, y lo que ya se saltaba antes.
- **YAML válido** y ambas ramas tipadas como cadena (comprobado sobre el árbol de parseo, no a
  ojo).
- Gate completo antes del commit: build de las dos schemes ✓, audit ✓, índice `RESULT: OK` ✓.

### Comprobado en vivo contra GitHub (punto 1)

Se pusheó una rama desechable `tmp/verify-ci-trigger` **sin abrir PR** y GitHub disparó
**0 runs**. Antes habría disparado uno por el evento `push`. La rama se borró acto seguido.

Ojo con un dato que **no** prueba nada y podría parecer que sí: que el push de este commit a
`2.1` diera un solo run. Un push directo a la rama principal también daba uno antes; la
duplicación aparecía en **rama + PR**. Por eso la comprobación se hizo sobre una rama de ticket.

### Pendiente de observar (punto 2)

Que un PR de solo-`gateway` cierre en ~0,3 min **no se ha visto todavía en vivo**: no había un
cambio de esa carpeta a mano para provocarlo. La lógica está probada en local contra las rutas
reales (12/12) y la confirmación llegará con el primer PR que toque solo ahí. No es un riesgo
abierto: si el filtro fallara, fallaría hacia correr de más, que es el lado seguro.
