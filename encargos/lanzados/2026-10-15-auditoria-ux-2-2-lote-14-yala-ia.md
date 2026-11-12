# Auditoría UX 2.2 · lote 14: Yala IA

> **ALCANCE ESTRICTO:** solo los flujos del lote 14. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 14: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 14).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 14 · Yala IA (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 14.1 | Abrir Yala IA por primera vez | Píldora «IA» del Panel · botón de destellos en Estadísticas y Registros · ⌘K | Puerta Pro → consentimiento «Asistente financiero» → `YalaAIOnboardingView` (5 pasos) → `ChatSheetView` (columna en iPad) | `L/YalaAIOnboardingLogic.swift`, `V/Chat/Onboarding/YalaAIOnboardingView.swift`, `V/Chat/YalaAIChatPresentation.swift` | parcial (`AdaptiveNavigation`, la columna) |
| 14.2 | Tocar Yala IA sin ser Pro | El mismo botón | `UpgradePromptSheet(.chatAssistant)` | `V/Panel/PanelView.swift` (`startChat`) | no |
| 14.3 | Hacerle una pregunta | Caja «Escribe tu pregunta...» | `ChatSheetView` (burbujas, cargando, error, «Reiniciar contexto de conversación») | `V/Chat/ChatSheetView.swift`, `VM/ChatAssistantViewModel.swift` | `ChatMessagingLayout` |
| 14.4 | Usar las sugerencias o los temas | Saludo con 3 sugerencias · botón «Temas» | `ChatGreetingBubble`, `ChatTopicsSheet` | `V/Chat/ChatGreetingBubble.swift`, `ChatTopicsSheet.swift` | `ChatMessagingLayout` |
| 14.5 | Dictar la pregunta | Micrófono de la caja | `VoiceListeningPanel` | `V/Chat/VoiceListeningPanel.swift` | parcial (`ChatMessagingLayout`) |
| 14.6 | Apuntar un gasto hablándole | Respuesta con tarjeta de registro | `ChatTransactionDraftCard` (Guardar / Descartar / Detalles) → `ChatDraftDetailSheet` → «Ver registros creados» | `V/Chat/ChatTransactionDraftCard.swift`, `ChatDraftDetailSheet.swift` | `ChatMessagingLayout` |
| 14.7 | Llegar al límite diario de preguntas | ≥65 de 75 preguntas | «Te quedan %d preguntas hoy» → «Has usado tus preguntas de hoy» | `YS/ChatAssistantService.swift` | no |
| 14.8 | Buscar una conversación anterior | — | No hay historial: «Esta conversación se borra al cambiar de día.» | `V/Chat/ChatSheetView.swift` | parcial (`ChatMessagingLayout`) |
| 14.9 | Personalizar el tono de la IA | Icono de ajustes del chat · Ajustes › «Personalizar resumen IA» | `AIPersonalizationSheet`, `SmartInsightsSettingsView` | `V/Chat/AIPersonalizationSheet.swift`, `V/Settings/SmartInsightsSettingsView.swift` | no |
| 14.10 | Retirar los consentimientos de IA | Ajustes › Privacidad IA | `AIPrivacySettingsView` (3 interruptores, «¿Desactivar esta función?») | `V/Settings/AIPrivacySettingsView.swift` | no |
| 14.11 | Ocultar el botón de Yala IA | Ajustes › Personalización | Interruptor | `V/Settings/PersonalizationSettingsView.swift` | `PersonalizationGroupedList` |

**Visto en el código:**
- El consentimiento sale **antes** de la presentación, con un párrafo denso sobre OpenAI y 13 meses de datos, y se
  titula «Asistente financiero», no «Yala IA».
- La píldora dice solo «IA»; «Pregúntale a Yala» solo lo lee VoiceOver.
- «Reiniciar contexto» es jerga. «Insights, Asistente y Hero del Panel» mezcla nombres internos.
- Hay tres consentimientos de IA separados (voz/imagen, chat, insights).

**Tickets abiertos del lote:** `ai-onboarding-demo-speaks-english-and-dollars`,
`qa/ai-chat-reads-heavier-than-a-messaging-app`, `qa/chat-draft-card-redesign`, `qa/chat-dictation-looks-poor`,
`chat-ignores-expenses-only-mode`, `chat-creates-only-one-transaction-per-message`,
`chat-suggestions-reject-the-users-own-recurring-payments`.
**Cards de 2.2 que lo cambian:** «Partir la IA según modo nube o privado», «Yala IA entiende Grupos…», «Yala en
ChatGPT, Claude y Grok» (el conector MCP). Este lote va **después** de esas decisiones si salen antes.

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L14-1, L14-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 14 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L14.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L14-k-antes.png`, `L14-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
**No esperes la elección de Jürgen.** Cuando termines, `xcrun simctl shutdown all` y cierra normal con /cerrar-total. Frank junta las decisiones después y las guarda en las cards para la fase de implementación.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- La moneda «S/» frente a «PEN» es una preferencia del usuario: nunca la pongas como opción A/B/C.
- Capturas de HOY (de esta sesión) y maquetas reales en el simulador para cada propuesta visual.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 — decisiones (Frank, 2026-10-15, resueltas en autónomo (bypass))

- **Base:** la rama nace de `origin/2.2` (264316453); `git log origin/2.2..HEAD` vacío. PR contra 2.2.
- **Simulador:** iPhone 17 Pro iOS 27.0 (46287CFE), Yala Dev, español de Perú, modo oscuro, semilla `realista` y los
  args `-uitest-*` de `ChatMessagingLayout` (`-uitest-ai-chat-ready`, `-uitest-chat-suggestions`,
  `-uitest-chat-conversation`, `-uitest-chat-draft`). El contador de preguntas se fija con `-chatQuestionsToday N`.
  Fuera del simulador antes de las 9:00 Lima.
- **Sin servidor de IA en el simulador:** el chat real responde «Yala IA no está disponible». Lo que depende de la
  respuesta del modelo se audita con las conversaciones fijas de los XCUITest y por código, y se dice.
- **Formato:** el de los lotes 10–13 (informe.md + `datos-lote-14.json` + `render.py` al HTML acumulado +
  `variantes-L14.html` + cards por script).
- **Bug claro** = texto falso o mal escrito para quien lo lee, una preferencia que no se respeta, una cifra o un
  aviso que no sale cuando toca. Cambiar qué se pide, en qué orden o cómo se ve → card de Jürgen.
- **Bugs que entran en el PR:** (1) la presentación dice «Yala AI» en 10 idiomas cuyo nombre es «Yala IA»/«Yala KI»
  (parte del ticket `ai-onboarding-demo-speaks-english-and-dollars`; los dólares de la demo quedan en su ticket);
  (2) «Te quedan 1 preguntas hoy» y, con 0, nunca sale «Has usado tus preguntas de hoy»; (3) la hoja «Detalles» del
  registro propuesto enseña «PEN» aunque el usuario eligió el símbolo «S/».
- **Maquetas:** `MockL14.swift` + `-mockL14 N`, fichero local que no se commitea; se guarda como
  `maquetas-lote-14.patch` en la entrega.
- **Tickets abiertos del lote:** no se rehacen; si una mejora los cubre, se cita.
- **iPad (columna de Yala IA):** no se recorre; la cubre `AdaptiveNavigation` y el encargo pide un solo simulador.
