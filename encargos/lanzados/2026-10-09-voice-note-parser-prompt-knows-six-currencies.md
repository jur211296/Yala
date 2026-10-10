---
esfuerzo: high
---
# La lectura de voz conoce la divisa del usuario («5000 pesos» en Argentina sale en ARS) y pide JSON estricto, así que una respuesta mal formada ya no rompe el registro

## Contexto
Card del tablero `tablero-voz-5000-pesos-en-argentina-sale-en-otra-cs7q` (lista para lanzar, vence 2026-10-10). Tickets: `tickets/backlog/voice-note-parser-prompt-knows-six-currencies.md` (principal) y `tickets/backlog/voice-parser-sends-no-json-mode.md`. El triage de Frank del 2026-10-07 los confirmó vivos en el código de 2.1. Van juntos porque los dos viven en `TranscriptionParserService`.

Lo que le pasa al usuario: dicta «30 francos» en Suiza y el borrador sale en EUR; dicta «5000 pesos» en Argentina y sale en MXN o PEN. Y cuando el modelo devuelve algo que no es JSON limpio, el registro por voz, por Siri o desde el chat falla con un error genérico y hay que repetir la frase.

Según los tickets (son pistas, verifícalas en este árbol antes de tocar nada):
- El prompt de `TranscriptionParserService.parseMultiple` (`Yala/Services/TranscriptionParserService.swift`, ~L240 en 2.1 de hoy) enseña seis divisas y no recibe la divisa principal del usuario. Es el mismo arreglo que el paso 6 bis hizo en la foto (`VisionCurrencyContext`): pasar la divisa principal y las de las cuentas, y enseñar los nombres de las divisas de los 10 idiomas.
- Jerga y decimales: «18 lucas» en Lima se lee como 18 000 (una luca es un sol); «28 euros e 30» se parte en dos movimientos; una nota japonesa de 860 円 sale a veces en soles.
- `parseMultiple` construye la `ChatQuery` sin `responseFormat`: es el único servicio de IA de la app sin modo JSON. Lo usan la hoja de voz, el chat (rama «registrar») y el atajo de Siri (`QuickExpenseIntent`). `parseMultipleResponse` (~L288) quita a mano vallas de markdown.
- El SDK del proyecto (MacPaw/OpenAI 0.4.7) soporta `responseFormat: .jsonSchema(...)` con `strict`. En modo estricto todos los campos son obligatorios: los opcionales se declaran `["string","null"]`. Comprueba que el gateway deja pasar `response_format` para la tarea `text.parse`.
- El prompt se contradice en tres sitios: el esquema dice `"date": "YYYY-MM-DD"` y «Sin mención de fecha → hoy» (`DateContextProvider.swift`), pero el tercer ejemplo devuelve `"date": null`; el primer ejemplo pone la fecha de hoy con `"confidence": {"date": 0.0}`; el tercer ejemplo propone `subcategoryHint: "Transporte"`, que no tiene por qué estar en la lista del usuario.
- Banco: `npm run bench -- --task text.parse` sacó 97,7 % el 2026-10-07. La clave del banco cobra del mismo saldo prepago que producción (`.claude/rules/ai-gateway.md`): pon tope de gasto por corrida.

Antes de esta sesión va en la cola `chat-context-treats-archived-accounts-as-excluded`; no depende de ella.

Para orientarte: `CLAUDE.md`, `.claude/rules/ai-gateway.md`, `.claude/rules/currency-fx.md`, `.claude/rules/l10n.md`, `.claude/rules/testing.md`, los dos tickets y `docs/ai-voice-bench-2026-10.md`.

**Créditos (actualizado 2026-10-09 14:01):** Jürgen confirmó que volvió a haber créditos de Claude, así que sí se puede gastar API en esta sesión. Para OpenAI y Gemini usa las claves del banco con el tope de gasto por corrida de siempre (`.claude/rules/ai-gateway.md`); para Claude, también con tope.

