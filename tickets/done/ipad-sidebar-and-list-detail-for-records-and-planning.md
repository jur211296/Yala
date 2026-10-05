---
id: ipad-sidebar-and-list-detail-for-records-and-planning
status: done
priority: medium
area: "platform, ipad, navigation, records, planning"
updated: 2026-10-04
created: 2026-09-26
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.1 y §8, fase 1), 2026-09-26"
qa-status: not-replicable
qa-date: 2026-10-04
qa-notes: barrido 2026-10-04 sin device-QA - solo iPad: falta la vuelta a ancho con un registro abierto; lo demas visto en simulador el 29-sep
---

# iPad · fase 1: barra lateral y lista-detalle en Registros y Planificación

**Paso 5 de 13 del carril adaptativo. Tamaño L. Después de Cola B, tras la release 2.1.**

## Qué cambia para el usuario

En iPad, las secciones de la app pasan a una barra lateral (las de Más, siempre a la vista). En
Registros y Planificación, la lista y el detalle se ven a la vez: tocas un registro o un presupuesto y
se abre al lado, sin perder la lista. Todas las pantallas ganan un ancho legible. En iPhone la navegación
no cambia. Lo mismo vale para el iPhone Duo abierto, que tiene ancho regular.

## Cómo (§5.1 aprobada por Jürgen el 2026-09-27)

Aprobada con una condición: la versión que Apple recomienda, que se adapte sola a cualquier tamaño de iPad, de
ventana y al iPhone Duo abierto. Decisión: ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo».

- `TabView` con `.tabViewStyle(.sidebarAdaptable)` y `TabSection` con las secciones de Más
  (`MoreView`). En iPad se ignora la configuración de pestañas del usuario y desaparecen Más y la
  pestaña temporal.
- En Registros y Planificación, **un único** `NavigationSplitView` de dos columnas que en compact se pliega solo a
  pila (`preferredCompactColumn` para elegir qué se ve). **No** un `if` por size class con dos árboles: al
  redimensionar destruye lo abierto, y en el Duo se redimensiona con cada apertura (foro de Apple, «iOS 27 automatic
  resize»). El detalle de registro deja de ser hoja en ancho regular (cuidado: al cerrarse encadena el editor,
  `DetailContainerView.swift:768`).
- Lo abierto y lo seleccionado viven fuera del contenedor y sobreviven a un redimensionado.
- `AppTab` y los consumidores de `AppRouter` (`AppRouter.swift:23-28`) tienen que alcanzar los destinos
  que hoy solo se alcanzan desde Más.
- **Antes de empezar**: [[sheet-size-follows-the-device-not-the-window]] hecho. El ADR ya está escrito (27-sep).

## Hecho cuando

- Capturas antes/después en `YalaLane-Adapt-iPad-mini` y `YalaLane-Adapt-iPad-Pro-13`, vertical y horizontal:
  barra lateral con todas las secciones; Registros y Planificación con lista y detalle a la vez; ancho legible.
- En `YalaLane-Adapt-iPhone-SE` y `-ProMax`, a tamaño por defecto y a AX5: la navegación de siempre. Diferencias
  solo si las permite la regla del iPhone.
- **Redimensionar** el iPad con Device Hub de pantalla completa a ventana estrecha y vuelta, con un registro abierto:
  el registro sigue abierto (plegado a pila en estrecho, en su columna en ancho). Guion en el ticket si lo corre
  Jürgen.
- Duo abierto, si ya existe `YalaLane-Adapt-iPhone-Duo`: lista y detalle a la vez. Si no existe, lo cubre
  [[iphone-duo-native-app]].
- XCUITest de navegación en `YalaLane-Adapt-iPad-Pro-13` y en `YalaLane-Adapt-iPhone-ProMax`, por UDID.
- Rendimiento medido con Instruments en Registros con la semilla `pesado`.
- Gate verde.

## Hecho (2026-09-29)

**Qué cambia para el usuario.** En un iPad a pantalla completa en horizontal, las seis páginas (Panel, Estadísticas,
Planificación, Registros, Reportes, Grupos) y Buscar están en una barra lateral, sin pasar por Más. En vertical salen
arriba, con la barra lateral a un toque (lo que Apple hace por defecto en ese ancho). En Registros, tocar un registro lo
abre al lado de la lista; en Planificación, lo mismo con un presupuesto (y con un pago planificado, que usa el mismo mecanismo: inferido, no capturado). En un iPad mini en
vertical no caben los dos: la lista flota encima del detalle vacío y, al abrir algo, se aparta para que se vea entero.
En iPhone todo sigue igual.

