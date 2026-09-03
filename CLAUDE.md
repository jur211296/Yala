# Yala (iOS)

Yala es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

## Stack

- Swift, SwiftUI, SwiftData (.xcodeproj)
- **Target iOS 26+** — APIs nativas (Liquid Glass, ToolbarSpacer, etc.)
- Schemes: **Yala** (producción) | **Yala Dev** (con toggle Pro y `DEV_BUILD`) | Tests: YalaTests
- Simulador: **iPhone 17 Pro**
- 21 SwiftData models. ModelContainer via `SwiftDataConfiguration`. Divisas SSOT en `Yala/Utils/CurrencyUtils.swift` (`CurrencyCode`, 48 divisas).

## Docs (leer cuando sea relevante)

| Archivo | Propósito |
|---------|-----------|
| `docs/ESTADO.md` | Qué está en curso (NOW) |
| `docs/HANDOFF.md` | Traspaso de sesión |
| `docs/DECISIONS.md` | Registro de decisiones |
| `docs/TICKETS.md` | Índice + schema de tickets |
| `docs/sessions/` | Sesiones vivas; las obsoletas van a `docs/sessions/_archive/` |
| `tickets/` | Tickets vivos (`backlog` · `in-progress` · `qa` · `done` · `blocked` · `discarded`) |
| `qa/README.md` | QA automatizado (suites y scripts) |
| `marketing/` | Árbol vivo de marketing (ficha App Store + screenshots). `Web/` queda en la raíz. |

La SSOT de proceso y tickets es **este repo**. No uses Obsidian / YalaWiki como fuente de verdad. Skills: `/backlog`, `/spec`, `/idea`.

## General Rules

- Hacer SOLO los cambios explícitamente solicitados. No mover UI, refactorizar adyacente, ni añadir mejoras no pedidas.
- Antes de editar, listar archivos a modificar y qué cambia. Esperar aprobación si son más de 3 archivos.
- Confirmar que rutas referenciadas existen antes de proceder. Si no, preguntar al usuario.
- Evitar refactors grandes innecesarios. No introducir dependencias nuevas sin justificación.
- Mantener separación UI / lógica / SwiftData.

## Reglas inviolables

### Errores y unwraps
- NUNCA `try?` que silencia. Usar `do { try } catch { print("Service: Error: \(error)") }`.
- NUNCA force unwraps sin validación previa (`guard let x = ... else { return }`).
- Logs SIEMPRE dentro de `#if DEBUG` — nunca datos sensibles en producción.
- API keys: NUNCA hardcodear. Usar `Secrets.xcconfig` + `Info.plist` via `Bundle.main.object(forInfoDictionaryKey:)`.


### Cálculos con fechas

- **`DateInterval` es CERRADO en ambos extremos (`start` Y `end` inclusivos)** — al construir un `end` que coincide exactamente con el `start` de otro período/bucket adyacente (ej. `DateInterval(start: startOfLastMonth, end: startOfThisMonth)`), ese instante compartido se cuenta en AMBOS lados: `.contains(_:)` devuelve `true` para los dos, y con predicados manuales (`date >= start && date <= end`) el mismo double-count. Ocurre en la práctica porque `DatePicker(displayedComponents: [.date])` normaliza la hora elegida a medianoche exacta (00:00:00) — una transacción fechada "1 de julio" cae en `.lastMonth` (junio) en vez de solo `.thisMonth`. **Fix**: restar 1 segundo al `end` cuando representa "hasta el inicio de X, sin incluir X" (`calendar.date(byAdding: .second, value: -1, to: startOfX)`). Costó el bug de "Mes/Año pasado incluye día 1 del actual" replicado en 4 archivos independientes (`DetailPeriod.dateInterval()` en `SharedModels.swift`, su mirror en `WidgetDataService.swift`, `PreviousPeriodHelper.previousPeriodInterval` [ancla en `.end` que cambia → re-anclar en `.start`, invariante], y `FullFinancialContextBuilder.buildIntervals` [cadena de buckets adyacentes `lastMonth`/`twoMonthsAgo`/`threeMonthsAgo`/semanas] + `ReportNotificationService.getIntervalForReportType`). Al añadir un período/bucket nuevo con boundary en medianoche, verificar el mismo patrón.

