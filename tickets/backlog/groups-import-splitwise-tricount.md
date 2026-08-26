---
id: groups-import-splitwise-tricount
status: backlog
priority: medium
area: "groups, import"
created: 2026-07-02
updated: 2026-08-26
source: YalaWiki/Backlog/groups-import-splitwise-tricount.md
---


# Importar grupo desde CSV de Splitwise / Tricount

## Problema

Un grupo que migra de Splitwise o Tricount llega a Yala con historial: meses o años de gastos compartidos y, sobre todo, **saldos netos vigentes** ("Ana me debe S/120, yo le debo S/45 a Luis"). Hoy la única forma de traer eso es recrearlo a mano gasto por gasto, o resumirlo mentalmente en saldos iniciales manuales (`isOpeningBalance`, que ya existe como mecanismo). Ambas opciones son fricción pura en el momento más delicado del funnel: la cohorte entera está decidiendo si se muda o no.

Splitwise y Tricount permiten exportar el grupo (CSV en Splitwise; CSV/XLSX en Tricount). Un import de ese archivo al crear el grupo en Yala convierte "empezar de cero" en "seguir donde estaban" — diferenciador fuerte para capturar grupos completos.

**Depende de** `groups-onboarding-solo-grupos` (la entrada Solo Grupos sin invitación): sin ella, la cohorte Splitwise ni siquiera puede crear el grupo. Secuencia: entrada primero, import después. El import también sirve a usuarios de Yala completo que ya usan Grupos.

## Solución propuesta

En el flujo de crear grupo (o en settings de un grupo recién creado y aún vacío), ofrecer **"Importar desde Splitwise o Tricount"**: el usuario elige el archivo exportado, Yala lo parsea, muestra un preview (miembros detectados, rango de fechas, total de gastos, saldos netos resultantes) y el usuario confirma.

