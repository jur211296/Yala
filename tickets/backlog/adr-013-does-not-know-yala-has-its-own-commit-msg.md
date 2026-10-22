---
id: adr-013-does-not-know-yala-has-its-own-commit-msg
status: backlog
priority: low
area: "proceso"
created: 2026-09-09
updated: 2026-10-08
source: salió de camino al cerrar el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo
---

# ADR-013 no sabe que Yala tiene su propio `commit-msg`

## Qué pasa

Desde el 2026-09-09 el candado anti-atribución de Yala vive en `.githooks/commit-msg`, en
este repo, y **no delega** en el hook global de `~/.claude/git-hooks/`. El global sigue
siendo la SSOT para los otros 24 repos del Mac, pero ya no lo es para éste.

ADR-013 (en `~/Claude/casa/decisions/`) dice que la regla «no depende de acordarse» porque
hay un hook global. Para Yala eso es cierto por otro camino, y quien toque el hook global
—para añadir un patrón nuevo, por ejemplo— **no tiene forma de enterarse** de que aquí hay
una copia que también habría que tocar.

## Por qué no se hizo en la misma sesión

El encargo era de Yala y decía explícitamente no tocar hooks de casa sin decisión. La
decisión que dio Jürgen fue justamente **no** tocar el global.

## Qué haría falta

- Una nota en ADR-013 (o un ADR que lo matice) diciendo que Yala tiene su propio
  `commit-msg` por la trampa de `core.hooksPath`, con puntero a `.claude/rules/git-hooks.md`.
- Y al revés: que quien añada un patrón al global sepa que existe
  `bash qa/scripts/commit-msg-test.sh`, cuya segunda mitad detecta la divergencia si la
  hay — pero solo si alguien lo corre en el Mac.

## Criterio de hecho (AC)

- [ ] ADR-013 menciona la excepción de Yala y por qué.
- [ ] Queda escrito qué correr para comprobar que los dos hooks no han divergido.

## Medido en 2.1 (triage 2026-10-08)

- `~/Claude/casa/decisions/0013-ningun-commit-dice-que-lo-escribio-una-ia.md` sigue sin nombrar Yala ni `.githooks/commit-msg`; solo trae el límite genérico de `core.hooksPath` (`:69-71`). Ningún ADR posterior de casa lo matiza.
- En Yala siguen `.githooks/commit-msg`, `.claude/rules/git-hooks.md` y `qa/scripts/commit-msg-test.sh`. El arreglo es de casa, fuera de este repo.

Triage 2026-10-08: abierto · medium → low · ADR-013 sigue sin mencionar el commit-msg propio de Yala; es una nota de documentación en casa, con red local (commit-msg-test.sh).
