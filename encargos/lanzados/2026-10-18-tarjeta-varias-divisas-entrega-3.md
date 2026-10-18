# Tarjeta con varias divisas, entrega 3: se elige la tarjeta y la divisa del importe decide la línea (más quitar la línea «Entró … − salió …» del Panel)

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Contexto
Jürgen aprobó el 16-oct (22:38) la cola de cards de 2.2, y la tarjeta multidivisa va primero, en cuatro entregas en orden 1→2→3→4 (obligatoria en 2.2, decisión del 13-oct). La entrega 1 (PR #547) dejó el enlace «línea en otra divisa» en el modelo, iCloud y Modo Nube. La entrega 2 (PR #548, mergeado hoy en 2.2) dejó la tarjeta con sus líneas en el Panel, la ficha, Ajustes y el formulario (`AccountCardLogic`, `AccountLineLogic`, `AccountLineService`, seed `-uitest-seed tarjeta-dos-lineas`). Esta es la entrega 3: en todos los selectores, filtros, presupuestos y entradas de captura se elige la tarjeta, y la divisa del importe decide la línea.
- Card principal: `tablero-tarjeta-con-varias-divisas-entrega-3-se-i9rh`. Card agrupada en esta misma sesión (toca el Panel): `tablero-quitar-del-panel-la-linea-entro-salio-ba-825e`. Muévelas a in progress al empezar y a done al cerrar (`--agente frank`); si algo queda para probar en el iPhone, a in qa asignada a `jurgen` con el guion en la nota.
- Ticket con el alcance completo: `tickets/backlog/multi-currency-accounts-3-pickers-and-capture.md` en origin/2.2 (escrito el 10-oct: comprueba rutas y conteos contra el código de hoy). Decisiones de Jürgen: `tickets/backlog/multi-currency-accounts.md` y `docs/multi-currency-accounts-impact-2026-10.md`, secciones 2.4, 2.8, 2.13-2.15 y 4-6. Lee también el ticket de la entrega 2 (`tickets/qa/multi-currency-accounts-2-card-view.md`) y el cuerpo del PR #548.
- La entrega 2 dejó dicho que «Filtrar por esta cuenta» desde la tarjeta filtra solo la principal hasta esta entrega: aquí debe incluir sus líneas.

## Qué se pide
1. Los puntos 1 a 7 del alcance del ticket: selector de cuentas anidado, una función pura tarjeta + divisa → línea usada por todas las entradas (formulario, chat, voz, imagen, Siri, Apple Pay, aprobación de borradores de la Bandeja, programados y favoritos), filtros por cuenta que incluyen las líneas al elegir la tarjeta, presupuestos que cuentan los gastos de las líneas, selectores que excluyen `isSystemAccount` revisados uno a uno, e importación CSV con varias divisas. Si no coincide ninguna línea, va a la principal con el aviso de divisa de hoy y no crea líneas solas.
2. Card «Quitar del Panel la línea «Entró … − salió …» bajo el hero» (decisión de Jürgen del 18-oct 10:39): quitar la línea `panel.hero.flowCaption` de `HeroMonthView`, dejar solo el mensaje de mes sin movimientos, que las pastillas se lean «Entró/Salió» con su importe en VoiceOver, borrar la clave de los 16 idiomas si queda sin uso, y NO tocar `accountDetail.moneyIn` de la ficha de cuenta.

## Qué NO hay que tocar
- Informes, flujo de caja y exportación por tarjeta (entrega 4). Cuentas de una sola divisa: sin líneas, todo sigue igual.
- Nada de despliegues a producción (ni CloudKit Production ni Supabase de producción ni el Worker de producción). Si hiciera falta esquema nuevo, déjalo listo, crea su card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, ni `Yala--qa-guiado-2-1-tf17`.

## AUTONOMÍA (fin de semana)
Jürgen no está en el escritorio. Si sale una duda reversible, elige la opción recomendada, impleméntala y anótala en la card y en el PR («Decidido por la sesión: …, porque…»). Para el diseño visual sigue el sistema de diseño y los componentes que ya usa Yala y lo que dice el ticket; si dudas entre variantes, elige la más coherente con lo que dejó la entrega 2, y deja las capturas para que Jürgen la revise. Lo irreversible (esquema de producción, borrar datos, cobros) queda para Jürgen, sin parar la sesión.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- Texto nuevo de usuario en los 16 idiomas de la app, con `/l10n-check` en verde y sin nombrar a «OpenAI».
- Todo ticket nuevo lleva su card.
- Prueba según /barrido-qa lo que aplique: la suite de la función tarjeta + divisa → línea, un test por cada entrada del punto 3 del ticket que guarde un importe en USD en la línea USD, `ApplePayDraftServiceTests` y `ChatDraftAccountCurrencyTests` en verde, XCUITest del selector anidado con el seed de tarjeta de dos líneas, filtros y presupuestos con líneas.
- Capturas de antes y después del selector de cuentas, un filtro por la tarjeta, un presupuesto de la tarjeta y el hero del Panel sin la línea (con Dynamic Type grande y modo oscuro donde aplique) en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, y con sus rutas en el resumen de cierre.
- Cierra con /cerrar-total.

## Cómo se sabe que está bien
El criterio de hecho del ticket cumplido, la card del hero cumplida según su «hecha cuando», `/gate` y la suite de `YalaTests` en verde, y el PR contra 2.2 explicando en lenguaje de usuario qué ve ahora y qué queda para la entrega 4.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, Jürgen fuera el fin de semana): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (18-oct): `selectedAccountIDs` sale en 60 líneas de 17 ficheros (cuadra con el ticket) y se
CONSUME en ~25 sitios (constructores de `FilterCriteria`, elegibilidad del Panel y de Estadísticas, saldo vivo, Insights,
Tendencias…). El gasto de un presupuesto se calcula en dos sitios (`BudgetsViewModel.filterTransactions` y
`PanelViewModel.calculateBudgetSummary`); el resto (alertas, widgets, IA, puntuación) pasa por el primero. El formulario de
transacción no tiene selector de divisa: la divisa es siempre la de la cuenta. `InboxDraft` no guarda divisa. No existe hoy
un «aviso de divisa distinta» en la captura (el del ticket no tiene sitio concreto). La coordenada `NewTransactionView:422-425`
del ticket está desfasada: hoy es `:439-443`.

