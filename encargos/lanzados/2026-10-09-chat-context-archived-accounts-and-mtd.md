---
esfuerzo: high
---
# Yala IA suma las mismas cuentas que el Panel y compara el mes en curso con el mes pasado hasta el mismo día

## Contexto
Card del tablero `tablero-yala-ia-da-saldos-distintos-del-panel-co-obwc` (lista para lanzar, vence 2026-10-10). Tickets: `tickets/backlog/chat-context-treats-archived-accounts-as-excluded.md` (principal) y `tickets/backlog/chat-compares-with-the-month-in-progress.md`. El triage de Frank del 2026-10-07 los confirmó vivos en el código de 2.1. Van juntos porque los dos viven en `FullFinancialContextBuilder`.

Lo que le pasa al usuario: archiva una cuenta, vuelve a incluirla a mano en las estadísticas, y Yala IA y el Panel le dan saldos distintos. Y a mitad de mes pregunta «¿gasto más que el mes pasado?» y le contesta que menos, porque compara lo que lleva del mes con el mes pasado entero.

Según los tickets (son pistas, verifícalas en este árbol antes de tocar nada):
- `FullFinancialContextBuilder` (`Yala/Services/Chat/FullFinancialContextBuilder.swift`, hacia las L106, L113 y L135 en 2.1 de hoy, y el comentario de cabecera de la L12) deja fuera de los cálculos las cuentas con `excludeFromStatistics` **o** `isArchived`.
- El Panel, Estadísticas y los widgets filtran solo por `excludeFromStatistics`. Desde el 2026-10-03 esa es la regla (decisión de Jürgen): «Archivar no decide la suma» (`.claude/rules/session-filters.md`). El chat puede seguir **listando** las archivadas en la metadata.
- El contexto no trae «el mes pasado hasta el mismo día»: es la mayor fuente de respuestas equivocadas del banco de `chat.answer` (las cinco malas de la muestra a mano, «Yes… less»). La app ya resuelve esa comparación en Tendencias (MTD contra MTD): reutiliza esa lógica.
- **Hoy no hay gasto de API**: los créditos los paga Jürgen. Nada de corridas del banco ni llamadas de pago a modelos; todo se prueba con tests locales.