- **Corolario, medido el 2026-09-02: «el fichero está en la lista de arreglados» NO significa que lo estén todas sus ramas.** `PreviousPeriodHelper` ya figuraba arriba como corregido y sin embargo su rama `.thisMonth` (y `sameIntervalPreviousYear`) seguían sin restar el segundo: una TX del día 1 a medianoche contaminaba la columna «anterior» del informe **los 730 días barridos**, el hero de Estadísticas 28/730 y la comparativa interanual 2/730. Al revisar este patrón, recorre **todas las ramas del switch**, no el fichero. Y busca las instancias **escritas a mano fuera del helper**: aparecieron dos (`AnomalyDetectionCalculator`, donde la TX entraba en su propia línea base y apagaba su detección de anomalía, y el `prevInterval` del hero en `PanelViewModel`). Dos avisos más: (1) **el `-1s` no siempre es incondicional** — una función compartida por períodos EN CURSO (cierran en medianoche) y CERRADOS (ya cierran en 23:59:59) debe condicionarlo (`calendar.startOfDay(for: end) == end`), o les quita un instante real; (2) **su trampa gemela es contar días**: `dateComponents([.day])` TRUNCA, así que sobre un intervalo que cierra en 23:59:59 devuelve uno de menos — normaliza (`end.addingTimeInterval(1)`) antes de contar, o el denominador de cualquier promedio diario se queda corto.

### Documentation & copy
- Describir features desde la perspectiva del USUARIO, no técnica.
- NUNCA fabricar features — solo lo confirmado en scope.
- Copy nuevo: leer BRAND-VOICE.md.


> Las reglas de área viven en `.claude/rules/` y se cargan solas al tocar los archivos
> que les corresponden: `swiftdata-cloudkit.md` · `swiftui-ds.md` · `l10n.md` · `testing.md`.
> No las repitas aquí: duplicarlas es como divergen.

## Workflow

```
Captura → Diseño → Construcción → Gate → Commit → QA → Cierre
 /idea     /spec      (sesión)    /gate  /commit-one  /qa   /cerrar
        + Plan Mode
        + /review-plan
```

- **`/spec`** desarrolla el plan dentro del ticket en `tickets/`. Luego **Plan Mode + `/review-plan`** — su sección de "Diferidos" es lo que evita el retrabajo; no la saltes.
- **Construcción**: sesión larga y autónoma. `/verify-ios` para el bucle corto de «¿compila?».
- **Review adversarial** (varias lentes independientes + refutación por hallazgo) cuando el cambio toque lógica densa donde un bug sale caro: sync/race (CKShare, bridges, notificaciones), cálculos financieros, migraciones SwiftData, bridge SplitExpense ↔ TransactionItem. Para l10n, rebranding o polish visual no aporta.
- **`/gate`** antes de commitear: build ×2, unit, XCUITest de las áreas tocadas, audit y validación del índice. Sella el árbol; el hook de pre-commit comprueba ese sello.
- **`/qa`** es por lotes: una sesión drena varios tickets `qa_`, no uno.
- **`/cerrar`** al terminar: nada abierto, ticket sincronizado y disco liberado.

### Dónde se commitea (2026-09-01)

La rama depende de **dónde corre la sesión** —comprobable con un comando— no de quién llegó antes:

| Dónde corre | Cómo entrega |
|---|---|
| **Árbol principal** (`~/Yala`) | Commit directo en `2.1`. Sin rama y sin PR, **también para código**. |
| **Worktree** (`lanzar-sesion`, Grokbot) | Rama + PR, siempre. |

Se comprueba con `git rev-parse --git-common-dir`: si devuelve algo distinto de `.git`, es worktree. «Quién está trabajando primero» NO es comprobable y por eso no es el criterio: dos sesiones que arranquen a la vez se creerían ambas la primera.

Dos condiciones innegociables para commitear directo en `2.1`:

1. **`/gate` en verde.** Sin PR, el gate es la única red que queda. Si no pasa, no hay commit.
2. **El árbol es tuyo.** Si `git status` trae cambios que no son de esta sesión, parar y avisar. Dos sesiones sobre el mismo árbol se arrastran y el aislamiento por hunks no funciona.

**Sin nada que compilar** —diffs que caen ENTEROS en `docs/` · `tickets/` · `marketing/` · `Web/` · `.github/` · `README.md` · `CLAUDE.md` · `LICENSE*`— va directo a `2.1` **desde cualquier sesión**, worktree incluido, y el gate salta a la validación del índice.

