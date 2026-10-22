---
id: two-qa-benches-nobody-runs
status: backlog
priority: low
area: "qa"
created: 2026-09-09
updated: 2026-10-08
source: salió de camino al cerrar el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo
---

# Dos bancos de pruebas que no corre nadie

## Qué pasa

`qa/scripts/` tiene tres bancos que pinean comportamiento de la infraestructura. Uno corre
solo desde el 2026-09-09; los otros dos **no los invoca nada**:

| Banco | Qué pinea | Quién lo corre |
|---|---|---|
| `commit-msg-test.sh` | el candado anti-atribución | CI, job `coverage-index` |
| `worktree-stamp-test.sh` | el sello de `/gate` (7 casos) | **nadie** |
| `ci-allowlist-test.sh` | el allowlist del CI (12 casos) | **nadie** |

Medido con `grep -rn` sobre `*.sh`, `*.yml`, `*.md` y `*.json`: las únicas menciones a los
dos últimos son su propia cabecera y un puntero desde el script que documentan.

## Por qué importa

Los dos nacieron de un fallo real —el sello bloqueaba ficheros nuevos, el allowlist del CI
dejaba correr suites duplicadas— y su cabecera dice que existen para que eso no vuelva. Un
banco que nadie ejecuta no vigila: lo que impide la regresión es que alguien se acuerde de
correrlo, que es justo lo que el banco venía a sustituir.

## Qué haría falta

Añadirlos al job `coverage-index` de `.github/workflows/qa.yml`, que ya corre en ubuntu en
cada push y donde el tercero entró sin coste apreciable. Antes de hacerlo, comprobar que
los dos corren en Linux: `worktree-stamp-test.sh` monta un repo git desechable en `/tmp`,
y conviene medir que no depende de nada de macOS.

## Criterio de hecho (AC)

- [ ] Los dos bancos corren en CI, o está escrito por qué no pueden.
- [ ] Un mutante confirma que cada uno puede ponerse rojo desde el CI.

## Medido en 2.1 (triage 2026-10-08)

- `.github/workflows/qa.yml:83-108` corre hoy cinco bancos: `commit-msg`, `sim-lock`, `ci-simulador`, `ci-reintentar-rojos` y `ci-vigilante-nocturna`. Faltan los dos de este ticket.
- `.claude/rules/git-hooks.md:178` sigue diciendo que a `worktree-stamp-test.sh` no lo corre nadie.
- `ci-allowlist-test.sh` extrae el `case` de `qa.yml`, y conviene comprobar que el bloque sigue siendo extraíble antes de cablearlo.
- Por qué low: vigilan dos redes (el sello del gate y el allowlist del CI), pero las dos redes funcionan. Lo que no existe es la alarma si se rompen.

Triage 2026-10-08: abierto · medium → low · qa.yml ya corre cinco bancos de qa/scripts, pero sigue sin correr worktree-stamp-test.sh ni ci-allowlist-test.sh