CADENA tras cerrar `distribution-balance-ignores-new-records` (PR #417 en cola de auto-merge a 2.1; card ydrd en done). No depende de ella: trabaja sin esperarla. El PR #416 (`budget-interval-midnight-and-days-left`, ya mergeado) tocó los días que quedan en este mismo fichero: parte de lo que hay en 2.1. Las cards high que quedan necesitan backend/deploy o están en manos de Jürgen; esta es la mejor medium sin decisión pendiente, sin deploy, sin secretos y, quitando el banco, sin gasto de API.

**Simulador compartido ahora mismo:** al lanzar, la sesión `centro-de-mando--kanban-filtros-fecha-lento-y-conteos` tiene booteado el `iPhone 18 Pro` (`A4B39B45…`) con un `xcodebuild test` de Mando. No lo toques ni lo apagues. Mientras siga encendido o haya un `xcodebuild` ajeno corriendo, lee código y escribe tests; antes de compilar, comprueba con `xcrun simctl list devices booted` y `pgrep -fl xcodebuild` que la Mini quedó libre, y si no, espera. Nunca dos simuladores a la vez.

Para orientarte: `CLAUDE.md`, `.claude/rules/session-filters.md`, `.claude/rules/ai-gateway.md`, `.claude/rules/testing.md` y los dos tickets.

## Que se pide
1. Reproducir con test: una cuenta archivada con «Excluir de las estadísticas» apagado suma en el Panel y no en el contexto del chat; y el contexto de hoy no trae el mes pasado hasta el día equivalente.
2. Quitar `isArchived` como criterio de suma del contexto del chat y dejar solo `excludeFromStatistics`, igual que el Panel. Las archivadas pueden seguir listadas en la metadata; actualiza el comentario de cabecera.
3. Añadir al contexto el mes pasado hasta el día equivalente (con la misma lógica MTD de Tendencias, incluidos los bordes: día 31 frente a un mes de 30, febrero, día 1) y que el prompt diga cuándo usarlo. Verifica dónde vive hoy el prompt del chat. Si vive en la app, ajústalo. Si vive en el Worker del gateway, no lo toques (sería un deploy): mete el dato en el contexto con una etiqueta clara y abre un ticket aparte para el prompt.
4. Sin banco ni llamadas de pago: fija el caso de `chat.answer` a mitad de mes con un test local del contexto (qué cifras trae y con qué etiqueta). Deja escrito en el ticket qué caso del banco habría que correr cuando vuelva a haber presupuesto.
5. Tests: las dos reglas de suma (archivada incluida suma, excluida no) coinciden con el Panel; el contexto lleva el MTD del mes pasado con sus bordes. Controles rojos con el código viejo.
6. Anota lo hecho y lo medido en los dos tickets y muévelos según las convenciones del repo.
7. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-yala-ia-da-saldos-distintos-del-panel-co-obwc` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- Los filtros del Panel, Estadísticas y widgets: ya siguen la regla.
- Los días que quedan del presupuesto (otro encargo).
- La tabla de modelos del gateway y el despliegue del Worker.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~24 GB libres el 2026-10-09, por debajo del umbral de 32; limpia primero y, si baja de ~20 GB, para, limpia y sigue).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Rebase al final, sin esperar a nadie: la sesión arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR. Justo antes de abrir su PR, hace `git fetch` y rebasa sobre `origin/2.1`, y resuelve ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados sobre el árbol rebasado, con un solo simulador.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Yala IA suma las mismas cuentas que el Panel, archivadas o no.
- A mitad de mes, el contexto trae el mes pasado hasta el mismo día, con sus bordes, fijado por test (sin banco).
- Tests con controles rojos con el código viejo; builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, tickets movidos, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Decisiones resueltas antes de tocar código (Frank, 2026-10-09, sesión autónoma de día). Medido en este árbol:

1. **Premisa del encargo, medida.** Las tres líneas siguen vivas (`FullFinancialContextBuilder` L106, L113, L135 y la
   cabecera L12). El Panel suma con `computeEligibleAccounts` (solo `excludeFromStatistics`) y cuenta con
   `PanelTotalAccountsLogic.countableAccounts` (excluidas fuera, y las cuentas sistema de Grupos que archiva la propia app).
2. **Qué cuentas suma el chat → las mismas que el Panel.** Movimientos: solo `excludeFromStatistics`. Saldos:
   `PanelTotalAccountsLogic.countableAccounts`, la regla del Panel tal cual; así las cuentas sistema de Grupos archivadas
   por la app (saldo 0) no aparecen como «cuentas» en el contexto. `excluded_accounts` pasa a listar solo las excluidas:
   listar ahí una archivada que suma sería mentirle al modelo. **Asumido:** no se añade una lista aparte de archivadas
   (el ticket lo permitía, nadie lo pide).
3. **Dónde vive el prompt → en la app** (`ChatAssistantService.buildSystemPromptStatic`), no en el Worker. Se ajusta
   ahí. La regla nueva va **dentro de la regla 7** (comparaciones) y no como 16: el banco busca las líneas
   `16. Tono` / `17. Enfoque` literalmente (`gateway/bench/lib/chatAnswer.ts`) y renumerarlas rompería su extracción.
4. **Qué lógica MTD → `DateAlignmentHelper.alignedPreviousInterval`**, la del hero de Tendencias (`InsightsCalculator`):
   el mes pasado hasta el final del día equivalente a hoy, con el clamp que cubre día 31 frente a un mes de 30 y
   febrero, y el día 1 entero. **Con una corrección local:** el helper devuelve un `end` en la medianoche del día
   siguiente, y `DateInterval.contains` es cerrado; aquí se resta 1 s cuando ese `end` no es el clamp al fin del mes
   (regla de `CLAUDE.md`). Los dos heros usan el helper con `.contains` y cuentan esa medianoche: no se tocan
   (Panel/Estadísticas fuera de alcance), va a ticket aparte.
5. **Alcance de «el mes pasado hasta hoy» → todas las comparaciones precalculadas.** El mismo bug vive en
   `categories[]`, `subcategories[]` y `merchants_top_20[]`: su `variation_percent_vs_last_month` compara el mes en curso
   con el mes pasado ENTERO, y el modelo la cita tal cual. Se añade `periods.last_month_to_date` y, por entrada,
   `total_last_month_to_date`; la variación pasa a compararse con ese total y se renombra
   `variation_percent_vs_last_month_to_date` para que el nombre diga lo que mide. `total_last_month` y
   `periods.last_month` se quedan (mes pasado completo, para «¿cuánto gasté el mes pasado?»).
6. **Banco:** no se corre (sin gasto de API). Su réplica TS del contexto (`gateway/bench/lib/chatContext.ts`) se
   actualiza con los campos nuevos para que la próxima corrida los lleve, y se pasa `npm test` del gateway en local
   (sin red). No se toca la tabla de modelos ni el Worker.
7. **Tests:** suite nueva con `now` inyectado y `Calendar` fijo (bordes 15, 31→30, 29/30/31 de marzo→febrero, día 1,
   medianoche del día siguiente) + las dos reglas de suma contra la regla del Panel. Controles rojos: mutantes con el
   código viejo (filtro `isArchived` repuesto, MTD sin el -1 s, variación contra el mes entero).
8. **Cierre:** sin device-QA (no cambia nada visible; la respuesta del modelo se mide con el banco cuando haya
   presupuesto) → card a «done» asignada a frank.
9. **Salió al compilar: el conector de Claude (`mcp/`) porta este contexto** y tenía la misma regla vieja
   (`balances.ts`, `summary.ts`); su golden de paridad (`MCPAppParityGoldenTests` ↔ `mcp/test/golden/app-parity.json`)
   la fijaba y se puso rojo. **Decidido:** alinear el código del conector, regenerar el golden y pasar su suite en
   local. **No se despliega** (se despliega a mano con `wrangler`, fuera del encargo): queda para Jürgen.
10. **Simulador (Jürgen, 10:3x):** la sesión de centro-de-mando tenía el iPhone 18 Pro encendido y esperaba una
    respuesta suya; se compila y se testea en ese mismo simulador sin apagarlo ni arrancar otro.
