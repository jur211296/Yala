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
| `$VAULT/planning/CODEBASE-MAP.md` | Tablas de Services / Calculators / ViewModels / Tests con paths |
| `$VAULT/planning/UI-PATTERNS.md` | Design System, gotchas de SwiftUI, formularios, glass |
| `$VAULT/planning/SWIFT-STYLE.md` | ViewModel pattern, idioms modernos, DS.Semantic / DS.Gradients, "añadir preferencia" |
| `$VAULT/planning/L10N.md` | 16 locales, workflow para añadir keys, tests CI |
| `$VAULT/planning/DEVICE-QA.md` | Setup Yala Dev, simulador y automatización de UI |
| `$VAULT/planning/BRAND-VOICE.md` | Tono y estilo de marca |
| `$VAULT/planning/WORKFLOW.md` | Workflow detallado de skills |
| `$VAULT/planning/PROJECT.md` · `ROADMAP.md` · `STATE.md` | Producto, plan, progreso |
| `$VAULT/planning/DECISIONS.md` | Registro de decisiones arquitectura |
| `$VAULT/planning/QA-SCENARIOS.md` | Escenarios de prueba |
| `qa/README.md` | QA automatizado (suites y scripts) |

`$VAULT` = `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki/` (Obsidian, sync vía iCloud).

Carpetas del vault: `Backlog/` · `Ideas/` · `Bugs/` · `Attachments/` · `planning/`. Skills: `/backlog`, `/spec`, `/idea`.

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

- **`/spec`** desarrolla el plan dentro del ticket del vault. Luego **Plan Mode + `/review-plan`** — su sección de "Diferidos" es lo que evita el retrabajo; no la saltes.
- **Construcción**: sesión larga y autónoma. `/verify-ios` para el bucle corto de «¿compila?».
- **Review adversarial** (varias lentes independientes + refutación por hallazgo) cuando el cambio toque lógica densa donde un bug sale caro: sync/race (CKShare, bridges, notificaciones), cálculos financieros, migraciones SwiftData, bridge SplitExpense ↔ TransactionItem. Para l10n, rebranding o polish visual no aporta.
- **`/gate`** antes de commitear: build ×2, unit, XCUITest de las áreas tocadas, audit y validación del índice. Sella el árbol; el hook de pre-commit comprueba ese sello.
- **`/qa`** es por lotes: una sesión drena varios tickets `qa_`, no uno.
- **`/cerrar`** al terminar: nada abierto, ticket sincronizado y disco liberado.

**Documentación: dos superficies, no cinco.** El ticket del vault (qué y por qué, mientras el trabajo vive) y la regla durable en `.claude/rules/` (lo que el yo-futuro no debe romper). Git ya guarda el qué y el cuándo; `STATE.md` y `DECISIONS.md` son narrativa histórica, no bitácora de cada commit.

**Regla QA (contrato anti-drift):** la SSOT de cobertura es `qa/coverage-index.json` (validar: `bash qa/validate-coverage.sh`). Al tocar código bajo `Yala/`, en el MISMO commit actualizar el área correspondiente (`coverage`, `lastVerified`). Cobertura por clasificación: `deterministic` → XCUITest en `YalaUITests`; `agentic` → `/qa`; `manual` → documentada. El **ratchet** BLOQUEA si el backlog determinista crece respecto a `_meta.backlogBaseline` — escribe el test o baja el baseline conscientemente.

## Corrección de errores

- SIEMPRE buscar TODAS las instancias del mismo patrón antes de declarar un fix completo.
- NO confiar en "BUILD SUCCEEDED" — verificar los casos.
- **Antes de culpar al código, mira el entorno.** Si los XCUITest fallan al lanzar (`RequestDenied`, `xctrunner`), si el simulador se apaga solo o si un build se cuelga: `bash qa/scripts/disk-report.sh`. Con el disco lleno CoreSimulator falla con errores que no mencionan el disco. Ese diagnóstico ya costó 11 días una vez.
- Una hipótesis de la Lista Negra **caduca**: si el entorno cambió (versión de Xcode, de macOS, del runtime), vuelve a comprobarla antes de darla por buena.

## Self-Maintenance

Al modificar modelos / servicios / ViewModels: actualizar `$VAULT/planning/CODEBASE-MAP.md`.
Los gotchas nuevos van al fichero de `.claude/rules/` de su área, no a este archivo.
Preferencias nuevas (`UserDefaults`): checklist en SWIFT-STYLE.md.

## Control de Ejecución

Tras implementar: resumen **en lenguaje de usuario** (qué cambia para él), build para confirmar, sugerir el siguiente paso y **detenerse**. No encadenar tests, QA ni commits sin que los pida.

**Git:** cada comando de lectura una sola vez, secuencialmente. No matar shells con git en curso.

**Tags:** semver con prefijo `v` → `v1.0.0`. Nunca sin prefijo ni sin 3 componentes.