**D1 · Dónde entran las líneas al filtrar por la tarjeta** → al ESCRIBIR el filtro de sesión: `SessionState` normaliza
`selectedAccountIDs` (poner la tarjeta añade sus líneas; quitarla las quita; una línea elegida sola se respeta). Los
selectores de filtro enseñan solo la tarjeta, y la píldora y el contador cuentan tarjetas.
Por qué: hay un escritor común y ~25 lectores; expandir en cada lector deja uno fuera tarde o temprano. Alternativa
descartada: expandir en cada consumidor (FilterService, elegibilidades, saldo vivo…).

**D2 · Presupuestos** → el presupuesto guarda la tarjeta (como hoy) y el CÁLCULO incluye sus líneas, en los dos sitios que
filtran gasto. El editor enseña solo la tarjeta. Nada se escribe en el CSV `accountIDs` ni viaja por sync.
Por qué: una línea añadida después cuenta sola y no hay estado duplicado. Alternativa descartada: guardar las líneas en el
presupuesto (se quedaría fuera la línea nueva y viajaría a otros teléfonos).

**D3 · Selector de cuentas anidado** → la tarjeta una vez y sus líneas debajo, sangradas, con la divisa. Elegir la tarjeta
devuelve la línea cuya divisa coincide con la que pasa el llamador (`routingCurrency`); sin coincidencia, la principal.
Los identificadores `account_selector_row_<nombre>` se conservan y la tarjeta va antes que sus líneas (los UITests que
toman la primera fila siguen eligiendo lo mismo).

**D4 · Una sola función pura tarjeta + divisa → cuenta** (`AccountCardLogic.route`): coincide con la principal o una línea
viva → esa; no coincide → la principal y lo dice (`isFallback`). Nunca crea una línea. Cuentas sin líneas: devuelve la
misma cuenta.

