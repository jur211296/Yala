# Tarjeta con varias divisas, entrega 4: informes, flujo de caja y exportación por tarjeta

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Contexto
Jürgen aprobó el 16-oct (22:38) la cola de cards de 2.2, y la tarjeta multidivisa va primero, en cuatro entregas en orden 1→2→3→4 (obligatoria en 2.2, decisión del 13-oct). Ya están en 2.2: la entrega 1 (PR #547, el enlace «línea en otra divisa» en el modelo, iCloud y Modo Nube), la entrega 2 (PR #548, la tarjeta con sus líneas en el Panel, la ficha, Ajustes y el formulario) y la entrega 3 (PR #549, mergeado hoy: se elige la tarjeta y la divisa del importe decide la línea; `AccountCardLogic.route`, `AccountCardLogic.shownSelection`, `Budget.spendingAccountIDs`, filtros de sesión normalizados, seed `-uitest-seed tarjeta-dos-lineas`). Esta es la entrega 4, la última: informes, flujo de caja, exportación y contexto de IA por tarjeta.
- Card: `tablero-tarjeta-con-varias-divisas-entrega-4-inf-dbxp`. Muévela a in progress al empezar y a done al cerrar (`--agente frank`); si algo queda para probar en el iPhone, a in qa asignada a `jurgen` con el guion en la nota.
- Ticket con el alcance completo: `tickets/backlog/multi-currency-accounts-4-reports-and-export.md` en origin/2.2 (puntos 1 a 6; los 5 y 6 los añadió la entrega 3 hoy). Comprueba rutas y números de línea contra el código de hoy. Decisiones de Jürgen: `tickets/backlog/multi-currency-accounts.md` y `docs/multi-currency-accounts-impact-2026-10.md`, secciones 2.3, 2.9 y 4-6. Lee también el ticket y el cuerpo del PR de la entrega 3 (`tickets/qa/multi-currency-accounts-3-pickers-and-capture.md`, PR #549).
- Al cerrar esta entrega se cierra la tarjeta multidivisa: mueve el ticket paraguas `multi-currency-accounts.md` según corresponda y dilo en el PR.

## Qué se pide
Los puntos 1 a 6 del alcance del ticket:
1. Tabla de informes agrupada por cuenta (`PivotTableCalculator`): por tarjeta (líneas convertidas a la divisa preferida, con «≈») o por línea (cada una en su divisa), sin sumar en crudo.
2. Flujo de caja por cuenta (`TrendsTabView`): por tarjeta o por línea, con la misma regla.
3. Export CSV (`TransactionsExportService`): columna nueva con la tarjeta a la que pertenece la cuenta del movimiento (vacía si no es línea de nada); el filtro de divisas del asistente ofrece las divisas de todas las líneas al elegir la tarjeta.
4. Contexto del chat de IA (`FullFinancialContextBuilder`): describe la tarjeta con sus líneas, no como cuentas sueltas.
5. El conector de Claude (`mcp/`): portar la regla de `Budget.spendingAccountIDs` (leer `parent_account_id`) y añadir una tarjeta con líneas al golden de `MCPAppParityGoldenTests`.
6. El filtro de cuentas del asistente de exportación (`ExportFiltersStepView`): la tarjeta sale una vez, como en el resto de filtros, y excluye las cuentas de sistema.

## Qué NO hay que tocar
- Las vistas de la tarjeta (entrega 2) y la captura (entrega 3), salvo lo que haga falta para reutilizar su lógica. Los informes que ya agrupan por divisa de la transacción (saldo total, Estadísticas, Tendencias) no se tocan. Cuentas de una sola divisa: sin líneas, todo sigue igual.
- La edición en lote que mueve movimientos a otra cuenta (ya tiene su ticket aparte).
- Nada de despliegues a producción (ni CloudKit Production, ni Supabase de producción, ni el Worker de producción, ni publicar el conector MCP). Si hiciera falta esquema nuevo, déjalo listo, crea su card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, ni `Yala--qa-guiado-2-1-tf17`.

## AUTONOMÍA (fin de semana)
Jürgen no está en el escritorio. Si sale una duda reversible, elige la opción recomendada, impleméntala y anótala en la card y en el PR («Decidido por la sesión: …, porque…»). Para el diseño visual sigue el sistema de diseño y los componentes que ya usa Yala y lo que dice el ticket; si dudas entre variantes, elige la más coherente con lo que dejaron las entregas 2 y 3, y deja las capturas para que Jürgen la revise. Lo irreversible (esquema de producción, borrar datos, cobros) queda para Jürgen, sin parar la sesión.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- Texto nuevo de usuario en los 16 idiomas de la app, con `/l10n-check` en verde y sin nombrar a «OpenAI».
- Todo ticket nuevo lleva su card.
- Prueba según /barrido-qa lo que aplique: tests de la tabla de informes y del flujo de caja por tarjeta y por línea (con conversión y «≈»), del CSV con la columna de tarjeta, del filtro del asistente de exportación, del contexto de IA, `MCPAppParityGoldenTests` con la tarjeta en el golden y los tests del conector `mcp/`, y un XCUITest con el seed `tarjeta-dos-lineas` donde haya pantalla.
- Capturas de antes y después de la tabla de informes por cuenta, el flujo de caja por cuenta y el asistente de exportación (con Dynamic Type grande y modo oscuro donde aplique) en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, y con sus rutas en el resumen de cierre.
- Cierra con /cerrar-total.

## Cómo se sabe que está bien
El criterio de hecho del ticket cumplido, `/gate` y la suite de `YalaTests` en verde, los tests del conector en verde, y el PR contra 2.2 explicando en lenguaje de usuario qué ve ahora y que la tarjeta multidivisa queda completa.

## Paso 0 (2026-10-18, Frank, sesión autónoma)

Medido antes de escribir, contra origin/2.2 (`0a752eb06`):

- **Las coordenadas del ticket se movieron.** El contexto de IA ya no está en `FullFinancialContextBuilder.swift:350-357`
  sino en `buildBalances` (`:439-473`); el flujo de caja por cuenta, en `TrendsTabView.swift:1634-1648` y `:1741-1755`.
- **Hoy la tabla de informes ya es «por línea»**: agrupa por nombre de cuenta, suma en nativo y rotula con la divisa del
  primer movimiento. Con una tarjeta salen dos filas, cada una en su divisa. Lo que falta es la vista «por tarjeta».
- **El CSV que exporta Yala por defecto NO se reimporta hoy** (`TransactionCSVImportService.swift:316-331` exige la
  cabecera exacta `date,amount,currency,category,subcategory[,tags][,note]`; la columna `account` ya la rompe). El
  criterio «reimportar sigue funcionando» se lee como «no empeora»: va con su ticket aparte.
- **El filtro de cuentas de Registros sí enseña las cuentas de Grupos** (`RecordsFiltersViewModel.activeAccounts`); los
  que las excluyen son los selectores (presupuesto, programados, captura).
- **El conector `mcp/` solo apunta a staging** (`wrangler.toml`: `yala-mcp-staging`), donde la columna
  `parent_account_id` ya existe (g18_01 aplicado y sondeado). El rol `yala_mcp_reader` tiene SELECT a nivel de tabla.

Decidido por la sesión (reversible, sin Jürgen delante):

1. **Informes y flujo de caja: un selector «Por tarjeta · Por línea»**, el mismo componente en los dos sitios. Solo sale
   con la agrupación por cuenta puesta (informes) o la vista por cuenta (flujo de caja), y solo si hay alguna tarjeta con
   líneas. Por defecto, «Por tarjeta», porque es como piensa la tarjeta quien la usa (decisión 6). No se guarda entre
   sesiones, como el resto de la agrupación del informe.
2. **«Por tarjeta»: una fila por tarjeta, con sus líneas convertidas a la divisa preferida y «≈»** si algún movimiento se
   convirtió (el mismo significado que el total de la tarjeta en el Panel, entrega 2). **«Por línea»: lo de hoy.** Las
   cuentas sin líneas no cambian en ninguno de los dos modos.
3. **Columna `card` del CSV: el nombre de la tarjeta en la principal y en sus líneas**; vacía en una cuenta sin líneas.
   El ticket decía «vacía si no es línea»; con la principal vacía, filtrar la hoja por la tarjeta dejaría fuera los soles.
   Va detrás de `account`. **Solo se ofrece (y sale activada) si hay alguna tarjeta con líneas**, con el molde del
   interruptor de Grupos del mismo paso: quien no tiene tarjetas exporta el mismo fichero que hoy. La copia de «exportar
   todo» del cierre de sesión (`ProfileView`) no cambia.
4. **Filtro de cuentas del asistente: cada tarjeta una vez, sin cuentas de Grupos.** Elegir la tarjeta mete sus líneas
   (`AccountCardLogic.normalizedSelection`) y el filtro de divisas ofrece las de todas. Los movimientos de las cuentas de
   Grupos salen cuando están marcadas todas las cuentas (el estado de partida, y el de «Exportar antes» de vaciar datos)
   y no cuando se elige una cuenta concreta. Así la copia completa sigue siendo completa.
5. **Contexto de Yala IA:** la tarjeta sale una vez en `balances.accounts`, con `lines` (cada una con su saldo y su
   divisa) y `card_total` en la divisa preferida; las líneas dejan de salir sueltas. Regla nueva 15c en el prompt: no
   sumar en crudo y decir que el total es aproximado. El `total_balance` no cambia.
6. **Conector:** port de `AccountLineLogic.resolve` y `Budget.spendingAccountIDs` a `mcp/src/logic/`, `parent_account_id`
   en la lectura de cuentas, y un escenario nuevo en el golden con una tarjeta, su línea USD y un presupuesto de la
   tarjeta. Nada se publica: el conector sigue en staging.
7. **Sin esquema nuevo.** Ningún despliegue.

### Review adversarial (2026-10-18, dos lentes: dinero y consumidores)

Arreglado en este PR, cada uno con su test:
- **La tarjeta solo se convierte si su fila mezcla divisas.** Con Divisa › Cuenta, bajo el nodo USD salía «≈ S/ …»;
  ahora sale en dólares, sin «≈» (lo cazaron las dos lentes).
- **El total de la tarjeta en Yala IA es el del Panel**: roles sobre TODAS las cuentas y la línea archivada fuera de la
  tarjeta (listada aparte, porque cuenta en el saldo total); divisas normalizadas.
- **Sin ninguna cuenta propia**, el filtro del export ofrece las de Grupos como antes (si no, «Siguiente» quedaba apagado).
- **El resumen del asistente cuenta lo que enseña el filtro**, no las líneas ni las cuentas de Grupos.
- **La columna «Tarjeta» se ofrece si lo exportado incluye una tarjeta**, no si existe alguna.
- `CloudPersonalAttestExportTests.hasNoFilters` fijaba «todas las columnas» en la copia del cierre de sesión: ahora fija
  todas menos `card` (decisión 3).

Decidido por la sesión, sin cambio: en el modo «Ocultar» las cuentas de Grupos siguen la misma regla («entran con todas
marcadas»), así que ocultar todas también las oculta y ocultar algunas no. Es la lectura de «lo que no tiene chip no se
oculta a mano».
