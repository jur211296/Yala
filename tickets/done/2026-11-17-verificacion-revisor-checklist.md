---
id: 2026-11-17-verificacion-revisor-checklist
status: done
priority: high
area: qa
created: 2026-11-17
updated: 2026-11-17
source: encargo 2026-11-17-verificacion-revisor-checklist (Jürgen, 17-nov: «Apliquemos todo lo recomendado» sobre la propuesta de verificación, P4 segunda parte)
---
# Un solo revisor con la checklist de confiabilidad en el gate, leído de 2.3

P4 de `docs/verificacion/README.md`, segunda parte. La primera (la checklist de 30 ítems con su
disparador) es el ticket `2026-11-17-verificacion-checklist-curada`.

## Antes

La revisión de lógica cara era una recomendación de `CLAUDE.md`: «review adversarial con varias
lentes», sin nada que la pidiera ni la registrara. El gate y sus reglas se leían del mismo árbol que
se verificaba.

## Ahora

- `qa/scripts/checklist-elegir.py`: lee de `origin/2.3` la checklist y las instrucciones del revisor,
  calcula el diff (árbol de trabajo y no versionados contra el punto de partida con 2.3) y elige los
  ítems que dispara, hasta 10, primero los de lógica cara. Exit 0 si el revisor aplica (nube, dinero,
  migración, fechas o formulario), 3 si no, 2 si no puede leer la checklist.
- `.claude/agents/revisor-checklist.md`: un solo revisor, veredicto por ítem (CUMPLE, HALLAZGO con
  escenario, NO APLICA, DUDA, PIDE), hasta tres rondas, formato fijo que se cuenta.
- `/gate`, paso 4 bis: el gate saca el selector de 2.3 con `git show`, lanza el revisor y contesta
  sus hallazgos por `SendMessage`. **Observar**: no bloquea. El resultado va al cuerpo del PR y a la
  línea `Verificado:` (`· revisor 4 ítems, 2 hallazgos, 1 aceptado`, con
  `verificado-en-commit.sh sellar … --revisor N --hallazgos H --aceptados K`).
- `CLAUDE.md` y la ficha de Frank apuntan a este paso en vez de a las varias lentes.
- `.claude/rules/ci-qa.md`, «Revisor con checklist»: qué se lee de 2.3, lo medido y cuándo se
  promueve (no antes del 15-dic-2026 ni de 30 PR con revisor; al menos la mitad de los hallazgos
  aceptados y menos de 1 de cada 10 PR sin acuerdo; lo decide Jürgen).

## Medido

- **Disparo sobre los 215 PR mergeados a 2.3 del 3 al 17-nov**, con los 30 ítems: el revisor habría
  aplicado en 72 (≈5 al día); mediana 2 ítems, máximo 6, el tope de 10 nunca. 102 PR disparan algún
  ítem (30 solo de `pruebas`). Más frecuentes: `tocar-tras-escribir-en-xcuitest` (32),
  `ahora-fijo-en-pruebas` (23), `marca-aproximado-sobre-lo-mostrado` (20). No dispararon nunca
  `salir-de-fase-repone-pendientes` ni `syncid-cambiado-escribe-testigo`.
- **Revisor sobre el PR de categorías a un toque (#920)**, ronda 1: hallazgo con
  `SplitCalculatorUITests` (el toque de «Mi parte» cae en el teclado) y `AccountCardPickersUITests:91`
  (el chip de cuenta bajo «Guardar»), las dos que ese PR rompió sin correrlas; ~110 k tokens, 2 min.
  Ronda 2 con una refutación falsa («pasó en la nocturna del 16-nov»): la rechazó citando el ticket de
  los rojos del 16-nov y el `merge-base`. No es una prueba ciega: ese PR es origen del ítem.
- Bancos: `checklist-elegir-test.sh` (22 comprobaciones; 7 mutantes del selector, los 7 caen) y
  `verificado-en-commit-test.sh` (+5 casos del segmento del revisor). Los dos en `coverage-index`.

## Fuera

- El selector no escribe `ultimo_disparo` en el YAML: sería cambiar las reglas desde el PR. Los ids
  quedan en el cuerpo de cada PR; los cuenta P5.
- El revisor no corre en el CI: es local, como la interfaz de lo tocado (sin runner macOS pagado).
