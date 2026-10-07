# Los tres tests de la suite UI advisory que fallan en todos los reintentos (monto mínimo, inbox→grupo, favorito) vuelven a pasar de forma estable

## Contexto
Card del tablero `tablero-ui-tres-tests-de-la-suite-advisory-falla-wsc6` (lista para lanzar, vence 2026-10-11). Visto el 2026-10-06 en la QA programada de 2.1 (run https://github.com/jur211296/Yala/actions/runs/37485294893, HEAD = merge del PR #372). La suite UI es advisory: el run queda verde y no bloquea merges, pero estos tres fallan 3 de 3 reintentos, así que la suite deja de avisar de nada real.

Persistentes (3/3):
- `EdgeCasesUITests.test_extremeMinimumAmountSaves`: no llega la pantalla de éxito.
- `InboxConvertToGroupUITests.test_convertDraftToGroupExpense_preservesDraftDate`
- `QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList`

Flaky 1/3 (anotar en el ticket, NO arreglar en este encargo): `AccountsCrud` archivingAccount (timeout al lanzar), `BudgetAlertsConfig` selectingThreshold, `RemoteWipeNoticeRouting` keepWaiting.

Hoy se cerró el PR #383 (onboarding: «Cancelar» del aviso de borrar todo tras un adopt vuelve a la bienvenida), en cola de auto-merge a 2.1 con el job tests en curso. No depende de este encargo.

Para orientarte: `CLAUDE.md`, `.claude/rules/` que toquen, `.github/workflows/qa.yml` (solo para entender cómo corre la suite advisory) y los logs del run de arriba con `gh run view`.

## Que se pide
1. Si no existe, escribe el ticket en `tickets/` del repo con los tres persistentes y los tres flaky anotados.
2. Para cada uno de los tres persistentes, averigua si falla el test (selector, espera, datos de arranque, texto que cambió con un rediseño reciente) o si falla el producto (la app de verdad no guarda el monto mínimo, pierde la fecha del borrador al pasarlo a grupo, o el favorito no aparece). Reprodúcelo en local antes de tocar nada.
3. Arregla con la opción más robusta: si es el producto, arregla el producto y deja el test como guardián; si es el test, arréglalo sin debilitar lo que comprueba (nada de quitar aserciones, subir timeouts a ciegas ni `XCTSkip`). Si un arreglo exige una decisión de producto de Jürgen, déjala propuesta en el ticket (A/B/C con recomendación) y sigue con los otros.
4. Cada test arreglado tiene que pasar varias veces seguidas en local (por ejemplo 3 corridas) y, si es un bug de producto, con un control que lo pruebe rojo con el código viejo.
5. Capturas: solo si el arreglo cambia algo visible para quien usa la app; en ese caso `capturas/antes.png` y `capturas/despues.png` en el worktree y las rutas absolutas en el cierre. Si es solo de tests, no hace falta.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-ui-tres-tests-de-la-suite-advisory-falla-wsc6` a «done» si no queda nada para Jürgen, o a «in qa» si hubo cambio de producto que deba mirar en el iPhone, con `tablero mover <id> --a "<estado>" --agente frank`.

## Que NO hay que tocar
- Los tres flaky 1/3: solo anotados en el ticket.
- Que la suite UI siga siendo advisory: no la conviertas en bloqueante ni cambies los reintentos en `qa.yml`.
- `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~31 GB libres, por debajo del umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR #383 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Los tres tests persistentes pasan de forma estable en local y en el job de la suite advisory del PR (o en la QA programada si el PR no la corre).
- Ningún test debilitado; si hubo bug de producto, está arreglado y con control rojo con el código viejo.
- Ticket en `tickets/` con los flaky anotados; builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Ticket nuevo o reabrir los dos que ya hablan de esto?** → Ticket nuevo `advisory-ui-tests-fail-every-retry`
en `tickets/in-progress/`, que enlaza a `edgecases-extreme-minimum-flaky-under-load` y
`uitest-compara-fechas-sin-fijar-locale` (backlog). Al cerrar, los dos viejos se cierran con él si su causa queda
resuelta. Por qué: el encargo pide un ticket con los tres persistentes y los tres flaky juntos; los viejos describen
cada uno una parte y con hipótesis ya caducadas. Descartado: reabrir uno solo, que dejaría al otro diciendo lo contrario.

**D2 · Inbox→grupo: ¿test o producto?** → Test. El log del CI muestra el chip con «3 oct.» (la fecha correcta del
borrador) y la expectativa en «Oct 3»: la app corre fijada a `es_PE` y la expectativa se formatea con el locale del
runner (inglés en el CI). Arreglo: formatear la expectativa con el MISMO locale que se fija a la app, sacado a una
constante compartida del helper de lanzamiento para que no puedan divergir. La aserción de igualdad se queda entera.
Descartado: comparar sin mes o con `contains`, que debilita lo que comprueba.

**D3 · Los dos rojos de `transaction_success_accept`: ¿test o producto?** → Se decide midiendo, no leyendo: se
reproduce en local imitando el CI (idioma/región del runner en inglés con `-testLanguage`/`-testRegion`) y se mira el
árbol de accesibilidad tras tocar Guardar. Si la app no guarda, es producto y se arregla con control rojo; si guarda
y el test no lo ve, se arregla el test sin subir timeouts.

**D4 · Si en local con iOS 27 no se reproduce y el CI usa iOS 26.5** → No hay runtime 26.5 en la Mini y bajarlo cuesta
~8 GB con el disco a 31 GB. Se reproduce primero con iOS 27 + locale del runner; solo si eso no basta se valora el
runtime. La verificación final la da la suite UI del CI (la QA programada; en el PR el paso de UI va `skipped`).

**D5 · Flaky 1/3** → Solo anotados en el ticket, como pide el encargo.
