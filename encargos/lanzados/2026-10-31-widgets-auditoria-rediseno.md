---
esfuerzo: max
release: no
---
# Auditar y rediseñar a fondo los widgets de Yala: útiles, modernos y con gráficas

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `widgets-auditoria-rediseno` · Sesión cola **S35f** · al cerrar → **S36** (`barrido-qa-2-2-b`).

## Contexto
Jürgen (2026-10-31 08:12): «Añade en la cola de 2.2 una auditoría veloz de los widgets de WidgetKit, están horribles. Hay que mejorarlos, que se vean bien, dinámicos, modernos, que den valor.» Jürgen (2026-10-31 09:04): «Que se esfuerce bastante, si tiene que ser más de una card no hay problema, quiero que se haga bien y que los widgets sean funcionales, den valor y se vean modernos, con gráficas agradables, fondo adecuado de las cards, respetando el design system.» Calidad por encima de velocidad. Antecedentes: S23 (widgets extragrandes iOS 27) y S27p (divisa principal del widget).

Cards:
- `tablero ver tablero-widgets-auditoria-veloz-y-rediseno-para-hzag`

## Qué se pide
1. Auditoría veloz de todos los widgets del target WidgetKit: tamaños small/medium/large (y extragrande), lock screen y accesorios, iPad/Duo si aplican, modo claro y oscuro, tintado y StandBy. Captura el estado actual de cada uno en `capturas/widgets/antes/` y deja la tabla (qué está feo o no aporta, y qué se hace) en `docs/widgets/AUDITORIA-WIDGETS-2-2.md`.
2. Rediseño alineado al resto de la app: glass, tipografía y colores semánticos del sistema de diseño; que se vean bien en tintado y StandBy.
3. Contenido con valor según lo que ya exponga la app: saldos, gasto del mes vs presupuesto, próximos pagos, grupos, etc. Sin inventar datos nuevos en el modelo.
4. Interactividad con App Intents donde aporte (p. ej. agregar gasto rápido), animaciones de transición de contenido (`contentTransition`, `invalidatableContent`), deep links correctos a cada destino, timelines y refresh correctos (recarga tras guardar), y placeholders/estados vacíos bien hechos. Todo respeta Reducir movimiento.
5. Capturas después de cada widget en `capturas/widgets/despues/`, y el par antes/después de cada uno en el digest.
6. Requisitos explícitos: widgets funcionales con valor real (nada decorativo); gráficas agradables con Swift Charts donde aporten (gasto del mes vs presupuesto, tendencia, distribución); fondo de card adecuado con `containerBackground` según el design system, correcto en claro, oscuro, tintado y StandBy; respeto estricto del design system (tokens de color, tipografía, radios y espaciados que ya existen en el repo; nada de valores sueltos).
Si el trabajo no cabe bien en una sesión, esta sesión hace la auditoría completa + la primera tanda, y crea las cards necesarias en 2.2 («ready to launch», `cierra-sola`, prioridad alta, asignadas a frank), cada una con su brief propio `~/Claude/tmp-frank/sesion-S35fN-<slug>.md` con este mismo formato, encoladas justo después de S35f y antes de `barrido-qa-2-2-b` en `cola-2-2-orden-activo.txt`, y actualizando `al_cerrar_de` en `siguiente-activo.txt` para que se encadenen solas.
Si hay decisiones de diseño grandes, elige el default razonable y anótalo en el digest y en el PR en vez de esperar.
Todo lo que salga de la auditoría y no quepa en la sesión se crea como cards: TODAS en versión 2.2, estado «ready to launch», `cierra-sola`, asignadas a frank (nada queda en backlog ni en otra versión). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido QA.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Lógica de datos de la app (solo lo que leen y muestran los widgets y sus intents). Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas antes/después de cada widget en `capturas/widgets/` y en el digest.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, cierra-sola): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Todo en esta sesión o por tandas?** → Auditoría completa de los 18 widgets y los 2 controles + **tanda 1** en este PR: la base común (tokens, fondo, cabecera, cifras, píldoras, gráficas, frescura, Reducir movimiento) y los widgets de más uso: Saldo, Gastos, Presupuestos, Pagos planificados (incluido su extragrande vertical, que comparte fila), Últimos registros, Entrada rápida y los cuatro de la pantalla bloqueada. Lo demás va a cards hijas 2.2 encoladas tras S35f: **S35f1** Entradas y salidas + Resumen del mes (S/M/L/XL/XLP), **S35f2** Categorías y subcategorías (los dos Top y las dos tartas).
Por qué: la base se valida con los widgets que más se ven y las tandas siguientes solo la aplican. Alternativa descartada: los 18 en un PR — capturas, 16 idiomas y review se vuelven inmanejables y bajan la calidad.

**D2 · ¿Cómo se capturan antes y después?** → Banco de render en `qa/widget-render/` (proyecto aparte generado con `xcodegen`, fuera de los targets de la app): compila las vistas del widget y las pinta con `ImageRenderer` por tamaño (medidas del iPhone 17 Pro), en claro, oscuro y StandBy simulado (sin fondo, sobre negro), con la foto REAL que escribe la app sembrada (`-uitest-seed realista`), la misma antes y después. Tintado y pantalla de inicio real: comprobación aparte en el simulador sobre unos cuantos «después».
Por qué: la galería real cuesta ~15 gestos por widget y se borra al reinstalar (memoria del 2-oct y del 29-oct); el banco da pares idénticos para los ~30 tamaños. Alternativa descartada: solo pantalla de inicio real — días de trabajo y pares no comparables.