Dos modos de import a decidir (ver Preguntas abiertas #2 — posiblemente ambos, elegibles en el preview):

- **Solo saldos netos (v1 recomendada)**: calcular el balance neto por miembro desde el export y crear los `SplitExpense` con `isOpeningBalance = true` correspondientes. Mínimo volumen de records CloudKit, cero ruido en el historial, y el mecanismo ya existe de punta a punta (modelo, sync, UI de edición, exclusión de stats y notificaciones).
- **Historial completo**: crear un `SplitExpense` + `SplitShare`s por cada fila del export. Preserva el historial navegable pero multiplica el volumen a sincronizar por CKSyncEngine en el momento del onboarding (grupos Splitwise viejos pueden tener cientos de gastos) y arrastra el problema de mapear pagador/participantes por gasto a miembros que aún no se unieron.

## Estado actual confirmado en el código (2026-07-02)

- **Saldos iniciales de migración ya existen**: `SplitExpense.isOpeningBalance` (`Yala/Models/SplitExpense.swift:44`), creables vía `GroupExpenseService.createExpense(..., isOpeningBalance: true)` (`GroupExpenseService.swift:69`), con UI dedicada (`GroupMembersView.swift:295`, `GroupDetailView` sheets `editOpeningBalance`/`openingBalanceDetail`), excluidos de estadísticas (`GroupStatsViewModel.swift:181,264`) y de notificaciones (`GroupNotificationService.swift:175`), y en el schema CloudKit de Production (`CKRecordTranslator.swift:167`, desplegado — commit `5c1b5b4f`). **El modo "solo saldos netos" es mayormente parsing + UI encima de esto.**
- **Infraestructura de parsing CSV/XLSX ya existe** (para transacciones personales): `Yala/Utils/TransactionCSVImportService.swift` — detección de delimitador (`detectDelimiter`), split robusto de filas (`splitCSVIntoRows`, maneja quotes/multilinea), parsing de fechas multi-formato (`parseDate`), normalización de montos (`normalizeAmountString`) y divisas (`normalizeCurrencyInput`), multi-moneda (`scanCurrencies` + `importCSVMultiCurrency`), y XLSX (`XLSXReader.swift`). **No reusar el servicio entero** (está acoplado a `TransactionItem`/cuentas personales), pero sí sus helpers de parsing — evaluar extraerlos a un módulo común en vez de duplicar.
- **Restricción de modelo clave**: `SplitMember` (`Yala/Models/SplitMember.swift`) solo tiene estados `active`/`pendingApproval`/`rejected` y está ligado a identidad iCloud real. **No existe el concepto de miembro "fantasma"** (persona del export que aún no se unió a Yala). Esto condiciona todo el diseño (ver Preguntas abiertas #1).
- `GroupExpenseService.createExpense` invoca automáticamente el bridge personal (`GroupTransactionBridge.bridgeExpense`) para cada gasto creado — un import de historial completo dispararía N bridges. Verificar si `isOpeningBalance` lo excluye o si se necesita gatear (relevante para el volumen y para no inundar el Inbox/cuentas del importador).

## Preguntas abiertas de diseño (resolver en `/spec` antes de implementar)

1. **Miembros que aún no se unieron** — la pregunta central. El export trae nombres ("Ana", "Luis") sin identidad iCloud. Opciones:
   - (a) **Miembros placeholder**: nuevo estado/flag en `SplitMember` (ej. `isPlaceholder` + `displayName` del export, sin `userRecordName`), con "claim" al unirse la persona real (matching por nombre elegido en el invite onboarding, o asignación manual por el owner: "este que se unió es Ana"). Toca el schema CloudKit de grupos (append-only, deploy a Production) y toda la lógica que asume identidad real (`currentUserMember`, balances, settlements, notificaciones).
   - (b) **Import diferido**: el owner crea el grupo, invita, y el import de saldos se ofrece cuando todos ya se unieron (mapeo nombre-export → miembro real en el preview). Cero cambios de schema, pero la migración no es instantánea (fricción: "invita a los 5 primero").
   - (c) **Híbrido**: importar YA los saldos como opening balances "sin asignar" y asignarlos a medida que la gente se une. Complejidad intermedia.
   - La opción (b) es la más barata y honesta para v1; (a) es la mejor UX pero es un cambio estructural del subsistema de Grupos.
2. **¿Solo saldos netos, historial completo, o ambos?** Recomendación v1: solo saldos netos (ver Solución). El historial completo puede ser v2 si hay demanda real — medir con telemetría cuántos imports se hacen.
3. **Formatos de export a soportar** (validar con archivos reales en `/spec`):
   - Splitwise CSV: filas de gastos con columnas `Date, Description, Category, Cost, Currency` + una columna por miembro con su parte neta (positiva = puso dinero, negativa = debe); última fila "Total balance" con los saldos netos. El parsing de saldos netos puede leer directo esa fila.
   - Tricount: export CSV/XLSX con estructura distinta (validar con un export real; también existe compartir por link, fuera de scope).
   - Detección automática de formato por headers vs selector manual de origen.
4. **Multi-moneda**: un grupo Splitwise puede tener gastos en varias divisas; el grupo Yala tiene una divisa principal. ¿Convertir al importar (con qué tasa histórica), importar solo la divisa dominante, o rechazar exports multi-moneda en v1? `TransactionCSVImportService` ya resolvió este problema para lo personal (`importCSVMultiCurrency`) — revisar su UX antes de decidir.
5. **Pagos/settlements en el export**: Splitwise incluye filas "Payment" (liquidaciones). Si se importan solo saldos netos, ya vienen descontados. Si se importa historial, ¿mapear a `SplitSettlement` o a gastos normales?
6. **Idempotencia y límites**: ¿qué pasa si importan dos veces el mismo archivo, o si el grupo ya tiene gastos? Recomendado: import solo disponible en grupos sin gastos reales (los opening balances manuales existentes se reemplazan con confirmación).
7. **Dónde vive el parsing**: pure-logic testeable (`SplitwiseImportParser` / `TricountImportParser` en `Yala/App/Logic/` o `Utils/`), sin SwiftData — recibe el contenido del archivo, devuelve un struct neutro (`ImportedGroupSnapshot`: miembros, gastos, saldos netos por nombre). La creación de records es una capa aparte sobre `GroupExpenseService`.

## Acceptance Criteria (draft — afinar en `/spec` tras resolver las preguntas)

- [ ] Desde el flujo de crear grupo (o un grupo vacío), el usuario puede elegir un archivo de export de Splitwise o Tricount.
- [ ] Preview antes de confirmar: miembros detectados (con su mapeo a miembros reales del grupo), saldos netos resultantes por persona y divisa, y qué se va a crear.
- [ ] Al confirmar, los saldos quedan como opening balances (`isOpeningBalance`) visibles en la sección existente de saldos iniciales del grupo, y el balance del grupo refleja las deudas migradas.
- [ ] Archivos malformados o de formato no reconocido → error claro y localizado, sin import parcial (todo-o-nada).
- [ ] Importar no dispara notificaciones a los miembros (los opening balances ya están excluidos) ni inunda el Inbox del importador vía el bridge.
- [ ] Re-importar sobre un grupo que ya tiene datos está protegido (bloqueado o con confirmación de reemplazo, según decisión #6).
- [ ] Tests pure-logic de los parsers con fixtures reales de Splitwise y Tricount (incluyendo edge cases: quotes, multilinea, multi-moneda, filas Payment, locales con coma decimal).
- [ ] `/verify-ios` verde y `qa/coverage-index.json` actualizado (parsing `deterministic` con XCUITest/unit; flujo e2e `agentic`).

## Referencias

- Ticket prerequisito: `groups-onboarding-solo-grupos` (entrada Solo Grupos sin invitación).
- `Yala/Models/SplitExpense.swift:44` + `Yala/Services/Groups/GroupExpenseService.swift:69` — mecanismo `isOpeningBalance` existente.
- `Yala/App/Views/Groups/GroupMembersView.swift:295` — UI actual de saldos iniciales.
- `Yala/Utils/TransactionCSVImportService.swift` + `Yala/Utils/XLSXReader.swift` — helpers de parsing a reutilizar/extraer.
- `Yala/Models/SplitMember.swift` — estados de miembro (sin placeholder hoy).
- Investigación de la sesión 2026-07-02 (flujo Solo Grupos + precondiciones de grupos).

migrated from YalaWiki Backlog/groups-import-splitwise-tricount.md @ 1934e8ad