**Cómo quedó** (y dónde se aparta del «Cómo» de arriba, con su porqué en el Paso 0 del encargo):

- Raíz: `TabView(.sidebarAdaptable)` que en ancho monta todas las páginas y en compacta las de siempre, quitando
  las que no tocan (`RootTabLayoutLogic`). **No con `.hidden(_:)`**: una pestaña oculta y seleccionada tumba la app
  (medido: lo cazó el gate en `GroupInviteOnboardingUITests`, con la shell de solo grupos y la selección en Panel). **Barra lateral plana, sin `TabSection`**: una sección que solo exista en regular cambia el
  árbol al redimensionar, y una permanente reordena la barra del iPhone, que el usuario ordena a mano. Las
  sub-secciones de Más siguen en los chips de cada página. Perfil sigue en la barra de cada pantalla.
- Lista y detalle: `ListDetailSplit` (un único `NavigationSplitView`, `.balanced`), reusado por Registros y
  Planificación. Los `navigationDestination` de Planificación presentan solos en la columna de detalle. El registro
  abierto vive en `RecordsViewModel.openRecordID`; en ancho, el detalle es columna (`TransactionDetailSheet(presentation:
  .column)`, Editar abre el editor directo); en compacta, la hoja de siempre con su encadenado.
- Lo medido que no estaba escrito, ahora en `swiftui-ds.md` («Layout adaptativo»): el split deja la lista en ~280-320 pt
  si no se le da ancho (filas rotas); `.toolbar(removing: .sidebarToggle)` detrás del ancho lo anula; con visibilidad
  fija la superposición del mini no se retira.

**Verificado** en los simuladores del carril, iOS 27.0, por UDID. Evidencia y método en
`qa/evidencia-adaptativo-20260929/ipad-sidebar-and-list-detail-for-records-and-planning/README.md`:

- iPad mini y Pro 13, vertical y horizontal, antes y después: barra lateral (o pestañas arriba en vertical), y lista y
  detalle a la vez en Registros y Planificación.
- iPhone SE y Pro Max, por defecto y AX5: iguales píxel a píxel salvo barra de estado, datos aleatorios de la semilla y
  antialiasing subpíxel.
- `AdaptiveNavigationUITests` (3 casos) en verde en `YalaLane-Adapt-iPad-Pro-13` y `YalaLane-Adapt-iPhone-ProMax`.
- Instruments (Time Profiler) en Registros con `pesado`: 0 cuelgues; Animation Hitches no graba en simulador.
- Unit: `RootTabLayoutLogicTests`, `ListDetailOverlayLogicTests`, `RecordsDetailColumnTests`.
- **Gate** (ProMax por UDID): builds `Yala` y `Yala Dev` sin avisos en lo tocado; `YalaTests` 8491 tests / 809
  suites en verde; XCUITest de las 49 suites de las áreas tocadas en siete lotes, **115 verdes y 3 rojos, centinela
  en 0 y sin reinicios**. Los tres rojos fallan también en `2.1`: los dos de `ScheduledPaymentSkipUITests`
  ([[scheduled-payment-skip-uitests-fail-at-the-end-of-the-month]], 2 de 2 en `2.1`) y
  `QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList` (flaky conocido,
  [[nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo]]: 1 de 2 en `2.1`, 2 de 2 con este cambio).
- **Un crash que cazó el gate, ya arreglado:** la primera versión ocultaba pestañas con `.hidden(_:)` y UIKit abortaba
  al entrar por invitación (`GroupInviteOnboardingUITests`, 0 de 2 con esa versión, 2 de 2 en `2.1` y con la final).

**Encontrado y fuera:** [[ipad-list-highlights-the-open-row]] (la fila abierta no se marca),
[[ipad-reports-and-search-get-a-readable-width]] (Reportes y Buscar sin ancho legible), el chip Registros de
Estadísticas sigue en hoja (anotado en [[ipad-and-duo-panel-and-statistics-use-the-width]]). Los XCUITest viejos que
buscan `app.tabBars` en iPad siguen en [[navigation-uitests-look-for-the-iphone-tab-bar-on-ipad]].