**D3 · ¿Qué fondo lleva la card?** → `containerBackground` con el token de tarjeta del tema por defecto (blanco en claro, #1C1C1E en oscuro: los `card` de `YalaTheme`), sin degradados ni brillos; el sistema lo quita en StandBy y lo sustituye en tintado/transparente, así que el contenido usa solo colores semánticos y marca con `widgetAccentable()` una sola cosa por widget (la cifra o la gráfica). Excepción: Entrada rápida, que es un botón, va en relleno sólido de marca con blanco AA (índigo #3D36B3 / rosa #D6006B / turquesa #0F7A80, los rellenos de la app).
Por qué: tarjetas blancas sobre fondo no blanco son identidad (Jürgen, 2-sep) y nada de degradados (13-oct). Alternativa descartada: fondos de color o degradado en los widgets de datos.

**D4 · ¿Qué tokens?** → Espejo nuevo `WidgetDS` con los MISMOS nombres y valores que `DS` (espaciados, radios, opacidades y tipografía) y un test de paridad contra `DesignTokens.swift`; los widgets de la tanda 1 solo usan `WidgetDS`/`WidgetColors`. El `WDS` viejo se queda para los widgets de las tandas siguientes (no cambia su aspecto sin capturas) y lo retira la última tanda.
Por qué: «nada de valores sueltos» con red contra la deriva. Alternativa descartada: cambiar los valores de `WDS` — movería en silencio los widgets que no se tocan.

**D5 · ¿Colores de texto?** → Solo tokens AA: `incomeAmount` (adaptativo #0F7A80/#00C2CB), `overBudgetText` (#D6006B/#FF0080), `electricIndigo`; la paleta (#FF0080, #00C2CB, colores de categoría) solo en rellenos, barras y gráficas. En listas solo el ingreso lleva color (regla de la app). Paridad de los hex con la app por test.

**D6 · ¿Qué enseña cada widget de la tanda 1 (sin datos nuevos)?**
- Saldo S/M: la cifra, cuánto subió o bajó en el período (curva del período: cierre de hoy − cierre del día anterior al inicio) en píldora, y la curva sin ejes de 8 pt.
- Gastos S/M: lo gastado y, en «Este mes» y «Este año», la comparación con el período anterior **a la misma altura** (resumen del mes/año pasado que ya viaja), con la curva acumulada del período y la del anterior punteada.
- Presupuestos M/L: la fila del Panel (insignia sólida, «Te quedan» / «Te pasaste», barra) + marca del ritmo (cuánto del período pasó) en mensual, semanal y anual.
- Pagos M/L/XLP: fila con fecha relativa («Hoy», «Mañana», «En 3 días», «Vencido»), importe sin color salvo ingreso, y «Te falta pagar este mes» de la foto en la cabecera.
- Últimos registros M/L: insignia sólida, título, «categoría · cuándo», importe (solo ingreso con color) y botón «+» de nuevo registro.
- Entrada rápida: azulejos sólidos + tamaño mediano nuevo en «Nuevo registro» con las tres acciones.
- Pantalla bloqueada: cifras compactas con el separador decimal del idioma, presupuesto con aro (`Gauge`) además del rectangular.
Por qué: todo sale de campos que ya viajan en la foto del App Group. Grupos NO viaja → card aparte (D9).

**D7 · ¿App Intents?** → Los toques abren cada destino con enlaces (los que ya entiende `AppBootstrapper`); no se añade ningún `Button(intent:)`. Las acciones en el sitio que aportarían (marcar un pago como pagado, repetir un favorito) escriben datos de la app, que el encargo deja fuera → card a Jürgen para decidir si las quiere. `invalidatableContent()` solo tiene sentido con esas acciones: queda para esa card.
Por qué: abrir la app no necesita un intent y el enlace es el camino probado (`WidgetDeepLinkTests`). Alternativa descartada: botones con los intents de Centro de Control — cambian un camino que funciona sin aportar nada.

**D8 · Movimiento** → `contentTransition(.numericText(value:))` en las cifras y fundido en lo demás; con Reducir movimiento, sin transición.

**D9 · Lo que sale de la auditoría y no entra** → cards 2.2 «ready to launch», `cierra-sola`, alta, de frank: S35f1, S35f2, widget de Grupos (necesita campos opcionales nuevos en la foto), «los widgets no siguen Mostrar variaciones» (la preferencia no llega al App Group). Card a Jürgen (decisión): acciones en el sitio con App Intents.

**D10 · Refresco** → misma política en todos: siguiente medianoche o +4 h, lo que llegue antes (cambian «Hoy/Mañana», el mes y el ritmo); la recarga tras guardar ya existe (`WidgetDataCache.updateCache` → `reloadAllTimelines`). Si la foto es de otro día, pie discreto «Actualizado …».
