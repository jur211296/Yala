# Lote P2 · Rendimiento del Panel
toca: `PanelViewModel.swift`, `WidgetDataCache.swift`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial).
Lote producto (cola-2-3-propuesta.md §3 P2). No en paralelo con sesiones que toquen el Panel (S5/P6). La medida en iPhone Release la deja Jürgen; tú deja cómo medirla documentada si no hay device.

Cards:
1. Volver al Panel lo recarga y recalcula entero (~0,7 s).
2. El primer contenido del Panel espera a que termine el arranque.
3. La caché de los widgets bloquea el hilo principal (~0,27 s por reconstrucción).
4. Con dos necesidades filtradas desde Registros, el Panel enseña solo una en su chip y en el widget de necesidades.
5. Al volver a Yala, una pantalla podría quedarse sin actualizar sus números hasta volver a salir (sin medir: deja instrumentación o criterio verificable).

Hecha cuando: las cinco quedan hechas o con criterio verificable; tests en verde. No rediseñes el Panel.

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** La rama nacía de `2.2` y el encargo pide `2.3`: rebasada sobre `origin/2.3`
(71cd790b4) sin commits propios. Las seis páginas de pestaña siguen montadas (`swiftui-ds.md`), así que los
observadores del Panel (`dataVersion`, filtros, tasas, preferencias) ya corren con el Panel oculto: la recarga del
`onAppear` repite lo que ellos ya hicieron. `WidgetDataCache.updateCache` tiene 74 llamadas en producción y ningún
test depende de que escriba en el acto. El cálculo del Panel ya filtra por TODAS las necesidades elegidas; solo el chip
y el widget leen `.first`. El guard `applicationState == .active` sigue en 10 sitios.

**D1 · Card 1 — ¿cómo sabe el Panel que no hace falta recargar al volver?** → Una firma de frescura
(`PanelReloadFreshness`): recarga si nunca cargó, si cambió `dataVersion`, si hubo CUALQUIER guardado de SwiftData desde
la última carga (`ModelContext.didSave`, de cualquier contexto) o si cambió el día. Si no, la vuelta no recarga ni
recalcula.
Por qué: el contador de guardados cubre por construcción a los escritores que no avisan por `dataVersion`, que es el
riesgo que paró el ticket; el inventario de escritores se hace igual y va al ticket. Alternativa descartada: fiarse
solo de `dataVersion` (exige que los 70+ escritores avisen, y el inventario dice que no todos lo hacen).

**D2 · Card 2 — ¿qué se toca del arranque?** → Dos cosas, sin mover el orden del bootstrap: (a) el freno del Panel
deja calcular con la app `.inactive` mientras no esté marcada en segundo plano (el arranque en frío, antes de la
primera activación); el paso a segundo plano sigue frenando por `setBackground(true)` en `.inactive`; (b) un aviso de
datos que llega con un cálculo ya esperando no reinicia la espera: se suma a él. Y (c) la caché de widgets deja de
ocupar el hilo en el paso 9 (D3).
Por qué: son las tres causas medidas en el ticket. Alternativa descartada: reordenar el bootstrap (toca dependencias
medidas en `swiftui-ds.md`).

**D3 · Card 3 — ¿fuera del hilo principal o agrupada?** → Agrupada y diferida: `updateCache` pide la reconstrucción y
una sola corre en una vuelta posterior del main actor (las peticiones de la ventana se funden); `updateCacheNow` para
quien necesita la foto en el acto (tarea de fondo, paso a segundo plano). Al pasar a segundo plano se vacía lo
pendiente; `clearCache` cancela lo pendiente.
Por qué: la card lo admite («o se agrupa») y sacarla del main exige leer los `@Model` desde otro contexto en todo
`buildSnapshot` y sus 15 ayudantes `@MainActor`: no cabe con paridad garantizada en un lote. Alternativa descartada:
`@ModelActor` (refactor de aislamiento con riesgo de divergir de la foto de Siri).

**D4 · Card 4 — ¿qué enseña el Panel con dos necesidades?** → Un chip por necesidad (como etiquetas y monedas, que ya
van así) y el widget resalta y suma todas las elegidas. Tocar una necesidad en el widget sigue siendo «ver solo ésta».
Por qué: el chip de necesidad ya estaba documentado como «uno por valor»; no se rediseña nada. Alternativa
descartada: un chip «Esencial +1» (cambia el diseño del chip de necesidad).

**D5 · Card 5 — ¿se arregla una hipótesis sin medir?** → Se deja instrumentación y un arreglo que no cambia el caso
normal: si `scenePhase` llega a `.active` con `applicationState` aún sin activar, en vez de `return` se espera a
`didBecomeActive` y entonces se suelta el freno y se recarga. La espera deja una línea en Console.app
(`com.yala` / `ForegroundResume`, también en TestFlight; en el repo no hay migas de Sentry, el molde es
`IntentSignalBreadcrumb`), que es el criterio verificable. Se mide además en el simulador con una traza.
Por qué: el `return` es un fallo silencioso permanente si ocurre; esperar la activación cuesta nada si no ocurre.
Alternativa descartada: solo instrumentar (dejaría el posible freno pegado otra versión más).

**D6 · ¿Medida en iPhone Release?** → No hay device en esta sesión: se mide en el simulador con `LoadTimesUITests`
antes y después, y la receta para el iPhone queda en el ticket y en el PR.
