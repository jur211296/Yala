---
id: 2026-11-17-verificacion-cuarentena-y-sello
status: done
priority: high
area: qa
created: 2026-11-17
updated: 2026-11-17
source: encargo 2026-11-17-verificacion-cuarentena-y-sello (Jürgen, 17-nov: «Apliquemos todo lo recomendado» sobre la propuesta de verificación, P1 segunda parte y P3)
---
# Cuarentena de pruebas inestables con dueño, y línea «Verificado:» en cada commit

Dos propuestas de `docs/verificacion/README.md` (comparación con el equipo de Claude Code, 17-nov).

## P1, segunda parte: un rescate solo vale si la prueba está en la cuarentena

**Antes.** Un unit que fallaba y pasaba al repetirlo dejaba el PR en verde, con un aviso que nadie
leía. Medido del 10 al 17-nov: 50 rescates en 47 de 338 corridas del job `tests`, los 50 de la
familia `CurrencyConverter*` (7 casos), y 1 arranque fallido del simulador.

**Ahora.**
- `qa/cuarentena.json`: prueba, dueño, ticket, fecha de entrada y motivo. Entran los 7 casos de
  divisas (su arreglo, en el PR de las pruebas inestables de divisas, aún no estaba en 2.3).
- El job `tests` la trae de `origin/2.3` en un paso propio, nunca del PR, y escribe en el resumen
  del job el modo y las vencidas (≥ 14 días).
- `ci-reintentar-rojos.sh --cuarentena`: rescate en la lista → aviso con dueño y días; fuera →
  aviso «Rescate fuera de cuarentena» en el PR y en el resumen. Los arranques fallidos no pasan por
  la lista.
- **Modo observar** hasta el 1-dic-2026. Interruptor: `_meta.modo` en el fichero de 2.3. La
  promoción a bloquear es una sesión corta aparte.

## P3: cada commit dice cómo se verificó

- `/gate` sella con `verificado-en-commit.sh sellar …`: línea 1 la huella de siempre, línea 2
  `Verificado: build 2/2 · unit N suites · interfaz N clases · índice ✓`.
- `.githooks/prepare-commit-msg` copia esa línea al mensaje como trailer, o `Verificado: ninguno` /
  `Verificado: ninguno (solo docs)` sin sello válido. Corre también con `--no-verify`. No bloquea.
- `resellar` conserva el resumen entre los commits de una tanda (la huella incluye HEAD).

## Verificación

- `ci-reintentar-rojos-test.sh` 54/54 (casos 21-28 nuevos), `cuarentena-test.sh` 29/29,
  `verificado-en-commit-test.sh` 25/25: commits reales en un repo de juguete.
- Mutantes: 14 cambios a mano en la lógica (prefijo de suite, día 14, bloquear, ausente, duplicadas,
  replace/add, amend, squash, docs, pre-commit leyendo el sello entero, hook desenchufado…); los 14
  ponen algún banco en rojo.
- `actionlint` limpio sobre `qa.yml`; `ci-unit-bloqueante-test.sh` en verde.

## Queda fuera

- Promover la cuarentena a bloquear: 1-dic-2026, sesión aparte.
- Leer de 2.3 también el script que aplica la lista (hoy solo la lista): propuesta P4.
- Quitar los 7 casos de divisas cuando mergee su arreglo (o vencen el 1-dic y el CI lo avisa).
