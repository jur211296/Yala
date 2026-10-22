# Encargo: ipad-real-multiwindow-with-per-scene-state (paso 12 del carril adaptativo, fase 4)

Trabaja como Frank en Yala. Una sola sesión Yala; no hay otra en paralelo.

## Lectura obligatoria (antes de tocar código)
1. Ticket: `tickets/backlog/ipad-real-multiwindow-with-per-scene-state.md`
2. Plan paraguas: `tickets/backlog/ipad-native-app.md`
3. Carril: `docs/exploracion/adaptativo-ipad-duo.md` (sims §6.2, reglas de layout y verificación)
4. Depende de lo que apagó multiventana: ticket/PR de `ipad-multiple-windows-share-one-navigation-state`

## Qué implementar
Estado por escena / multiwindow real según el ticket:
- Re-encender multiventana (`UIApplicationSupportsMultipleScenes` en el SceneManifest de Info.plist; NO uses `INFOPLIST_KEY_UIApplicationSupportsMultipleScenes` — no existe en el generador Xcode 27).
- Navegación por ventana: pestaña, modales y bandeja a `@SceneStorage` o estado por escena (no en `SessionState.shared`).
- `AppRouter` decide a qué ventana va cada intent (widget, enlace, Siri).
- Covers terminales (cierre de sesión, «Un momento más», swap de contenedor) en TODAS las ventanas a la vez.
- `WindowGroup(for:)` para abrir grupo/registro en ventana propia.
- Cumplir criterios «Hecho cuando» del ticket (Device Hub en iPad Pro 13, widget/deep link, covers, review adversarial, gate verde).
- Layout por size class / ancho del contenedor (ADR 2026-09-27), nunca por tipo de dispositivo.
- Español neutro LATAM en copy de usuario si toca.

## Sims (orden Jürgen — obligatorio)
UDIDs recreados hoy en esta Mini (runtime iOS 27.0). Usa SIEMPRE `-destination id=<UDID>`, nunca nombre genérico ni `booted`:

| Nombre | UDID |
|---|---|
| YalaLane-Adapt-iPhone-SE | 3F56CC58-1B35-4C3F-9109-2D6A97573F69 |
| YalaLane-Adapt-iPhone-ProMax | D2A5E333-D6E1-4AB9-99DC-6A4D62BC7E9D |
| YalaLane-Adapt-iPad-mini | D373DF84-7E30-43B2-8CFA-719CFBBAB73E |
| YalaLane-Adapt-iPad-Pro-13 | 8774BC90-8B76-4EE7-B93B-97C8A2ED1969 |

- Solo sims `YalaLane-Adapt-*` por UDID.
- Un sim a la vez: boot → pruebas → apagar/limpiar → siguiente. (Máx 2 solo si no hubiera otras sesiones; hoy hay Insolito/salud, así que 1.)
- Prohibido: `simctl shutdown all`, `erase all`, `killall Simulator`, tocar sims sin el prefijo.
- DerivedData: `-derivedDataPath .ddp` dentro del worktree.
- Nota: un sim recreado pierde «Apps en ventanas» (Ajustes → Multitarea y gestos); sin ella los casos de estrechar ventana de AdaptiveNavigationUITests se saltan. Reactívalo con XCUITest temporal a Preferences si hace falta (sobrevive a arranques siguientes). Ver §6.2 del doc.

## Entrega
- Branch/worktree de encargo desde `origin/2.1` (base al lanzar: `41918a243`).
- Implementar, probar en sims Adapt, gate verde, review adversarial de router/covers.
- PR a `2.1` con auto-merge si es la práctica del repo.
- NO implementes el paso 13 (`ipad-large-and-extra-large-widgets`); eso lo encadena Frank después.

## Cierre (autónomo, no negociable)
Al terminar —éxito, bloqueo o abandono— ejecuta `/cerrar-total` tú solo. Nunca dejes la sesión colgada.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cada ventana monta su propio `ContentView`?** → No. **Una ventana líder** monta `ContentView` (el shell de proceso: arranque, onboarding/Welcome, borrados remotos, cierre de sesión, alertas de sistema, consumidor `.contentView` del router). **Las demás son seguidoras**: montan `MainTabView` con su propia navegación y nada del shell de proceso. Líder = la ventana viva más antigua; si se cierra, la siguiente asciende y monta `ContentView` (mismo camino que el remonte del swap).
Por qué: `ContentView` dispara por `@State` flujos que deben correr una vez por proceso (gracia del borrado remoto, Welcome, aviso de Apple ID); dos copias los duplicarían. Alternativa descartada: gatear cada deber de `ContentView` por ventana — 3.600 líneas, un olvido es un borrado doble.

**D2 · ¿Qué estado pasa a ser por ventana?** → Un objeto `SceneNavigation` por ventana con: pestaña principal y temporal, sub-pestañas (Estadísticas, Planificación, Informes), los destinos pendientes (grupo, gasto de grupo, formulario de grupo, registro), las peticiones de teclado, la visibilidad de la bandeja, del modal de `MainTabView` y el bloqueo del shell. Salen de `SessionState`, así el compilador encuentra cada lector. **Filtros y período siguen globales** (ya eran «compartidos entre Panel y Estadísticas» por diseño).
Alternativa descartada: `@SceneStorage` para la pestaña — restauraría la última pestaña también en iPhone tras un cierre del sistema y cambiaría el arranque que hoy siempre es el Panel.

**D3 · ¿A qué ventana va cada intent?** → Se sella al encolar: la ventana que recibió el enlace (`onOpenURL`) o la notificación (`targetScene`), si no la última ventana que fue la principal (key), si no la líder. Los intents de `.contentView` van siempre a la líder. Si la ventana sellada se cierra, el intent se re-resuelve al drenar. Sin ventanas registradas (host de unit tests) el comportamiento es el de hoy.

**D4 · Covers terminales en las seguidoras** → La seguidora deja de montar su contenido mientras la app está en un estado en el que nada debe operar: cierre de sesión (`SignOutRelaunchView`), forzado de actualización (`ForceUpdateView`), borrado en curso, arranque, y cualquier pregunta bloqueante de la líder (borrado remoto, reinicio de iCloud, cambio de Apple ID, Welcome/onboarding). Para las preguntas enseña «Yala te espera en otra ventana» con un botón que la trae al frente. Desmontar —y no tapar— cierra las hojas abiertas en esa ventana, que es lo que garantiza que no siga operando. Las hojas no bloqueantes de la líder (bandeja, ofertas, invitaciones) no frenan a las seguidoras. El swap de contenedor ya llegaba a todas (`YalaApp`).

**D5 · `WindowGroup(for:)`: ¿ventana mínima o ventana completa?** → Ventana completa de Yala que **aterriza** en el destino: un grupo abre Grupos con ese grupo (por el mismo `pendingGroupID` y sus puertas de aprobación); un registro abre Registros con su detalle. Entrada: «Abrir en una ventana nueva» en el menú contextual de la fila, solo si el sistema admite varias ventanas (`supportsMultipleWindows`; en el Duo cerrado no aparece).
Por qué: reusa los caminos con sus puertas; una vista suelta tendría que repetirlas. Alternativa descartada: detalle suelto en su propia escena.

**D6 · Manifiesto** → `UIApplicationSupportsMultipleScenes = true` en el manifiesto escrito de `Info.plist`; el generador sigue apagado (`…SceneManifest_Generation = NO`).

**D7 · Duo** → No hay simulador del Duo en esta Mac: se anota pendiente en `iphone-duo-native-app`, como pide §6.3.
