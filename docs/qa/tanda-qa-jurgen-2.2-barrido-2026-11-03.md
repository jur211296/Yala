# Tanda de QA de Jürgen — 2.2, barrido del 2026-11-03

Barrido con `/barrido-qa` y el criterio estricto del 24-oct (filtro doble) sobre `origin/2.2` en `8625a7edd` (#760).
Alcance: lo mergeado desde el TestFlight 2.2 (5) (`165ae0acd`, PR #701): **#702 a #760**, más las cards en «in qa»
que entraron después del barrido del 30-oct (#700 y el PR #650 de la tarjeta, que llegó a 2.2 el 30-oct).
Lo que decidió el barrido del 30-oct (`tanda-qa-jurgen-2.2-barrido-2026-10-30.md`) **no se repite**: sus montajes
siguen igual y se arrastran aquí sin tocarlos.

Los ids van sin el prefijo `tablero-`.

## Resumen

- **Revisadas: 76 cards** de Yala en «in qa». **Nuevas para este barrido: 61.** Arrastradas del 30-oct: 12. De
  Lola, sin tocar: 3 (`b4es`, `eukp`, `vfsf`).
- **Pasan a done: 54**, cada una con su motivo y su evidencia en la nota de la card y en la tabla de abajo.
- **Para tu iPhone: 0 nuevas.** Ninguna de las 61 pasa el filtro doble: las que tocan dinero, Grupos o sync traen
  XCUITest o test de integración del flujo, y las que no tienen test del flujo entero son de aspecto o de avisos (no
  graves). La tanda del iPhone sigue siendo **la del 30-oct: 8 cards en 4 montajes, unos 50 min**.
- **Preguntas de visto bueno nuevas: 6** (7 cards), fuera de la tanda. Frank te las manda una por mensaje, con sus
  fotos. La primera cierra también las tres que esperaban visto bueno desde el 30-oct (`e7by`, `k2up`, `i00g`).
- **Decisión pendiente: 1**, la misma (`laik`, Siri gratis con el modelo del iPhone).
- **Sentry:** `YALA-IOS-2` (congelación) no tiene eventos desde el 30-oct 23:17 UTC (build 5); el arreglo #723 va en
  el build 6. `YALA-IOS-3` e `IOS-4` eran previews del simulador de la Mini (#760); resolverlos espera al token con
  escritura (card `cjof`).
- **Pase de estrés:** al final. Un hallazgo, a card: `tablero-pase-de-estres-2-2-con-el-texto-al-maxim-fb1j` («Pase
  de estrés 2.2: con el texto al máximo, el chip de una cuenta en «Tus finanzas» saca el icono de su cápsula»).
- **Tickets cerrados: 6** (`tickets/qa` → `tickets/done`). **Ticket nuevo: 1** en `tickets/backlog/`.

## Qué bloquea 2.2

Lo mismo que el 30-oct: `046l` (ver el grupo antes de crear cuenta al unirse), montaje A.

## Las pruebas del iPhone

Sin cambios: montajes A (dos aparatos, unirse a un grupo: `046l`, `7xnd`, `ywm1`), B (iCloud real: `ppxk`, `n5zw`,
`7e60`), C (barra personalizada: `fozu`) y D (sandbox: `7c97`). Guion en
`docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md`. Hazlo con el **build 2.2 (6) o el siguiente**: nada de
#702-#760 cambia esos pasos.

## Preguntas de visto bueno pendientes para Frank

Capturas en `~/Claude/worktrees/_capturas/barrido-qa-2-2-b/`, una carpeta por pregunta.

| # | Cards | Qué se pregunta | Carpeta |
|---|---|---|---|
| 1 | `bvpn`, `jmgh` (y cierra `e7by`, `k2up`, `i00g`) | ¿Te vale Grupos en el fondo del tema con los montos en color de texto normal, las gráficas de Flujo de caja con el fondo de Tendencias y el Welcome centrado? Dos detalles abiertos: ¿la cifra verde de la pantalla de éxito de un gasto de grupo también va en texto normal?, y ¿la intro de Grupos y la de unirse conservan su degradado? | `p1-grupos-en-blanco-bvpn-jmgh/` |
| 2 | `y29x` | ¿El resumen de Grupos que elegiste se ve bien con tu tema y tus grupos (rosa rojizo y verde, aviso con tu moneda principal, filas por persona)? | `p2-hero-grupos-y29x/` |
| 3 | `g1uw` | Las hojas a media altura (Cuenta, Categoría…) pasan a cristal como «Configurar panel». ¿Te vale que se vea el monto rosa difuminado detrás? | `p3-hojas-glass-g1uw/` |
| 4 | `n7cl` | En «Tus finanzas», las cuentas de Grupos se juntan en un solo chip «Grupos» con una línea por grupo. ¿Te vale? | `p4-cuenta-grupos-n7cl/` |
| 5 | `c0nl` | Los widgets llevan un degradado de un tono con borde iluminado en vez del gris plano (excepción a «sin degradados»). ¿Te vale? | `p5-fondo-widgets-c0nl/` |
| 6 | `3zva` | En un pago ya pagado este mes, los botones dicen el mes («Ya pagué diciembre», «Saltar diciembre») bajo «Próximo: diciembre de 2026». ¿Te vale? | `p6-pago-planificado-mes-3zva/` |

## Lo que pasó a done

| Card | Motivo y evidencia |
|---|---|
| `lyxc`, `tyzh` · tests de FullFinancialContextBuilder por la fecha | tests: PR #724 con el reloj fijo (12 rojos el 1-nov 00:23, verdes después); QA de 2.2 en verde (`46505c82d`). |
| `8hs2` · test de pagos los días 31 | tests: no es bug de producto; gemelo con fechas fijas en #724, el mutante sin ancla tumba 4 de 5. |
| `d7fu` · subir TestFlight 2.2 (5) | operación hecha: build 5 en TestFlight (#701), ya sustituido por el 6. |
| `e76v` · subir TestFlight 2.2 (6) | operación hecha: 2.2 (6) VALID / IN_BETA_TESTING con #702-#748 (#749). |
| `truj` · fr/de mezclan tú y usted | l10n con test: GroupsInformalRegisterTests (#750). |
| `m76a` · repartos huérfanos de un saldo inicial rechazado | edge case de pocos usuarios con test: OpeningBalanceOrphanSharesTests + sonda g29_01 en staging (#750). |
| `hfhs` · grupo migrado: app y servidor eligen la misma fila | test: OpeningBalanceServerAdminParityTests; divergencia medida y cerrada (#750). |
| `0vbn` · menú de miembro en grupos migrados | edge case de pocos usuarios con test: GroupAdminPermissionLogicTests con la fila heredada sin reclamar y reclamada (#758). |
| `6n1o` · el servidor solo deja a dueño y admins | servidor probado: batería g27_01 34/34 en local, staging y producción; sonda real 7/7; OpeningBalanceServerRejectionUITests (#716). |
| `yd2w` · cualquier admin gestiona saldos iniciales | XCUITest del flujo: GroupOpeningBalanceAdminUITests + sonda staging 5/5 (#714). |
| `e6fd` · saldo inicial rechazado se queda en el teléfono | edge case de pocos usuarios (admin degradado mientras estaba sin red) con XCUITest: OpeningBalanceServerRejectionUITests y OpeningBalanceRejectionSettleTests (#732). |
| `8933` · editar la cuenta de un gasto de grupo pagado | test de integración: GroupBridgeEditedAccountTests (#750). |
| `8cqp` · el detalle lee el grupo tras salir | no grave (la salida del grupo ya se completó; el fallo era al cerrar la pantalla) y fijado por GroupDetailDismissDecisionTests y el scan de formularios (#729). |
| `th4n` · grupo desde su notificación sin pull to refresh | XCUITest del flujo: GroupPushOpensWithTheChangeUITests + GroupNotificationOpeningTests (#754). |
| `sztn` · revisión de las notificaciones de Grupos | no grave (texto y destinatario del aviso) y fijado por GroupPushNoticeTests; worker en staging (#705). |
| `xi74` · el autor del gasto viaja por el canal | no grave (un aviso de más en tu propio iPad) y fijado por GroupsChangeAuthorChannelTests; g29_01 en staging y producción (#750). |
| `emjb` · Grupos B 10, el cobro cuenta el día del pago | XCUITest del flujo: GroupSettlementCollectedUITests + GroupBridgeCollectedTests (#742). |
| `wrlu` · Grupos B 5, «Partir» en la Bandeja | XCUITest del flujo: GroupSplitLinesUITests + GroupSplitLinesServiceTests (#740). |
| `ffpl` · Grupos B 6, «Partir tu parte» en éxito y detalle | XCUITest del flujo: GroupSplitLinesUITests (#740). |
| `6u5f`, `oibr`, `00xj` · Grupos B, cabos sueltos | XCUITest: GroupsBCabosSueltosUITests + GroupsBCabosSueltosTests y GroupBridgeSplitLinesTransplantTests (#744). |
| `97gc` · Registros sin flotante | XCUITest: AdaptiveNavigationUITests y GroupsBCabosSueltosUITests (#744). |
| `3aqr` · registro unificado en las tres pantallas | XCUITest del flujo: RegistroUnificadoUITests + RegistroUnificadoTests (#728). |
| `ewjs` · editar cuenta de doble línea | XCUITest del flujo: AccountEditMultiCurrencyUITests + AccountEditMultiCurrencyTests (#707). |
| `nmtk` · tarjeta de crédito con fecha de corte | XCUITest del flujo: CreditCardStatementUITests + CreditCardStatementLogicTests y CreditCardReminderSchedulerTests (#650, en 2.2 desde el 30-oct). El aviso con la app cerrada no es grave: si falla, la tarjeta y su ficha siguen bien. |
| `yh9g` · congelación por Core Data (YALA-IOS-2) | test: DrainIndexesOnlyWhatItTranslatesTests (#723). Sentry: ni un evento desde el 30-oct 23:17 UTC (build 5); el arreglo va en el build 6. Si vuelve, lo dirá Sentry, no una prueba a mano. |
| `mei0`, `65wb` · YALA-IOS-4 e IOS-3 | solo de desarrollo (previews en el simulador de la Mini) y fijado por ErrorReportingPreviewGateTests (#760). Resolverlos en Sentry espera al token con escritura (card `cjof`). |
| `g6ua` · textos de IA automáticos en Estadísticas | tests del disparador y del techo: StatsAIAutoRefreshTests y StatsAIAutoRefreshInsightsTests, TrendsInsightCardUITests (#756). Si falla, sale el botón de siempre: no grave. |
| `g6nw` · globo de la comparación | copy reescrito en 16 idiomas (#711); medido: ningún `.strings` nombra ya «P-1» ni «A-1». No grave. |
| `505a` · widget de Grupos | tests: WidgetGroupsSnapshotTests, WidgetSnapshotLegacyDecodeTests y paridad del DTO, review adversarial (#727). |
| `dvg6` · widget de Grupos con push silencioso | no grave (el widget se pone al día al abrir la app) y fijado por GroupsWidgetPushRefreshTests (#750). |
| `hzag`, `wvoj`, `fhya` · widgets tandas 1-3 | no grave (aspecto) y fijado por WidgetDesignSystemParityTests, WidgetInsightsLogicTests, WidgetShowVariationsMirrorTests y ControlCenterNewRecordWiringTests; capturas antes/después en `_capturas/2026-10-31-widgets-*` y `_capturas/2026-11-01-widgets-tanda-3-categorias/` (#721, #722, #726). |
| `znu5` · porcentajes de los widgets de categorías | cálculo con test: WidgetBreakdownTotalWiringTests, CategoryBreakdownUncategorizedTests y WidgetDataCacheTests (#753). |
| `a5kf` · Duo abierto, perfil en la barra lateral | tamaños de pantalla, criterio de Jürgen; AdaptiveNavigationUITests y capturas en `_capturas/2026-10-30-duo-perfil-en-barra-lateral/` (#704). |
| `apil` · «tú debes» más grande | superada: el rediseño elegido (`htqk`) lo implementa `y29x` (#706), que va a visto bueno. |
| `e6ec`, `hsqm`, `2m2r` · saltos al entrar a Grupos y el «+» que asoma | aspecto, no grave: verificados en vídeo en el simulador; GroupsSearchDrawerWiringTests, TopPrimaryActionUITests y TopPrimaryActionRevealLogicTests (#703, #751). |
| `pjum` · fluidez de toda la app | aspecto, no grave: auditoría en `docs/fluidez/AUDITORIA-FLUIDEZ-2-2.md`, FluidezWiringTests y StagedTabSelectionTests (#720). |
| `0qhn`, `fb1j`, `tyh9` · fluidez C1, C3, C7 | aspecto, no grave: SkeletonFadeAccessibilityUITests, ContentTransitionsWiringTests y RowListEditLogicTests; vídeos (#734). |
| `s1ve`, `bbap` · fluidez C2, C5 | aspecto, no grave: TabImplicitAnimationsWiringTests (#747). |
| `m1hw` · fluidez C6, Reducir movimiento | accesibilidad, criterio de Jürgen; ReduceMotionWiringTests (#747). |
| `86b1`, `6sld` · fluidez C4, C8 (vibraciones y Yala IA) | no grave (vibraciones y transiciones) y fijado por FluidezHapticosWiringTests; vídeo en `_capturas/fluidez-hapticos-yala-ia/` (#748). Las notarás en el uso normal del build 6. |
| `oxyr`, `1jvv` · withAnimation de pestaña y borrar la última fila | aspecto, no grave: TabImplicitAnimationsWiringTests y RowListEditLogicTests; vídeos en `_capturas/2026-11-03-fluidez-listas-pestanas-y-grupo-desde-push/` (#754). |

## Lo que se queda y qué lo retiene

| Card | Lo retiene | Dónde |
|---|---|---|
| `046l` | §4 inicio de sesión real y servidor; unirse a un grupo es un flujo principal. BLOQUEA | montaje A del 30-oct |
| `7xnd`, `ywm1` | §4 dos aparatos y push real de la aprobación | montaje A del 30-oct |
| `ppxk` | §4 importación real de iCloud | montaje B1 del 30-oct |
| `n5zw` | §4 apagar iCloud Drive de verdad | montaje B2 del 30-oct |
| `7e60` | §4 el cierre al cerrar sesión no sale en el simulador | montaje B3 del 30-oct |
| `fozu` | §4 la pantalla negra no sale en el simulador | montaje C del 30-oct |
| `7c97` | §4 sandbox de Apple | montaje D del 30-oct |
| `bvpn`, `jmgh`, `e7by`, `k2up`, `i00g` | §2.6 visto bueno al rediseño y dos detalles abiertos | pregunta 1 |
| `y29x` | §2.6 visto bueno al resumen de Grupos con tus datos | pregunta 2 |
| `g1uw` | §2.6 visto bueno al cristal de las hojas | pregunta 3 |
| `n7cl` | §2.6 visto bueno al chip «Grupos» | pregunta 4 |
| `c0nl` | §2.6 visto bueno de identidad (degradado en widgets) | pregunta 5 |
| `3zva` | §2.6 visto bueno al copy nuevo | pregunta 6 |
| `laik` | §2.8 decisión pendiente | — |
| `b4es`, `eukp`, `vfsf` | de Lola (marketing), no las toqué | — |

## Pase de estrés (ADR-046)

Yala Dev sobre `8625a7edd`, iOS 27.2, **iPhone 17e** (el más pequeño) y **iPhone 17 Pro Max** (el más grande), uno
detrás de otro, con **texto al máximo (AX5) y modo oscuro**. Semillas: `realista` (2.306 registros), `grupos` +
`-uitest-seed-group-split-lines` (el caso Pía de Grupos B) y `tarjeta-dos-lineas` + `-uitest-seed-registro-unificado`.
Pantallas: Panel, Registros, Grupos, Planificación, Bandeja y Panel con la tarjeta de dos líneas. Capturas en
`~/Claude/worktrees/_capturas/barrido-qa-2-2-b/estres-17e/` y `estres-17-pro-max/` (cada carpeta con su `hoja.jpg`).

- **Encontrado, a card:** con AX5 el primer chip de «Tus finanzas» saca el icono de su cápsula y lo monta sobre el
  nombre («Ahorros USD»), en los dos iPhone. No es barato (no se sabe aún si lo trajo #758) y este PR no toca código:
  ticket `tickets/backlog/account-chip-icon-overflows-at-the-largest-text-size.md` y card
  `tablero-pase-de-estres-2-2-con-el-texto-al-maxim-fb1j` (2.2, lista para lanzar).
- **Visto y bien:** los cortes de «+ Nuevo registro» y «Presupuestos» en el 17e son el borde de filas con scroll
  horizontal, no truncados; los títulos largos («Bandeja de…») llevan sus puntos suspensivos; las cifras de seis
  dígitos caben.
- **No probado:** textos larguísimos, emojis y RTL (no hay semilla de `estres` en Yala; el import CSV sería el camino),
  red lenta (sin Network Link Conditioner) y las pantallas que piden varios toques (hoja «Tu parte», editar cuenta). El
  pase no corrió en esfuerzo `high`: la sesión no puede cambiarlo.
