# Estadísticas: textos con IA generados solos para PRO con IA aceptada (1 vez al día o ante cambios)

Cierre: **cierra-sola**. Al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `estadisticas-ia-automatica` · Encargo 06 de la cola Yala (antes S35l5) · al cerrar → encargo 07 (lote Grupos). Esfuerzo: high.

## Cards y criterio de hecho
- `tablero-estadisticas-los-textos-con-ia-se-genera-g6ua` — Estadísticas: los textos con IA se generan solos para usuarios PRO con IA aceptada, una vez al día o ante cambios relevantes
  - Hecha cuando: Un PRO con IA aceptada abre Estadísticas y ve textos ya generados y vigentes (máximo uno por día por página, más regeneración ante cambios relevantes con umbral y antirrebote); no PRO o sin consentimiento no dispara llamadas; tests del disparador y del límite; costo por usuario medido y anotado en el PR.

## Contexto
Pedido de Jürgen (2026-11-02 20:34 Lima): hoy los textos con IA de las páginas de Estadísticas no se generan solos. Deben generarse automáticamente para usuarios **PRO** que **aceptaron los términos y permisos de IA**, **una vez al día** o **ante ciertos cambios** relevantes en sus datos.

## Qué se pide
0. Paso 0: localiza cómo se generan hoy esos textos (vistas, servicio de IA, gating PRO y consentimiento), y documenta el flujo actual en el encargo.
1. Disparo automático al abrir la app o Estadísticas (y/o tarea en segundo plano si ya existe infraestructura) cuando: es PRO, IA aceptada, y el texto guardado tiene más de 24 h o hubo un cambio relevante (define un umbral razonable: p. ej. registros nuevos o editados que muevan el total del período; con antirrebote para no llamar en cada edición).
2. Cachear el texto por página y período; mostrar el guardado mientras se regenera. Máximo una generación diaria por página salvo cambio relevante, con techo duro diario.
3. Sin PRO o sin consentimiento: ninguna llamada; se mantiene el comportamiento actual.
4. Errores o sin red: silencioso, reintenta en la próxima apertura; nada de alertas.
5. Tests del disparador, el umbral, el techo diario y el gating. Mide y anota en el PR el costo estimado por usuario al día.

- Si hace falta tocar servidor o claves, primero staging; no subas a producción sin dejarlo documentado.

## Qué NO hay que tocar
Los textos de los términos y del consentimiento de IA, precios o paywall, marketing/, Web/.

## Pie fijo (lanzar-sesion)
- Proyecto Yala, repo `jur211296/Yala`. Versión **2.2**. Base `origin/2.2`; el PR va a `2.2` con auto-merge.
- Una sesión Yala a la vez: no lances otras sesiones Yala ni trabajes en paralelo con otra. Un solo PR para todo este encargo y un solo cierre.
- Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Pipeline serial de la Mini: limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados (nunca las de un worktree vivo); build con `xcodebuild -jobs 2` sin sim booteado; bootear 1 sim; tests; apagar y borrar el sim. `limpiar-mac --apply` al cerrar.
- Pasa cada card a «in qa» (o «done» si no necesita ojos de Jürgen) al abrir el PR, con `--agente` de la sesión.
- Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog), y lista sus títulos en el PR y en el cierre.
- Cierre autónomo: se lanza con `--permission-mode bypassPermissions`. Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
- Al cerrar, Frank publica el digest y lanza el siguiente encargo de `~/Claude/flota/cola-yala/`.

Termina con /cerrar-total.

## Paso 0 (Frank, 2026-11-03)

### Flujo actual, medido en el árbol
- **Tres páginas pintan texto con IA**, de dos servicios:
  - Resumen (hero «Resumen con IA» + Observaciones) y Distribución («De un vistazo») comparten UNA respuesta
    `insights.cards` (`InsightsViewModel` → `InsightsLLMService`). Se guarda en disco por huella exacta del payload
    (`InsightsAIResultStore`, 6 entradas, sin caducidad). Sale sola SOLO al abrir el modo Observaciones
    (`InsightsTabView`, `.task(id: aiContextVersion)`, L11-7). El hero y Distribución piden un toque.
  - Tendencias («En pocas palabras»): `trends.summary` (`TrendsAIViewModel` → `TrendsAIService`), solo con toque, caché
    en memoria 24 h con clave `hashValue` (muere al relanzar). Cualquier cambio de datos o filtro vuelve al CTA.
- **Gating**: `FeatureGateService.canAccess(.smartInsightsAI)` (Pro) + `aiInsightsConsentAccepted`. El gateway exige
  Pro y topa el cubo `insights` a 60/día (`gateway/src/policy.ts`). No hace falta tocar servidor ni claves.
- **Coste por llamada** (banco del 2026-10-07 sobre las peticiones reales, `gateway/src/ai/routes.ts`):
  `insights.cards` = gpt-6-luna, 0,48 USD/1000; `trends.summary` = gpt-6.1-sol, 4,49 USD/1000.

### Decisiones (autónomo, la opción conservadora)
1. **Dónde dispara**: al abrir Estadísticas o volver a primer plano con ella montada (cada pasada de cálculo), no al
   abrir la app: los datos de la IA salen del cálculo de Estadísticas. Sin tarea en segundo plano (la única
   infraestructura BGTask es de la migración). Resumen/Distribución se deciden a nivel del contenedor; Tendencias, en
   su página.
2. **Ranura = página + período + filtros + tono/enfoque/idioma** (todo menos las cifras). Se guarda la última respuesta
   de cada ranura con sus cifras clave y se enseña mientras se regenera.
3. **Cambio relevante**: ±3 registros o un total clave (gasto, ingreso; en Tendencias el total y el flujo) que se mueve
   ≥10 %. Antirrebote: 10 min por ranura entre generaciones y 1,2 s de calma tras el último cambio.
4. **Una al día**: con cifras distintas pero sin cambio relevante, se regenera solo si el guardado tiene >24 h y la
   página no generó nada hoy. **Con cifras idénticas no se regenera aunque tenga >24 h**: diría lo mismo (decisión de
   Jürgen del 2026-10-18 en L11-7: «si no ha habido nuevos registros o algún filtrado no deberíamos necesitar nuevo dato»).
5. **Techo duro**: 4 generaciones automáticas por página y día. Lo manual («Generar», «Regenerar») no cuenta.
6. **Umbral de volumen**: solo con ≥5 registros en el período, el mismo de Observaciones, Distribución y Tendencias.
7. **Errores y sin red**: silencioso. Con texto guardado se queda; sin él vuelve el botón de siempre. Reintenta en la
   próxima pasada. El intento cuenta para el techo aunque falle (acota el gasto).
8. Sin PRO o sin consentimiento: ninguna llamada y la pantalla como hoy.

### Ficheros
Nuevos: `Yala/App/Logic/StatsAIAutoRefreshLogic.swift`, `Yala/Services/StatsAIAutoRefreshStore.swift`, tests.
Tocados: `InsightsAIResultStore`, `InsightsViewModel`, `TrendsAIViewModel`, `TrendsAIService` (Codable), `InsightsTabView`,
`TrendsTabView`, `DetailContainerView`, `qa/coverage-index.json`.
