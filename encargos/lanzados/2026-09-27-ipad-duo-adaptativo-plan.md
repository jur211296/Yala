# Actualizar el plan iPad para que sea adaptativo nativo y cubra también el iPhone Duo

## Contexto
Jürgen (27-sep) aprueba la dirección de `docs/exploracion/ipad-nativo.md` (exploración iPad del PR #264: `TabView` con `.sidebarAdaptable`, lista-detalle en dos columnas, ancho legible ~700 pt, 5 fases, 8 tickets), incluida la §5.1 (barra lateral + lista + detalle), con esta condición: la versión que Apple recomienda, nativa y eficiente, que se adapte automáticamente a cualquier tamaño de iPad (Split View, Stage Manager, ventanas redimensionables) y también al nuevo iPhone Duo. Quiere aprovechar el espacio y rediseñar vistas donde haga falta.

La idea: layout guiado por size classes / tamaño de ventana, no por modelo de dispositivo.

Cola A (sync/nube) sigue en paralelo en otra sesión (`Yala--late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`); no la toques. Este carril iPad va en serie, una fase tras otra.

Tickets iPad existentes en `tickets/backlog/`: `ipad-native-app` (paraguas), `ipad-multiple-windows-share-one-navigation-state` (fase 0), `floating-buttons-cover-row-amounts-on-ipad-landscape` y `cola-b-redesigns-must-hold-up-at-ipad-width` (Cola B), `ipad-sidebar-and-list-detail-for-records-and-planning` (fase 1), `ipad-list-detail-for-groups-and-settings-and-chat-inspector` (fase 2), `ipad-keyboard-shortcuts-pointer-context-menus-and-drop` (fase 3), `ipad-real-multiwindow-with-per-scene-state` (fase 4), `ipad-large-and-extra-large-widgets` (fase 5).

## Qué se pide
1. **Leer la documentación oficial y reciente de Apple** (developer.apple.com): HIG de layout / iPad / diseño adaptativo, SwiftUI `NavigationSplitView`, `TabView` `.sidebarAdaptable`, size classes, novedades WWDC 2026 / iOS 27, y todo lo publicado sobre el iPhone Duo (pantallas, plegado/postura, continuidad al cambiar de tamaño, multitarea). Usa el navegador. Cita URLs. Distingue hecho documentado de suposición; si no hay documentación oficial del Duo, dilo explícitamente y no inventes specs.
2. **Actualizar `docs/exploracion/ipad-nativo.md`** (o crear `docs/exploracion/adaptativo-ipad-duo.md` enlazado desde él) con: cómo cubre el plan al Duo; qué cambia en las 5 fases; qué vistas rediseñar para aprovechar el espacio (priorizadas); y la regla de que el iPhone actual (compact) no cambia ni un píxel.
3. **Revisar/crear los tickets de fases** en `tickets/` (y `docs/TICKETS.md` al día) para que cada fase sea un encargo lanzable en serie, con criterio de terminado verificable en simulador (tamaños de iPad, Split View, y el Duo si hay simulador/perfil). Marca la §5.1 como **aprobada por Jürgen el 2026-09-27**.

## MODO AUTÓNOMO (override)
La regla del repo «wait for approval if >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA para este encargo. Trabaja de punta a punta: PR contra `2.1`, merge y `/cerrar-total`, sin preguntar si sigues, dejando `tickets/` y `docs/TICKETS.md` al día. Cualquier bug o decisión nueva que encuentres se convierte en su propio ticket antes de cerrar.
Día/noche (hora Lima; ahora son ~20:30): hasta las 21:00 puedes usar AskUserQuestion solo para una decisión real de producto o de acceso. De 21:00 a 06:00 elige la opción recomendada sin preguntar, o apárcala como ticket si es demasiado consecuente.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR;
  (3) terminaste y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Qué NO hay que tocar
- Código Swift de la app: solo docs y tickets.
- Nada de sync / nube / migración (Cola A va en otra sesión).
- `marketing/`.

## Cómo se sabe que está bien
- Doc actualizado con fuentes (URLs de Apple), hecho vs. suposición separados, Duo cubierto sin specs inventadas.
- Tickets de fases listos, ordenados y lanzables en serie, con criterio de terminado verificable en simulador; `docs/TICKETS.md` al día; §5.1 marcada aprobada (2026-09-27).
- PR contra `2.1` mergeado.
- `/cerrar-total`.

---

## Enmiendas de Jürgen durante la sesión (2026-09-27)

1. **20:27 — mejoras de iPhone.** Se sustituye «el iPhone actual (compact) no cambia ni un píxel» por: «se permiten
   mejoras de adaptación en iPhone si no rompen flujos ni ponen en riesgo la release 2.1; cada una verificable en
   simulador con capturas antes/después en tamaños iPhone pequeño/grande y Dynamic Type grande». Van como tickets
   propios priorizados, con ese criterio de terminado.
2. **20:28 — regla de simulador.** Este carril usa simuladores dedicados con prefijo `YalaLane-Adapt-`, siempre por
   UDID; prohibido `shutdown all`, `erase all`, `killall Simulator` o tocar simuladores sin ese prefijo (Cola A los usa
   en paralelo). DerivedData propio del worktree. Va al plan y a cada ticket de fase.

## Paso 0 (Frank, 2026-09-27)

Medido antes de decidir:

- **Hay documentación oficial del iPhone Duo**, publicada el 9-sep-2026: HIG «Designing for iPhone Duo», artículo
  «Preparing your app for iPhone Duo», seis charlas técnicas y el simulador en **Xcode 27.1 beta**. Las APIs propias
  del Duo (`ArrangementView`, `ReservedRegion`, `toolbarVerticalBehavior`, `toolbarVerticalEdge`) son **iOS 27.1
  beta**; Yala tiene deployment target 26.0, así que irían tras `if #available`.
- **Esta Mac tiene Xcode 27.0**, runtimes iOS 26.5 y 27.0, ningún tipo de dispositivo Duo y 15 GB libres. Sí tiene
  `DeviceHub.app` (el sucesor de Simulator.app), que la exploración del 26-sep no contó.
- El navegador (Chrome) se rechazó en la primera llamada; la documentación se leyó con descarga directa de las mismas
  páginas de developer.apple.com (su JSON público y las transcripciones de las charlas).

Decisiones (autónomo; ninguna es de producto que no tomara ya el encargo):

- **Documento nuevo** `docs/exploracion/adaptativo-ipad-duo.md`, enlazado desde `ipad-nativo.md`. La exploración del
  26-sep queda como registro de lo medido; el documento nuevo es el plan vigente. Así no se reescribe una medición
  con una decisión.
- **El Duo se cubre adaptando la misma app, no con una app aparte.** Apple lo dice en su HIG: sigue siendo iPhone, con
  compact en la pantalla exterior y regular en la interior. `iphone-duo-native-app` deja de ser una idea abierta y
  pasa a ser el ticket de la fase Duo, con el mismo id.
- **§5.1 se aprueba con un ajuste**: en vez de «`NavigationSplitView` solo en regular y la pila de hoy en compacto»
  (un `if` por size class en la raíz), un único `NavigationSplitView` que se pliega solo en compacto. Es lo que
  recomienda un ingeniero de Apple en los foros: el `if` en la raíz destruye el estado al redimensionar, y en el Duo
  se redimensiona cada vez que se abre o se cierra.
- **ADR ahora, no en la fase 1.** La exploración decía que la fase 1 escribiría el ADR al aprobarse §5.1. La
  aprobación ya ocurrió, y escribirlo hoy evita que dos fases lo interpreten distinto.
- **Mejoras de iPhone como fase propia** («fase iPhone», cuatro tickets). Van después de la fase 0 y antes de la fase
  1, porque son baratas y de bajo riesgo. El horizontal en iPhone **no** entra como mejora de bajo riesgo: en un
  iPhone Pro Max girado el ancho pasa a regular y pintaría la interfaz de iPad. Va como ticket propio, con decisión
  de producto y recomendación: después de la fase 1.
- **`DS.Adaptive.usesLargeSheets` decide por tipo de dispositivo** (`DesignTokens.swift:429-432`), justo lo que Apple
  pide no hacer. En el Duo abierto, las hojas saldrían con los detents de iPhone en una pantalla de 7,6". Ticket
  propio, previo a la fase 1.
- **Xcode 27.1 en esta Mac es un requisito de acceso de Jürgen**: es beta, pesa varios GB y el disco está en 15 GB.
  Queda como ticket y bloquea solo la verificación de la fase Duo. No se pregunta ahora porque no frena este encargo.
- **La fase 0 sube de urgencia**: Apple documenta que el Duo es el primer iPhone con varias ventanas de la misma app
  y que lo hereda de la configuración de iPad. Yala la tiene encendida, y el Duo sale el 23-oct-2026.
