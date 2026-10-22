# Exploración: Yala bien hecha para iPad (misma app universal), con capturas y plan por fases

## Contexto
Jürgen quiere explorar una versión de Yala que aproveche el iPad. Decisión ya tomada: NO una app aparte, sino
adaptar la app universal existente (el proyecto ya tiene `TARGETED_DEVICE_FAMILY = "1,2"`; solo ~6 ficheros Swift
usan `NavigationSplitView`/`horizontalSizeClass`). Hoy probablemente en iPad se ve la interfaz de iPhone estirada.
En paralelo corren otras sesiones de Yala (sync de Cola A y conector MCP), y está pendiente el rediseño UI/UX de
Cola B (ajustes como listas iOS, peso del chat Yala AI, hoja de cuenta, widgets…). Mira sus tickets en `tickets/`
para que el plan de iPad encaje con ese rediseño y no lo duplique. La implementación irá después de Cola B,
probablemente tras la release 2.1.

## Que se pide
- Compilar la app y abrirla en el simulador de iPad (un iPad grande y uno pequeño, vertical y horizontal, y en
  Split View / Stage Manager si es viable), con datos ficticios locales. Recorrer cada pantalla principal y hacer
  capturas.
- Documento `docs/exploracion/ipad-nativo.md` con: estado actual pantalla por pantalla (con capturas en el repo,
  carpeta de la exploración), qué se ve mal o desaprovecha el espacio, propuesta de estructura para iPad (barra
  lateral + lista + detalle, multitarea, teclado y atajos, puntero, drag & drop, widgets grandes, menús
  contextuales), riesgos técnicos (estado compartido entre ventanas/escenas múltiples y su efecto en la sync de la
  nube, rendimiento), qué cambios de Cola B conviene hacer ya «pensando en iPad», y un plan por fases con tamaño
  estimado de cada fase.
- Tickets en `tickets/backlog/` por fase o pieza clara (con prioridad acorde a «después de 2.1», salvo lo que deba
  entrar en Cola B, que se marca como tal), y `docs/TICKETS.md` al día.

## Que NO hay que tocar
- Código Swift de producción ni el target: esta sesión no cambia la app. Nada de datos reales de usuarios.
- `mcp/`, staging y producción de Supabase.
- Marketing (capturas de App Store o fichas): no es de este encargo.
- Si chocan `tickets/` o `docs/TICKETS.md` al integrar, rebasa sobre origin/2.1 y recuenta.

## Como se sabe que esta bien
- Documento con capturas reales del simulador de iPad y plan por fases concreto, tickets creados.
- PR a 2.1 mergeado, `docs/TICKETS.md` al día, `/cerrar-total`.

## MODO AUTÓNOMO
Queda suspendida para este encargo la regla del repo de esperar aprobación si hay más de 3 ficheros y el «¿Sigo?»
tras el plan: haz el trabajo de punta a punta (PR, merge, `/cerrar-total`) sin pedir permiso para seguir. Es horario
diurno (Lima): puedes preguntar a Jürgen con AskUserQuestion solo lo que sea de producto o acceso de verdad; lo
demás lo decides tú eligiendo la opción robusta.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿En qué simuladores?** → iPad Pro 13" (M5) como grande e iPad mini (A17 Pro) como pequeño, iOS 26.5, en vertical y horizontal.
Por qué: son los extremos de tamaño que ya existen en esta Mac y no hay que crear ni descargar nada, con el disco justo. Alternativa descartada: iOS 27.0, porque no tiene devices creados.

**D2 · ¿Cómo se gira el simulador?** → Con un XCUITest temporal (`XCUIDevice.orientation`) que recorre las pantallas y guarda capturas. No se commitea.
Por qué: esta Mac no tiene Simulator.app y `simctl` no sabe rotar. Alternativa descartada: capturar solo en vertical, que deja fuera medio encargo.

**D3 · ¿Split View o Stage Manager?** → No se puede montar en esta Mac: sin Simulator.app no hay forma de abrir una segunda app ni de redimensionar la ventana. Se documenta lo **inferido** del código: en una ventana estrecha el size class pasa a compacto y sale la interfaz de iPhone. Queda marcado como no medido y con un paso en el ticket de multiventana para medirlo en un iPad real.
Por qué: el encargo lo pide «si es viable», y no lo es aquí. Alternativa descartada: instalar otro Xcode, que no cabe en disco.

**D4 · ¿Qué datos?** → `-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed realista`: el store es local, sin CloudKit ni backend.
Por qué: 730 días de datos ficticios llenan cada pantalla como la de un usuario real. Alternativa descartada: `minimal`, que deja pantallas medio vacías y oculta los problemas de densidad.

**D5 · ¿Formato de las capturas?** → JPEG de 1000 px de ancho (1400 en horizontal) en `docs/exploracion/ipad-nativo/`.
Por qué: el PNG nativo pesa unos 3 MB por captura y hay unas 30. Alternativa descartada: el PNG a tamaño completo, que infla el repo para siempre.

**D6 · ¿Qué hacer con el ticket `ipad-native-app` que ya existe?** → Pasa a ser el paraguas: se actualiza con enlace al documento y a los tickets de fase. No se crea otro «épico».
Por qué: dos tickets con la misma idea divergen. Alternativa descartada: descartarlo, porque perdería su historial (del 9-sep).

**D7 · ¿Qué estructura se propone?** → La `TabView` actual con `.tabViewStyle(.sidebarAdaptable)` y secciones: el mismo código da barra de pestañas en iPhone y barra lateral en iPad. Dentro de las pestañas con lista y detalle (Registros, Planificación, Grupos, Ajustes), una `NavigationSplitView` de dos columnas solo en regular.
Por qué: una sola ruta de navegación para las dos plataformas, y el `AppRouter` sigue funcionando. Alternativa descartada: una `NavigationSplitView` raíz aparte para iPad, porque duplica la navegación y el router tendría dos consumidores por destino.

**D8 · ¿Cómo se marca lo que entra en Cola B?** → No existe un campo «cola» (medido). Se añade `cola-b` al `area` del ticket y una línea «Entra en Cola B» en el cuerpo. No se inventa un campo nuevo en el schema.
Por qué: el `area` ya es texto libre y se puede buscar con grep. Alternativa descartada: añadir un campo al schema de `docs/TICKETS.md`, que es una decisión de proceso que no toma este encargo.

**D9 · ¿Qué prioridades?** → Fases post-2.1: `medium` para la fase 1 (barra lateral y lista-detalle) y `low` para las siguientes. Lo de Cola B, `medium`. La multiventana que ya está encendida, `high`: afecta a quien use Yala en iPad **hoy**, así que no espera a 2.1 si se confirma.
Por qué: el encargo pone el listón en «después de 2.1», salvo Cola B. Un riesgo vivo no espera a una fase.

**D10 · ¿Cómo se entrega?** → PR a `2.1` y merge con el CI en verde, aunque el diff solo tenga docs, tickets e imágenes. El XCUITest temporal y el symlink de `Secrets.xcconfig` quedan fuera del commit.
Por qué: lo pide el encargo, y un PR deja a la vista las capturas. Alternativa descartada: commit directo a `2.1`, que la regla del repo permite para docs, pero que el encargo no pide.

**D11 · ¿ADR?** → No. La estructura de D7 es una **propuesta** que Jürgen no ha aprobado. El ticket de la fase 1 pide escribir el ADR cuando se apruebe.
Por qué: un ADR de algo no decidido es ruido. Alternativa descartada: ninguna razonable.
