Yala
# Un solo revisor con la checklist de confiabilidad en el gate, leído de 2.3
---
toca: qa/scripts/checklist-elegir.py,qa/scripts/checklist-elegir-test.sh,.claude/agents/revisor-checklist.md,.claude/commands/gate.md,.claude/rules/ci-qa.md,CLAUDE.md,tickets/done/2026-11-17-verificacion-revisor-checklist.md
esfuerzo: high
cierre: cierra-sola
---

## Qué hay que hacer (P4, segunda parte)
Va después de «Curar la checklist de confiabilidad con disparadores a partir de las reglas» y de «Las pruebas de interfaz de lo tocado corren en cada PR, elegidas por un script»: parte de `2.3` con los dos PR mergeados (necesita la checklist y comparte `gate.md`).

- `qa/scripts/checklist-elegir.py`: lee `qa/checklist-confiabilidad.yaml` **de `origin/2.3`** (un PR no puede cambiar las reglas que lo juzgan) y elige los 3 a 10 ítems cuyo disparador aparece en el diff.
- Paso nuevo en `/gate`: un solo revisor (`.claude/agents/revisor-checklist.md`) recibe el diff y esos ítems, y hace hasta tres rondas con la sesión antes de pedir ayuda. Nada de varios revisores en paralelo (el artículo y el dato del 14-nov dicen que rinde peor).
- Modo **observar**: el resultado del revisor queda en el PR y en el sello (se suma a la línea `Verificado:`), sin bloquear. Solo para lógica cara (nube, dinero, migraciones, formulario de registro).
- Ajusta `CLAUDE.md` donde hoy recomienda la revisión adversarial con varias lentes, para que apunte a este paso.
- Ticket en `tickets/done/2026-11-17-verificacion-revisor-checklist.md`.

## Contexto
Propuesta de verificación del 17-nov (comparación con el equipo de Claude Code), aprobada por Jürgen el 17-nov: «Apliquemos todo lo recomendado». Fuente en `origin/2.3`: `docs/verificacion/README.md` y `docs/verificacion/propuesta-2026-11-17.html` (array `PROPUESTAS`). Artículo de referencia: https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/ . Lee la propuesta correspondiente entera antes de empezar; las mediciones de ahí son tu punto de partida, pero vuelve a medir lo que cambies.

## Reglas
- Commits y PR sin firma de IA. PR hacia `2.3`. Rama desde `origin/2.3`; justo antes del PR, `git fetch` y un solo rebase.
- Dependencias: la sesión arranca sobre `origin/2.3`, sin esperar CI ni merge del PR anterior; solo espera el merge si toca los mismos archivos o necesita el código de otra sesión (se indica abajo cuando aplica).
- `toca:` acotado: si necesitas tocar un archivo fuera de la lista, anótalo en el cierre con el motivo.
- Simuladores: en la Max puedes usar un segundo simulador si otra sesión ocupa uno (tope 2); también el iPhone 14 conectado por DeviceMCP.
- Nada de reglas, scripts ni workflows del gate que se lean del propio PR cuando la propuesta dice «leído de 2.3»: se leen de `origin/2.3`.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital (accesos, credenciales, seguridad, ruleset distinto de lo aprobado, minutos de runner fuera de lo razonable) se pregunta, no se asume. Semi 05:30–20:00: preguntas y esperas con la sesión viva. Nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto.
- Si el trabajo queda completo y el modo lo permite, termina con `/cerrar-total`.
- Entregable: artifact visual de Claude (antes/después, qué se midió, qué queda en observar y cuándo se promueve).
- El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada una con motivo o «Nada», y una sección «Lección» si hubo un error evitable.

## Paso 0 — decisiones

> Resueltas por la sesión (semi): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** Al arrancar (12:40), los dos PR previos siguen abiertos en cola de auto-merge: la checklist (30 ítems, `qa/checklist-confiabilidad.yaml`) y la interfaz de lo tocado (cambia `gate.md` y `ci-qa.md`). Ninguno está en `origin/2.3`. Los 30 ítems tienen `rutas`; 6 son de `pruebas`. La Max no tiene PyYAML (el banco de la checklist lee el YAML con Ruby). `CLAUDE.md` l. 73 y `.claude/agents/frank.md` l. 68 recomiendan la revisión «con varias lentes».

**D1 · Dependencias.** Se construye sobre el contenido de los dos PR y se prueba el selector con `--reglas <rama de la checklist>`. Antes del PR, `git fetch` y un rebase; si el PR de la interfaz no ha entrado, se espera (toca `gate.md` y `ci-qa.md`, los mismos ficheros).

**D2 · Qué se lee de 2.3.** La checklist, el selector y las instrucciones del revisor (el cuerpo de `.claude/agents/revisor-checklist.md`, que el selector mete en el encargo del revisor). Si el diff toca alguno de los tres, el informe lo dice y se usan los de 2.3. Mientras el selector no esté en 2.3 (este mismo PR), el paso del gate se salta y lo dice. Descartada: usar el agente del árbol a pelo (un PR podría ablandar a su propio revisor).

**D3 · Disparo.** El contrato literal de la cabecera del YAML. El diff es el de la interfaz de lo tocado: `merge-base` con `origin/2.3` contra el árbol de trabajo, más los no versionados (el gate corre antes del commit).

**D4 · Tope y orden.** Máximo 10 ítems, ordenados por puntos (líneas que casan con símbolo o patrón; si el ítem solo tiene rutas, ficheros). Lo que pasa de 10 se lista como «fuera por el tope». No se rellena hasta 3: si disparan 2, van 2.

**D5 · Solo lógica cara.** El revisor corre si dispara al menos un ítem de nube, dinero, migración, fechas o formulario. `fechas` cuenta como dinero (son los cálculos de totales y períodos). Los de `pruebas` acompañan, pero no lo disparan solos.

**D6 · Rondas.** Un solo revisor. Ronda 1 con el encargo del selector; la sesión arregla o refuta cada hallazgo con evidencia; rondas 2 y 3 con `SendMessage` al mismo agente. Lo que siga sin acuerdo tras la 3.ª va al PR como «sin acuerdo» y a «Necesita de ti». Nunca varios revisores en paralelo.

**D7 · Observar.** No bloquea. El interruptor es la constante `MODO` del selector, leída de 2.3. El resultado va al cuerpo del PR (sección «Revisor con checklist») y al sello: `verificado-en-commit.sh sellar … --revisor N --hallazgos M --aceptados K` suma `revisor N ítems, M hallazgos, K aceptados` a la línea `Verificado:`. Sin revisor, sin segmento.

**D8 · `ultimo_disparo`.** El selector no escribe el YAML (sería cambiar las reglas desde el PR). Los ítems disparados quedan en el cuerpo del PR, de donde P5 los cuenta.

**D9 · Banco.** `checklist-elegir-test.sh` con un repo de mentira (sin depender de `origin/2.3`) y un paso en el job `coverage-index`.

**D10 · Fuera de `toca:`, con motivo.** `qa/scripts/verificado-en-commit.sh` y su banco (el segmento del revisor en la línea); `.github/workflows/qa.yml` (el banco en `coverage-index`); `.claude/agents/frank.md` (repite la recomendación de varias lentes que el encargo manda cambiar en `CLAUDE.md`); `docs/TICKETS.md` (índice al cerrar); este encargo (Paso 0).