**D5 · El formulario de transacción** → con una tarjeta elegida enseña la tarjeta y unas pastillas con sus divisas
(«S/ · US$»); elegir divisa elige la línea. `selectedAccount` sigue siendo siempre la cuenta concreta, así que guardar,
convertir y el resto no cambian. Al elegir la tarjeta se enruta por la divisa del importe que ya tenía el formulario
(prellenado de chat o favorito). Alternativa descartada: un selector de divisa libre en el formulario (otro cambio de
producto, fuera de alcance).

**D6 · Bandeja sin campo nuevo** → la línea se decide al CREAR el borrador (voz, imagen, Siri, Apple Pay, programados:
ahí se conoce la divisa) y, al aprobar desde su hoja, la tarjeta sale con las mismas pastillas de divisa.
Por qué: un campo en `InboxDraft` es esquema de iCloud a Production y columna nueva de la nube, irreversible y fuera del
encargo. Alternativa descartada: guardar la divisa dictada en el borrador.

**D7 · Apple Pay y el símbolo ambiguo** → si la última cuenta usada es de una tarjeta cuya divisa NO se escribe con ese
símbolo, y la tarjeta tiene UNA cuenta que sí (`$` → su línea en dólares), el pago va a esa cuenta; si no, como hoy (la
divisa de la última cuenta). Por qué: es el caso `[CRÍTICO]` del análisis (§2.13): con la tarjeta en soles, un pago en `$`
quedaba en soles. Corregido tras la review: la primera versión mandaba a dólares los `$` de una tarjeta en pesos (MXN, ARS…).

**D8 · Voz, imagen y Siri** → siguen eligiendo cuenta por la divisa dictada (`DraftBuilder.findAccount`, única cuenta viva
en esa divisa): una línea cuenta como una cuenta más de su divisa. La voz deja su copia privada y usa la común (que
además excluye las cuentas de sistema, como Siri y Apple Pay).

**D9 · Chat** → al elegir la tarjeta en el borrador, la divisa dictada decide la línea en vez de pisarse con la de la
cuenta; sin línea en esa divisa, la principal y su divisa, como hoy.

**D10 · Programados y favoritos** → el borrador de un pago programado y el prellenado de un favorito pasan por la función
con su propia divisa. Hoy su divisa es la de la cuenta, así que no cambia nada visible; protege lo creado sobre una
cuenta que después se vinculó como línea o principal.

**D11 · Importación CSV con varias divisas** → al elegir una cuenta de una tarjeta para una divisa, las demás divisas del
fichero sin asignar se rellenan con las líneas de esa tarjeta (la función de D4). Se pueden cambiar a mano.

**D12 · Transferencias** → el selector enseña la tarjeta anidada, pero una transferencia usa la cuenta elegida tal cual (se
elige la línea a mano): pagar la línea en dólares con soles es una transferencia FX normal (§2 del análisis).

**D13 · Hero del Panel** → fuera la línea `panel.hero.flowCaption` y su clave de los 16 idiomas; las pastillas se leen
«Entró S/ …» / «Salió S/ …» con claves propias (`panel.hero.incomePill` / `expensePill`), sin reusar
`accountDetail.moneyIn` (acoplar dos pantallas por un literal es como acaban cambiando juntas).

**D14 · `.first` del filtro** → con la tarjeta y sus líneas en el conjunto, las lecturas de un elemento (prellenado del
formulario desde el Panel, salto de Estadísticas a Registros) usan el representante: la cabeza, no una línea al azar.

**D15 · Una línea archivada sigue siendo de su tarjeta para sumar** → el presupuesto de la tarjeta y el filtro por la tarjeta
incluyen sus líneas archivadas. Por qué: «Archivar no decide la suma» (`.claude/rules/session-filters.md`); sin esto, archivar
una línea bajaba el gastado del presupuesto, también en los períodos pasados (review del 2026-10-18).

**D16 · Si la tarjeta no tiene cuenta en la divisa pedida, se queda la cuenta elegida** (favorito, programado): no se salta a
la principal, que cambiaría la divisa sin convertir (review del 2026-10-18). En un gasto de grupo (Caso A) no hay pastillas.

Lo irreversible (esquema de producción) no hace falta: nada de esta entrega toca modelo ni sync.