## Que se pide
1. Reproducir con test de prompt y de petición: hoy el prompt no lleva la divisa principal ni las de las cuentas, y la `ChatQuery` no lleva `responseFormat`.
2. Pasar al parser la divisa principal y las de las cuentas (mismo patrón que `VisionCurrencyContext`) y enseñar los nombres de divisas de los 10 idiomas, más la jerga y los decimales coloquiales del ticket.
3. Pasar a `json_schema` con `strict: true` con todos los campos del DTO (los opcionales como `["string","null"]`).
4. Resolver las tres contradicciones del prompt: una sola regla de fecha, ejemplos coherentes con ella y ejemplos que no inventen subcategorías.
5. El limpiador de vallas: mantenerlo mientras haya builds antiguas o retirarlo si el modo estricto lo hace inalcanzable; decídelo midiendo y déjalo escrito.
6. Banco `text.parse` con tope de gasto: igual o mejor que el 97,7 %, con casos nuevos para ARS («5000 pesos») y CHF («30 francos»).
7. Tests: la `ChatQuery` lleva `json_schema` estricto con todos los campos; con divisa principal ARS, «5000 pesos» sale ARS y con CHF, «30 francos» sale CHF (en el banco o con respuesta simulada, lo que sea determinista); ningún ejemplo contradice la regla de fecha ni usa una subcategoría fuera de la lista; los tests existentes de `parseMultipleResponse` siguen verdes.
8. Anota lo medido en los dos tickets y muévelos según las convenciones del repo.
9. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-voz-5000-pesos-en-argentina-sale-en-otra-cs7q` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.
10. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).

## Que NO hay que tocar
- La transcripción (`voice.transcribe`) y su prompt.
- La tabla de modelos del gateway y el despliegue del Worker.
- El flujo de la foto (`VisionCurrencyContext`): se copia el patrón, no se cambia.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~32 GB libres el 2026-10-08, justo en el umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Rebase al final, sin esperar a nadie: la sesión arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR. Justo antes de abrir su PR, hace `git fetch` y rebasa sobre `origin/2.1`, y resuelve ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados sobre el árbol rebasado, con un solo simulador.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Con divisa principal ARS, «5000 pesos» sale ARS; con CHF, «30 francos» sale CHF.
- La petición del parser va con JSON estricto y el prompt ya no se contradice.
- Banco `text.parse` igual o mejor que el 97,7 %, con números en el PR.
- Tests en verde con controles rojos con el código viejo; builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, tickets movidos, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Decisiones resueltas antes de tocar código (2026-10-09, 17:30 Lima):

1. **El JSON estricto vive en el gateway, no en la app.** Medido: la fila `text.parse` es `managed` con
   `responseFormat: "text"`, y las filas `managed` ignoran el formato del cuerpo. Pregunté a Jürgen (sale de «Qué NO
   tocar») y eligió **cambiar la fila y desplegar**: mismo modelo y esfuerzo, formato `json_object` + `TEXT_PARSE_SCHEMA`
   (ya existía) + `strictSchema: true`. Staging primero, después producción. Alcanza también a las versiones instaladas.
2. **La app manda igualmente `json_schema` estricto** en su `ChatQuery` (lo pide el encargo y documenta el contrato);
   hoy no tiene efecto mientras la fila mande. El esquema de la app se ata al del gateway con un test.
3. **Divisas: tipo propio `ParserCurrencyContext`**, con el patrón de `VisionCurrencyContext` (principal + cuentas activas)
   sin tocar la foto. Las familias de nombres compartidos (peso, dólar, franco, corona, libra, rupia, riyal, dírham) se
   RESUELVEN en Swift y el prompt recibe la regla ya decidida («"pesos" → "ARS"»): principal de la familia → la única
   cuenta de la familia → el valor por defecto (dólar USD, franco CHF, libra GBP; el resto `null`).
4. **Una sola regla de fecha**: `date` siempre `YYYY-MM-DD`, sin mención → hoy; `confidence.date` 1.0 si la dijo y 0.5 si
   no. Ejemplos coherentes con ella.
5. **Ejemplos sin subcategorías inventadas**: la pista de cada ejemplo sale de la lista del usuario por palabras clave
   (restaurantes, estacionamiento, supermercado) o es `null`. Las palabras clave viven en Swift y el banco las lee de ahí.
6. **Limpiador de vallas: se mantiene.** Medido: 5 de 528 respuestas históricas del banco traían vallas; con la fila
   estricta es inalcanzable para todas las versiones, pero la fila se puede cambiar sin release y el test existente de
   vallas debe seguir verde (lo pide el encargo). Queda escrito en su docblock.
7. **Siri**: la caché del App Group gana `accountCurrencies` opcional (compatible con la caché vieja).
8. **Banco**: solo `openai:gpt-6-luna` con esfuerzo `low` (la fila), 2 repeticiones; coste esperado < 0,05 USD por
   corrida (0,146 USD/1 000). Tope: se corta si una corrida pasa de 0,50 USD.
