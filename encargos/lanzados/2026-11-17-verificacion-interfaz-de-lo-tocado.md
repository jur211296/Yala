Yala
# Las pruebas de interfaz de lo tocado corren en cada PR, elegidas por un script
---
toca: qa/scripts/interfaz-de-lo-tocado.py,qa/scripts/interfaz-de-lo-tocado-test.sh,qa/coverage-index.json,.github/workflows/qa.yml,.claude/commands/gate.md,.claude/rules/ci-qa.md,.claude/rules/testing.md,tickets/done/2026-11-17-verificacion-interfaz-de-lo-tocado.md
esfuerzo: high
cierre: cierra-sola
---

## Qué hay que hacer (P2)
Hoy la sesión elige a mano qué clases de interfaz corre en su gate (paso 3 de `.claude/commands/gate.md`, cruzando el diff con `codeGlobs` de `qa/coverage-index.json`) y el CI del PR no corre ninguna (job `ui` solo en `schedule`/`workflow_dispatch`). Así llegaron 11 rotas a 2.3 (el PR de categorías a un toque corrió 6 clases y rompió 3 más que abren «Nuevo registro»).

- `qa/scripts/interfaz-de-lo-tocado.py`: lee el diff contra `origin/2.3` y devuelve las clases de `YalaUITests` que pasan por las pantallas tocadas, por las áreas del índice de cobertura y por los identificadores de accesibilidad de esas vistas que usan las pruebas. Tiene techo configurable y siempre dice qué dejó fuera y por qué (un cambio en `ContentView` no puede pedir 200 clases sin avisar).
- Banco de pruebas con casos reales: el PR de categorías a un toque (#920) debe devolver las 4 clases que rompió el 16-nov; documenta qué devuelve para los 7 rojos del 12 al 14-nov.
- El paso 3 de `/gate` usa el script en vez de la mano.
- Job nuevo en el PR que corre esas clases en el runner del CI, en modo **observar** dos semanas: resultado visible en el PR, sin bloquear. Mide minutos de runner por PR y déjalos en el artifact. Pasa a obligatorio (entra al ruleset de 2.3 como los unit el 10-oct) el 1-dic-2026 en una sesión corta aparte; no toques el ruleset ahora.
- Va después de la sesión «Cuarentena de pruebas inestables con dueño y línea «Verificado:» en cada commit» (comparten `qa.yml` y `gate.md`): parte de `2.3` con ese PR mergeado.
- Ticket en `tickets/done/2026-11-17-verificacion-interfaz-de-lo-tocado.md`.

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

> Resueltas por la sesión (modo semi, ninguna es vital): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué son «las 4 clases que rompió el 16-nov»?** → Medido en los logs de la nocturna del 16-nov (run 43929672868): 4 casos rojos 3/3 en 3 clases (`SplitCalculatorUITests` ×2, `AccountCardPickersUITests`, `PersonalToGroupConversionUITests`). El ticket atribuye a #920 solo las dos primeras; la tercera es un desplazamiento de Registros. El banco exige para #920 las dos que rompió más las cuatro que el ticket pide como mínimo (`SplitCalculator`, `AccountCardPickers`, `TransactionFormDecided02`, `EdgeCases`), y documenta qué hace con `PersonalToGroupConversion`.
Por qué: el encargo dice «4 clases» pero lo medido son 4 casos en 3 clases. Alternativa descartada: inventar una cuarta clase rota.

**D2 · ¿Cómo elige el script?** → Seis capas por fuerza: prueba tocada, ayudante de `Support/` tocado (por miembro), índice de cobertura (globs anchos degradados), identificadores declarados en lo tocado (exactos y prefijos interpolados, directos o vía ayudante), textos en español que cambian, y vistas anfitrionas (hasta dos saltos). Dentro de cada capa, especificidad `1/n` por identificador.
Por qué: el índice solo no une #920 con las rotas; los identificadores de `NewTransactionView.swift` sí. Alternativa descartada: solo índice (es lo que falló) o todo lo que use cualquier identificador sin orden (un `ContentView` pediría la suite).

**D3 · ¿Techo?** → Por minutos estimados con `qa/ci-ui-tiempos.json` (46 s/caso sin dato), 30 min por defecto, configurable (`--techo-min`, `UI_TOCADO_TECHO_MIN`, `--techo-clases`). Lo de fuera sale listado con capa, motivo y minutos.
Por qué: el coste por clase va de 1 a 12 min; un techo por número no acota el runner. Alternativa descartada: techo por clases.

**D4 · ¿El job del PR compila solo o reusa el build de `tests`?** → Dos jobs nuevos: `ui-tocado-plan` en ubuntu (el script, gratis, decide si hace falta macOS) y `ui-tocado` en `xcode-27` con su propio build, en paralelo a `tests`, solo si el plan trae clases.
Por qué: no toca el job `tests` (check requerido, y el PR de cuarentena lo está cambiando) y no alarga la señal del PR. Alternativa descartada: subir el build desde `tests` (ahorra ~15 min de macOS por PR pero mete un paso nuevo en un check requerido y serializa).

**D5 · ¿Observar cómo?** → El job no entra al ruleset (no se toca) y no lleva `continue-on-error`: su rojo se ve en el PR y no frena el auto-merge, que solo espera a los checks requeridos. Sin `-retry-tests-on-failure`: en observar se quiere el dato crudo de inestables. Fuera del `aviso`.
Por qué: un check no requerido ya es «visible sin bloquear»; un `continue-on-error` lo pintaría verde y escondería el dato. Alternativa descartada: reintentar (es lo que P1 acaba de llamar «un rojo rescatado no es verde»).

**D6 · ¿El script del CI se lee del PR o de la base?** → De la base (`HEAD^1`) si allí existe; si no (este PR), del propio PR, y el log dice cuál.
Por qué: un PR no debería poder adelgazar su propia selección; P2 no lo exige pero cuesta dos líneas. Los cambios al script los prueba su banco en `coverage-index`.

**D7 · ¿Minutos de runner?** → Se miden en el job (build, simulador, pruebas) y van en el artifact `ui-tocado` y en el resumen del job. Con el techo de 30 min: ~20 de build + ≤30 de interfaz por PR con pantalla tocada. El repo es público (minutos gratis); el coste real es la cola de `macOS`, y se dice en el cierre.
Por qué: P2 aprobó el riesgo «minutos de runner y cola» como medio. No es «fuera de lo razonable»: no se pregunta.

**D8 · Banco** → Sintético (mini-árbol en temporal, cada capa y el techo) + casos reales: árbol del commit de merge de cada PR (#920 y los 7 rojos del 12 al 14-nov: #921, #950, #917, #902 ×2, #918, #919) extraído con `git archive`. Los reales necesitan historia: si el commit no está, el banco lo trae con `git fetch --depth=2`; si no puede, falla (no salta).
Por qué: un caso real que se salta en silencio es el hueco que esto viene a cerrar.

**D9 · Promoción a obligatorio** → No se toca el ruleset. Fecha (1-dic-2026) y criterio quedan escritos en `ci-qa.md` y en el ticket.

**D10 · Respuesta de Jürgen a D7 (17-nov): NO hay presupuesto de runner macOS.** No se agrega el job del PR; D4, D5, D6
y D7 quedan sin efecto. El script se queda y lo usa solo el gate local (paso 3), con techo de 30 min. El banco sigue en
`coverage-index` (ubuntu, gratis) y fija el PR de categorías a un toque con techo 30 (una de las dos dentro) y 40 (las dos).