Esta lista **ya no es** «la del job `changes` de `.github/workflows/qa.yml` menos `.claude/`». Las dos responden preguntas distintas —«¿hay que compilar antes de commitear?» aquí, «¿puede este diff romper el build?» allí— y divergen en dos sitios, los dos a propósito:

- **`.claude/` está aquí fuera y allí dentro.** Hooks, rules y permisos no rompen el build —por eso el CI los deja pasar— pero cambian cómo trabaja todo el mundo, así que van por PR.
- **`.github/` está aquí dentro y allí fuera** (2026-09-03). En local no hay nada que compilar, así que el gate no aporta; en CI un cambio al workflow **tiene** que disparar la suite, o el CI dejaría de probar sus propios cambios — que es justo lo que hay que evitar después de un día ejecutando cero tests.

**El release sigue siendo de Jürgen**, y un PR abierto lo mergea él salvo que pida otra cosa. Lo que desaparece es el PR como trámite para el trabajo de una sesión única, no su criterio.

**Documentación: dos superficies, no cinco.** El ticket en `tickets/` (qué y por qué, mientras el trabajo vive) y la regla durable en `.claude/rules/` (lo que el yo-futuro no debe romper). Git ya guarda el qué y el cuándo; `docs/ESTADO.md` y `docs/DECISIONS.md` son narrativa de proceso, no bitácora de cada commit.

**Regla QA (contrato anti-drift):** la SSOT de cobertura es `qa/coverage-index.json` (validar: `bash qa/validate-coverage.sh`). Al tocar código bajo `Yala/`, en el MISMO commit actualizar el área correspondiente (`coverage`, `lastVerified`). Cobertura por clasificación: `deterministic` → XCUITest en `YalaUITests`; `agentic` → `/qa`; `manual` → documentada. El **ratchet** BLOQUEA si el backlog determinista crece respecto a `_meta.backlogBaseline` — escribe el test o baja el baseline conscientemente.

## Corrección de errores

- SIEMPRE buscar TODAS las instancias del mismo patrón antes de declarar un fix completo.
- NO confiar en "BUILD SUCCEEDED" — verificar los casos.
- **Antes de culpar al código, mira el entorno.** Si los XCUITest fallan al lanzar (`RequestDenied`, `xctrunner`), si el simulador se apaga solo o si un build se cuelga: `bash qa/scripts/disk-report.sh`. Con el disco lleno CoreSimulator falla con errores que no mencionan el disco. Ese diagnóstico ya costó 11 días una vez.
- Una hipótesis de la Lista Negra **caduca**: si el entorno cambió (versión de Xcode, de macOS, del runtime), vuelve a comprobarla antes de darla por buena.
- **En este repo la documentación envejece más rápido que el código: MIDE antes de obedecerla.** Una coordenada, un conteo, un «rojo conocido, no lo persigas» o un «esto queda inalcanzable» son **afirmaciones verificables**, y comprobarlas cuesta un grep. La sesión del 2026-08-06 lo pagó cuatro veces: una premisa que justificaba trabajo manual del owner era falsa (el store de Grupos es `cloudKitDatabase: .none`, así que nada quedaba «inalcanzable»); un «rojo conocido» del punto de control llevaba **seis días** cerrado en su fuente, e invitaba a ignorar un test que hoy es una red viva; un conteo de un informe era en realidad un valor POST-commit; y tres coordenadas de un informe apuntaban a líneas anteriores al propio commit que las medía. ⇒ **cuando un documento te diga «no mires aquí», mira; y cuando te dé una cifra que vas a reusar, re-mídela.** Corolario al escribir: distingue lo que MEDISTE de lo que INFERISTE, y si citas una línea, cítala del árbol en el que estás.

## Self-Maintenance

Al modificar modelos / servicios / ViewModels: los gotchas nuevos van al fichero de `.claude/rules/` de su área, no a este archivo. Preferencias nuevas (`UserDefaults`): checklist en las rules de área (no hay CODEBASE-MAP en este repo).

## Control de Ejecución

Tras implementar: resumen **en lenguaje de usuario** (qué cambia para él), build para confirmar, sugerir el siguiente paso y **detenerse**. No encadenar tests, QA ni commits sin que los pida.

**Git:** cada comando de lectura una sola vez, secuencialmente. No matar shells con git en curso.

**Tags:** semver con prefijo `v` → `v1.0.0`. Nunca sin prefijo ni sin 3 componentes.
