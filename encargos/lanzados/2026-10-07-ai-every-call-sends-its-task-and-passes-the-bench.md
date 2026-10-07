# Sesión 2 del gateway de IA: la app dice qué tarea pide y las 12 llamadas pasan por el banco

## Contexto
La sesión 1 (PR #387, mergeado a 2.1 y desplegado en staging y producción el 2026-10-07; PR #388 de cierre, mergeado) sacó a gpt-4.1-nano del gateway: la tabla tarea → {proveedor, modelo, parámetros} vive en `gateway/src/ai/`, existe la cabecera `X-Yala-Task`, el banco está en `gateway/bench/` y los resultados en `docs/ai-model-bench-2026-10.md`. Esa misma sesión escribió el encargo completo de esta: `tickets/backlog/ai-every-call-sends-its-task-and-passes-the-bench.md`. Léelo entero primero: es la fuente de lo que se pide, de las decisiones de Jürgen que lo gobiernan (todas del 2026-10-07, no se vuelven a preguntar) y del criterio de terminado.

Decisiones de Jürgen en una línea cada una: el gateway decide modelo y parámetros por tarea (opción A, sin parches ni pendientes); primero calidad medida y después precio, aunque toque un modelo mayor; comparar con todo el mercado; voz con el mejor motor del mercado por calidad medida en los 10 idiomas de la app (es, en, pt, fr, de, it, nl, pl, ja, zh-Hans) y sus variantes (es-419, es-AR, es-ES, en-GB, pt-BR, pt-PT), con acento peruano y ruido; gpt-4o-mini-transcribe descartado; cualquier motor de voz que no funcione bien en los 10 idiomas se descarta; imagen «lo más óptimo»; cuota free de voz y foto como cupo de prueba (opción B: 5 notas y 5 fotos en total por dispositivo, 1 nota = 1 uso). La revisión trimestral de modelos ya la dispara una rutina de Frank (día 6 de ene/abr/jul/oct): el paso 8 solo deja documentado eso en `gateway/bench/README.md`.

## Qué se pide
Los pasos 1 a 9 del ticket, en ese orden. El ticket marca qué tickets cierra; muévelos a done al terminar.

## Qué NO hay que tocar
- No encender un segundo proveedor en producción sin cumplir todos los requisitos del paso 7 (textos de consentimiento y permisos en todos los idiomas, política de privacidad web, DPA, claves, LEGACY_OVERRIDES). Si el banco lo justifica pero falta algo de eso, se deja preparado y apagado, y se dice en el cierre.
- La política de privacidad web en 2.1 no se publica hasta que se fusione o se haga cherry-pick a 1.0 (producción de la web sigue a 1.0). No publiques web.
- Las versiones instaladas siguen recibiendo OpenAI (no romper `routeFor`).
- Deploy del gateway: igual que la sesión 1, primero staging verificado y después producción, con rollback anotado. Si algo falla en staging, para antes de producción. Entre 21:00 y 6:00 Lima no toques producción: déjalo listo y sigue con lo demás.
- Paso 9 (cuenta y clave de OpenAI con el correo de Yala): si crear el proyecto o la clave exige a Jürgen en la consola, pídeselo y sigue con el resto mientras tanto. Si creas cualquier clave o secreto, dilo en el cierre con su nombre y dónde quedó, para que Frank lo pase a 1Password (vault Yala); no lo dejes solo en el Llavero.
- Las claves de banco disponibles en la Mini son las mismas que usó la sesión 1; no uses la clave del Worker de producción para el banco.

## Mini: pipeline serial y limpieza
La Mini tiene 16 GB de RAM y ~21 GB libres. Pipeline serial, sin solapar: (1) limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, (2) `xcodebuild -jobs 2` sin simulador encendido, (3) encender un solo simulador, (4) tests, (5) apagar y borrar ese simulador. Prohibido solapar swift-frontend + SpringBoard + app + UITests.
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados o con PR mergeado; no toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.
Gate: justo antes del gate, mira si hay un PR anterior de Yala en CI hacia 2.1. Si sigue, espera a que entre y rebasa una sola vez con el simulador apagado; si 2.1 no se movió, sigue; si ese CI falla, rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Capturas
El selector de idioma de voz y el mensaje de pasarse a Pro al acabar el cupo se ven: deja `capturas/antes.png` y `capturas/despues.png` (o con sufijo por pantalla) en el worktree y lista las rutas en el resumen.

## Cómo se sabe que está bien
El «Hecho cuando» del ticket, más: PR a 2.1 con el parte en el cuerpo, CI en verde o con los rojos explicados, gateway desplegado y verificado en staging y producción (salvo que algo lo impida y se diga), guion de device-QA en `tickets/qa/` si hay algo que Jürgen deba probar en el iPhone, y la Mini limpia (sin sims encendidos ni datos de devices, worktree retirado si el PR ya entró).

Al terminar, corre `/cerrar-total` tú solo, sin esperar a Jürgen.

## Paso 0 — decisiones

> Lo técnico se resuelve en autónomo (bypass) y se discute en el PR. Lo de acceso y el alcance del cupo se le
> preguntan a Jürgen en una ronda (sesión diurna, 15:45 Lima).

**D1 · Cómo manda la app la tarea** → `ProxyClientFactory.makeOpenAI(task:)` con un `ProxyTask` de 11 casos (los de
`TASKS` menos `insights.contextual`). La categoría sale de la tarea y la app sigue mandando `X-Yala-Category` (derivada,
siempre casa). Test por servicio que lee la cabecera de la petición que sale de verdad.
Por qué: una sola fuente de la verdad para tarea y cubo. Descartado: dejar `category:` y añadir `task:` (dos datos que pueden no casar).

**D2 · El cubo con cabecera** → con `X-Yala-Task` conocida, el cubo es el de la tarea; una `X-Yala-Category` presente
que no case sigue dando 400; ausente, vale. Por qué: cierra la mitad de `gateway-proxies-any-model-and-any-length` sin
romper a nadie. Descartado: ignorar del todo la categoría (se pierde la señal de un cliente mal cableado).

**D3 · Qué filas pasan a `managed`** → las nueve de la app de hoy (todas menos `legacy.passthrough` e `insights.hero`,
que solo mandan versiones viejas con `gpt-4.1-mini`, sin fecha de apagado). Hasta que el banco elija, la fila reproduce
los parámetros de hoy. Por qué: el gateway decide todas las llamadas de la app actual; lo que no se puede identificar sale como siempre.

**D4 · Longitud** → tope de salida por fila (p99 del banco ×2) y tope de cuerpo por tarea; `photo.read` exige imagen.
Por qué: es lo que falta de `gateway-proxies-any-model-and-any-length`.

**D5 · `insights.contextual`** → se borra de la app y del gateway. Medido: su único llamador se quitó el 2026-04-12
(`7eac1de3e`) y el gateway nació en junio, así que ninguna versión que habla con él la manda.

**D6 · Selector de idioma de voz** → «Idioma de la app» (por defecto, sustituye a «Sistema» y sigue al idioma elegido en
Yala) más los 10 idiomas. Nada cae a inglés por no reconocerse. Por qué: es lo que pide el paso 4 y deja dictar en otro
idioma a quien lo necesite. Descartado: quitar el selector (no habría forma de dictar en un idioma distinto al de la app).

**D7 · Cupo de prueba** → contador sin ventana por dispositivo para `voice` y `vision` del plan free (5 y 5). Transcribir
cuenta 1 y deja un crédito de 10 min para leer esa nota; leer con crédito no cuenta. Vale igual para las versiones
instaladas, que no mandan ninguna marca de nota. Un 5xx o un corte del proveedor devuelve el uso. Agotado: 403
`yala_trial_exhausted` y la app enseña el paso a Pro. Por qué: con 5 usos en total, perder uno por un fallo ajeno se nota.
Descartado: una cabecera de nota (las versiones instaladas seguirían gastando 2).

**D8 · `maxEdge` de la foto** → el gateway lo publica en `/config` (`ai.photoMaxEdge`, sale de la fila `photo.read`) y la
app reduce antes de subir, con 1536 si no lo tiene. Por qué: si la fila cambia de modelo, el tamaño viaja sin release.

**D9 · Divisas del prompt de la foto** → reglas para ¥ (JPY o CNY según el texto), R$, zł, CHF y «$» solo (la divisa
principal del usuario si usa «$», si no `null`). Se cierra con ello `vision-reads-every-dollar-sign-as-usd`.

**D10 · Segundo proveedor** → solo con cabecera y con los siete requisitos del paso 7. La política web no se puede
publicar desde 2.1 en esta sesión, así que, si el banco lo justifica, queda preparado y apagado.

**D11 · Cómo se reparte el banco** → tres trabajadores en paralelo con ficheros disjuntos: voz, tareas de texto del chat
y de la nota, y tareas de Insights/Tendencias. La latencia se mide en serie y con un candado para que nadie más corra a
la vez. Presupuesto estimado: ≈ 35 USD entre todo.

**D12 · Despliegue** → staging verificado y después producción, antes de las 21:00 o desde las 6:00 del día siguiente.

**D13 · Revisión periódica** → `gateway/bench/README.md` documenta la rutina trimestral que ya existe (día 6 de ene, abr,
jul y oct) y el disparo extra ante un apagado anunciado.

**Ronda con Jürgen (2026-10-07, ~15:50 Lima), las cuatro contestadas:**

- **J1 · Verificación** → token de 15 min en producción (dispositivo ficticio, como el 7-oct) y un `DEV_SHARED_SECRET`
  nuevo solo en staging, guardado en `~/Secrets` para pasarlo a 1Password. Pruebo yo free y Pro, cupo incluido.
- **J2 · Claves de Deepgram, AssemblyAI y ElevenLabs** → las crea Jürgen en `~/Secrets/yala-ai-bench/`; el banco de voz
  las recoge si llegan y sigue mientras con el resto.
- **J3 · Paso 9** → lo hago yo desde su Chrome con la sesión de platform.openai.com del correo de Yala.
- **J4 · Cupo** → por instalación (la identidad de App Attest): reinstalar da otro cupo.
