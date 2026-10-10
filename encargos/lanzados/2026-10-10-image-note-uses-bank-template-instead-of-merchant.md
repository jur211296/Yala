---
esfuerzo: medium
---
# La lectura de imagen pone en la nota texto del banco en vez del comercio

**Card:** tablero-la-lectura-de-imagen-pone-en-la-nota-tex-tkun · **Prioridad:** high · **Versión:** 2.1 (antes del QA de Jürgen)

Reporte de Jürgen (10-oct 08:48), con un caso real: la nota salió «GROK XAI - Consumo con tarjeta de crédito BCP» y debería ser algo como «Grok (xAI)». Captura: `~/Claude/tmp-frank/image-note-bank-template-grok-xai.png`.

## Dónde se arma hoy (medido por Frank en origin/2.1)
- `Yala/App/Services/ImageVision/VisionDraftFactory.swift` → `buildNote(merchant:note:)` une `merchant` + " - " + `note` del modelo. La segunda mitad es la frase de plantilla del banco.
- El prompt y el esquema de la imagen salen de la app (`ImageVisionService.analyze`, tarea `photo.read` del gateway en `gateway/src/ai/tasks.ts`). El esquema con `merchant` y `note` está en `gateway/src/ai/routes.ts` y `gateway/src/ai/schemas.ts`.
- Revisa si la voz y el chat (`TranscriptionParserService`, `text.parse`), el PDF y los extractores OCR (`ScreenshotSingleExtractor` y `ScreenshotListExtractor`) comparten esa lógica. Si la comparten, que el arreglo los cubra.
- No hay ningún ticket previo igual.

## Qué se pide
1. Que la nota sea lo esencial: el nombre del comercio limpio y legible (capitalización normal, la marca conocida si se reconoce, p. ej. «Grok (xAI)») y, solo si hace falta, un dato útil para saber dónde se gastó (sucursal o ciudad). Nunca texto de plantilla del banco («Consumo con tarjeta de crédito BCP», «compra con tarjeta», «operación», «pago», números de operación, códigos de terminal o de POS, asteriscos).
2. Hazlo en el prompt o el esquema (pedir `merchant` limpio y `note` vacía o útil) **y** con una limpieza determinista en la app (lista de frases de banco por idioma y por banco, quitar códigos). Así también se arreglan las respuestas de modelos viejos.
3. Tests unitarios de la limpieza con casos reales de BCP, Interbank, BBVA, Scotiabank, Yape y Plin (ES y EN).
4. Mídelo en el banco de IA (`gateway/bench`) con esos casos: la nota buena antes y después, y que no empeoren el monto, la fecha y la categoría (reporta las cifras). **Presupuesto de API: tope de 3 USD en total para la sesión**, con las claves del banco (OpenAI, Gemini, xAI, Anthropic). Si se acerca al tope, para y anótalo.
5. Si hace falta cambiar el gateway (esquema o prompt del lado del Worker): deploy autorizado, con la mejor práctica. Primero staging, verificar, después producción con prueba de humo y anotar la versión antes y después y el rollback. **Compatible con las versiones de la app que ya están afuera**: no quites campos ni cambies tipos; añade solo campos opcionales. Si el deploy pide un secreto o un login que no tienes, para y anótalo. Si todo se arregla en la app, no despliegues nada.
6. Device-QA corto para Jürgen en el cierre: leer 2 o 3 capturas reales (BCP, Yape) y mirar la nota.
## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Gateway: no se toca ni se despliega.** Medido: el prompt de `photo.read` sale de la app (`ImageVisionService.systemPrompt`); el gateway solo impone `PHOTO_SCHEMA` (con `merchant` y `note`, que siguen igual). El arreglo cabe entero en la app.
2. **Dónde se aplica:** foto y PDF (los dos pasan por `VisionDraftFactory.buildNote`). **Voz y chat no**: su nota sale de lo que dice el usuario (el prompt ya pide «note = el comercio») y una limpieza de plantilla podría comerse «pago de luz». **Extractores OCR (`ScreenshotSingle/ListExtractor`) no**: no los llama nadie fuera de sus tests.
3. **Dos capas:** el prompt pide `merchant` limpio y `note` null o un dato útil; y `VisionNoteCleaner` (lógica pura, `Yala/App/Logic/`) limpia de forma determinista: trozos de pura plantilla fuera, plantilla de los bordes fuera, códigos (≥4 dígitos, referencias), banco fuera, MAYÚSCULAS → normales, marcas de descriptor conocidas («Grok (xAI)», Uber, Netflix…). Si no queda nada, conserva lo leído sin códigos (perder todo es peor).
4. **`evidence` del draft sigue con el comercio crudo**: es la evidencia de lo leído.
5. **Banco:** casos sintéticos nuevos de alertas BCP, Interbank, BBVA, Scotiabank, Yape y Plin (ES/EN), métrica nueva de nota en `gradePhoto` con la limpieza REAL (el banco compila `VisionNoteCleaner.swift`). Antes/después con `gpt-6-luna` (la fila de producción), todos los casos de foto. Categoría: la foto no la devuelve (sale de la memoria de comercios), así que no se puede medir en el banco; se dice. Tope 3 USD.
