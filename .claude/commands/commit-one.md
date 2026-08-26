---
description: Crea un commit atómico verificado y deja el ticket sincronizado
allowed-tools: Bash(git:*), Bash(bash qa/scripts/worktree-stamp.sh:*), Bash(bash qa/validate-coverage.sh:*), Read, Write, Edit, Glob, Grep
---

Un commit, un tema, verificado.

## 1 · Leer el cambio

`git status --porcelain`, `git diff HEAD` y `git log --oneline -10`. Una vez cada uno; los resultados quedan en contexto.

Si hay commits `wip:` recientes relacionados con este trabajo, pregunta si combinarlos (`git reset --soft HEAD~N`) antes de seguir.

## 2 · Alcance

Mediana histórica del repo: 3 archivos. Por encima de ~10 archivos o ~500 líneas, **muestra el desglose y pregunta si conviene partirlo** — pero acepta la respuesta: en este proyecto los cambios de sync, migraciones y l10n (16 locales × N keys) son legítimamente grandes y partirlos rompe la atomicidad real.

Lo que sí es señal de partir: temas **inconexos** en el mismo diff (un fix de cálculo + un cambio de UI sin relación).

Determina el prefijo: `feat` · `fix` · `refactor` · `test` · `chore` · `docs`.

## 3 · Gate

```
/gate
```

Verde → adelante. Rojo → **no commitees**; arregla y repite. El hook de pre-commit vuelve a comprobar el sello, así que saltarse este paso solo retrasa el bloqueo.

Salta el gate únicamente si el prefijo es `docs:` o `chore:` **y** no hay ningún `.swift` en el diff.

## 4 · Cobertura

Según el prefijo, comprueba que el cambio no entra sin red:

- **`fix:`** → ¿hay un test que reproduzca el bug corregido? Si no, escríbelo. Es la regla más rentable del repo: un fix sin test de regresión vuelve.
- **`feat:`** → ¿las funciones nuevas no privadas tienen cobertura? Happy path + los bordes que importen.
- **`refactor:` / `test:`** → basta con que el gate esté verde.

Convenciones de test del proyecto (esto **no** es opcional ni negociable, y es lo que más se equivoca):

- **Swift Testing**, no XCTest: `@Test`, `@Suite`, `#expect`, `#require`. El repo tiene 419 archivos con `import Testing` y **cero** con XCTest.
- Nombres descriptivos de lo que se verifica. `func test_x_y_z()` no existe aquí.
- `makeTestContext()` **está permitido y es el patrón canónico** — reusa un container in-memory por archivo. Toda suite con ≥2 llamadas debe ser `@Suite(.serialized)`.
- Mejor aún: `@Model` directos sin contexto cuando la lógica lo permita. Más rápido y sin acoplamiento.
- Detalles y trampas en `.claude/rules/testing.md`.

## 5 · Commit

Propón el mensaje, lista los archivos exactos y **pregunta antes de ejecutar**.

```bash
git add <archivos concretos>
git commit -m "<prefijo>: <mensaje>"
rm -f .claude/sessions/tests-passed
```

Nunca `git add -A`. Nunca incluyas un trailer `Co-Authored-By`. No pushees: el hook `Stop` lo hace.

## 6 · Sincronizar el ticket

**Dos superficies, no cinco.** Git ya guarda el qué y el cuándo.

**a) El ticket en `tickets/`** (índice: `docs/TICKETS.md`):

Muévelo a la carpeta del nuevo estado y actualiza el frontmatter (`status` = nombre de la carpeta).

| Estado | Carpeta | Frontmatter |
|---|---|---|
| Implementado, falta QA | `tickets/qa/` | `status: qa` · `qa-status: needs-testing` · `implementation_date:` |
| QA pasado | `tickets/done/` | `status: done` |
| Descartado | `tickets/discarded/` | `status: discarded` |

No declares PASS ni cierres un ticket por inferencia. Actualiza `docs/TICKETS.md` si cambió el path.

Añade a `## Implementación` la fecha, el hash, los archivos con qué cambió en cada uno, y **las decisiones técnicas con su porqué** — eso es lo único que el código no puede contar solo.

**b) `qa/coverage-index.json`** si el commit tocó código bajo `Yala/`: `lastVerified` de las áreas afectadas, y `bash qa/validate-coverage.sh`.

**Una regla nueva y duradera** (un gotcha que costaría caro repetir) va a `.claude/rules/` del área correspondiente. Pasa raras veces. No inventes una para tener algo que escribir.

## Informe

```
✓ <hash> <mensaje>
✓ Ticket: <archivo> → <nuevo nombre>
✓ coverage-index: <áreas>        (o "sin cambios bajo Yala/")
✓ Tests añadidos: N              (si los hubo)
```

## Reglas

- El gate manda. No se commitea en rojo, y «es preexistente» no lo pone verde.
- Un commit = un tema.
- Todo en lenguaje de usuario en el ticket: «se corrigió el saldo de las cuentas compartidas», no «se refactorizó el FetchDescriptor».