**Redimensionado, medido a medias.** En el iPad Pro 13 con «Apps en ventanas»: a pantalla completa el registro se
abre en su columna, y al estrechar la ventana a 375 pt la app pasa a pestañas abajo con **el mismo registro abierto**,
empujado y con «Atrás» (`resize__r-00…r-02` en la evidencia). **La vuelta a ancho no se pudo automatizar**: con la
ventana estrecha centrada, XCUITest no sabe dónde está su esquina (`app.frame` es local a la ventana) y el arrastre trae
Ajustes al frente.

**No medido:** Duo (sin simulador hasta Xcode 27.1; [[iphone-duo-native-app]]).

## Guion de QA para Jürgen (la vuelta, ~3 min)

En el simulador `YalaLane-Adapt-iPad-Pro-13` (o en un iPad de verdad) con la build de `2.1` que traiga este cambio:

1. Ajustes → **Multitarea y gestos** → elige **Apps en ventanas**.
2. Abre Yala y ve a **Registros** desde la barra lateral. Si la ventana no ocupa toda la pantalla, arrastra su esquina
   inferior derecha hasta que la ocupe.
3. Toca un registro: se abre **al lado de la lista**.
4. Arrastra la esquina inferior derecha de la ventana hacia la izquierda hasta dejarla estrecha (más o menos un tercio
   de la pantalla). **Esperado:** pestañas abajo y el mismo registro a la vista, con «Atrás» arriba a la izquierda.
5. Arrastra la esquina de nuevo hacia la derecha hasta la pantalla entera. **Esperado:** vuelve la barra lateral y
   el registro sigue abierto **en su columna**, al lado de la lista, sin que tengas que tocarlo otra vez.
6. Si en el paso 5 ves la lista sin el registro, o una hoja encima: dímelo con una captura.
7. Deja Ajustes → Multitarea y gestos en **Apps en pantalla completa**.

## Relacionados

- [[ipad-native-app]] — paraguas. Depende de [[cola-b-redesigns-must-hold-up-at-ipad-width]].
- Siguientes: [[iphone-duo-native-app]], [[ipad-list-detail-for-groups-and-settings-and-chat-inspector]],
  [[ipad-and-duo-panel-and-statistics-use-the-width]], [[ipad-keyboard-shortcuts-pointer-context-menus-and-drop]].

## Reglas del carril adaptativo (obligatorias)

**Simulador** (Jürgen, 2026-09-27). Este carril usa simuladores dedicados creados con `xcrun simctl create` con
prefijo fijo `YalaLane-Adapt-` (p. ej. YalaLane-Adapt-iPhone-SE, YalaLane-Adapt-iPhone-ProMax,
YalaLane-Adapt-iPad-Pro-13, YalaLane-Adapt-iPad-mini) y los usa SIEMPRE por UDID (`-destination id=<UDID>`), nunca
por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar
simuladores sin ese prefijo (los usa la sesión de Cola A en paralelo). DerivedData propio del worktree
(`-derivedDataPath .ddp`). Receta para crearlos: `docs/exploracion/adaptativo-ipad-duo.md` §6.2.

**iPhone** (Jürgen, 2026-09-27). Se permiten mejoras de adaptación en iPhone si no rompen flujos ni ponen en riesgo
la release 2.1; cada una verificable en simulador con capturas antes/después en tamaños iPhone pequeño/grande y
Dynamic Type grande (`adaptativo-ipad-duo.md` §6.1).

**Layout** (ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo»). Se decide por size class y ancho del
contenedor, nunca por tipo de dispositivo ni orientación; un contenedor que se adapta, no un `if` por size class en
la raíz; APIs de iOS 27.1 solo tras `if #available`.

## Barrido de `qa` · 2026-10-04 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido antes del QA del lunes (encargo `2026-10-04-barrido-qa-antes-del-qa-del-lunes`), con el criterio de #224 y #291. Solo faltaba la vuelta a ancho con un registro abierto, que existe en un iPad y no en un iPhone. Lo demás se vio en el simulador el 29-sep.
