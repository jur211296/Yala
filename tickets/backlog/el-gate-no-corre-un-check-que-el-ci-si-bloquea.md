---
id: el-gate-no-corre-un-check-que-el-ci-si-bloquea
status: backlog
priority: low
area: "proceso"
created: 2026-09-08
source: medido de camino en chat-draft-sign-can-contradict-its-subcategory (2026-09-08)
updated: 2026-10-08
---

# El gate da verde a un cambio que el CI bloquea

## Qué pasa

`/gate` se declara «la única red que queda» cuando se commitea sin PR. Pero el job `coverage-index`
de `.github/workflows/qa.yml` —el que el propio workflow llama «el gate duro», el que corre siempre—
tiene **dos** pasos, y el gate local solo replica uno:

| Paso del CI | ¿Lo corre `/gate`? |
|---|---|
| `bash qa/validate-coverage.sh` (ratchet anti-drift) | **Sí**, paso 5 |
| `bash qa/check-test-isolation.sh` (`makeTestContext(` ⇒ `@Suite(.serialized)`) | **No** |

## Cómo se vio (2026-09-08)

Una suite existente (`VisionDraftFactoryTests`) ganó tests que usan `makeTestContext()` y no era
`@Suite(.serialized)`. El gate dio verde entero —build ×2, 61 tests, audit, índice— y el commit
salió; el CI lo tumbó a los 17 segundos. Reproducido en local extrayendo el `run:` del YAML:

```
❌ Aislamiento de tests roto: … YalaTests/VisionDraftFactoryTests.swift
```

No es un fallo cosmético de proceso: lo que ese check protege es real —`makeTestContext()` reusa el
container por `#fileID`, así que dos tests del mismo fichero en paralelo se pisan el store— y el
modo de fallo son tests que pasan en local y parpadean en CI, que es de los caros de diagnosticar.

## Por qué importa más de lo que parece

Con la regla del 2026-09-01, el trabajo de una sesión única en el árbol principal **va directo a
`2.1` sin PR**. Ahí no hay CI que lo pare antes de aterrizar: el rojo se descubre después, ya en la
rama de todos. El gate es exactamente la red que debía cubrir eso.

## Caminos

1. **Añadir el check al paso 5 del gate**, junto a `validate-coverage.sh`. Una línea, mismo sitio,
   mismo criterio de bloqueo. Es lo obvio y probablemente lo correcto.
2. **Que el paso 5 corra todo lo que corre el job `coverage-index`**, leyéndolo del YAML en vez de
   repetir la lista a mano — así no vuelve a divergir cuando el job gane un tercer paso. Más caro y
   más frágil (parsear el workflow), pero cierra la clase entera de fallo en vez de este caso.
3. **Dejarlo y documentarlo** en el gate: «esto no cubre X». Lo peor de los tres, pero al menos
   deja de prometer lo que no hace.

## Criterio de hecho (AC)

- [ ] Decidido el camino y aplicado.
- [ ] Control positivo: una suite con `makeTestContext(` sin `.serialized` hace que `/gate` **no**
      selle, y con `.serialized` sí.
- [ ] Comprobado si el job `tests` tiene algún otro paso que el gate tampoco replica.

## Medido en 2.1 (triage 2026-10-08)

- `/gate` §5 (`.claude/commands/gate.md:101-107`) sigue corriendo solo `bash qa/validate-coverage.sh`. Ningún hook ni comando local llama a `qa/check-test-isolation.sh`.
- El job `coverage-index` de `.github/workflows/qa.yml:69-108` ha crecido a 7 pasos: `validate-coverage.py`, `check-test-isolation.sh` (`:76`) y cinco bancos de scripts (`commit-msg-test.sh`, `sim-lock-test.sh`, `ci-simulador-test.sh`, `ci-reintentar-rojos-test.sh`, `ci-vigilante-nocturna-test.sh`). El gate no replica ninguno de los seis últimos.
- La divergencia que pedía el camino 2 ya ha pasado: los bancos solo importan si el diff toca esos scripts, pero el de aislamiento afecta a cualquier test nuevo.
- El CI lo sigue parando en todo PR y en el push a `2.1`. El hueco queda en el commit directo desde el árbol principal.

Triage 2026-10-08: abierto · medium → low · `/gate` §5 sigue sin correr `qa/check-test-isolation.sh` (`qa.yml:76`); el CI lo para en PR y en push, así que el hueco queda en el commit directo a `2.1`.
