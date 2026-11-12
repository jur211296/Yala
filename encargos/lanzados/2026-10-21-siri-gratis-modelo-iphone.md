# Encender Siri gratis con el modelo del propio iPhone (Apple Intelligence) en 2.2, con hoja de Pro como respaldo

## Contexto
Jürgen decidió el 21-oct a las 05:18 (Lima) la opción A de la card «UX 2.2 · L15-6 · Siri gratis con el modelo del propio iPhone: ¿se enciende?» (tablero-ux-2-2-l15-6-siri-gratis-con-el-modelo-d-laik). Ticket: tickets/backlog/siri-free-users-on-device-model-awaits-decision.md.
El camino on-device de Siri ya existe desde el PR #581 (Auditoría UX 2.2 · lote 15, https://github.com/jur211296/Yala/pull/581) y va APAGADO a propósito. Con FoundationModels, un usuario sin Pro y con Apple Intelligence disponible dicta a Siri, el teléfono lee el dictado y deja el borrador en la Bandeja. Ahora toca encenderlo en 2.2.
Regla de producto: en Yala, si el iPhone tiene los modelos de IA de Apple, Siri se puede usar gratis (plan free) con esos modelos. Si el modelo no está disponible, no está listo/descargado o Apple Intelligence está apagado, se mantiene la hoja de Pro como hoy (no el callejón «Activa Yala Pro»). Pro no cambia.

## Qué se pide
1. Encender el flag del camino on-device en 2.2 con el gate: gratis + modelo disponible → borrador en la Bandeja; gratis sin modelo (no disponible / no listo / AI apagado) → hoja de Pro; Pro → camino de siempre.
2. Unit tests del gate con la matriz Pro sí/no × modelo disponible / no disponible / no listo.
3. XCUITest en simulador: forzar modelo no disponible → hoja de Pro; forzar disponible (stub) → borrador en la Bandeja, sin paywall.
4. Señal o telemetría del gate (hoy el gate Pro de Siri no deja señal; ver card de canarios si existe) sin datos personales.
5. Guion de prueba en iPhone para Jürgen: iPhone con Apple Intelligence (15 Pro o posterior), cuenta gratis, «Anota 20 soles en almuerzo» en ES y su equivalente en EN → borrador correcto, anotar tiempo y calidad frente al servidor; iPhone sin Apple Intelligence o con AI apagado → hoja de Pro; Pro sin cambios.
6. Al cerrar: card L15-6 a in qa asignada a jurgen con el guion en la nota.

## Qué NO hay que tocar
- Nada de 2.1. Base origin/2.2 y PR contra 2.2.
- No cambiar el camino Pro ni el del servidor.
- No tocar los iPhones/iPad de Jürgen: él hace la prueba en real.
- Sin textos que nombren «OpenAI». Español neutro en copy.

## Pipeline y Mini
Sola en la Mini, un simulador a la vez. Pipeline serial: limpiar → build con `xcodebuild -jobs 2` sin sim booteado → boot 1 sim → tests → apagar y borrar ese sim. Al lanzar y al cerrar, borra sola el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar.
No esperes el CI de ningún PR: arranca sobre origin/2.2 y haz git fetch + rebase sobre origin/2.2 solo justo antes de abrir el PR.

## Cómo se sabe que está bien
Flag encendido en 2.2 solo con modelo en el dispositivo, respaldo a la hoja de Pro, unit + XCUITest verdes, guion iPhone en la card (in qa a jurgen), PR a 2.2 abierto con auto-merge. Si hay cambio visible, capturas antes/después en capturas/.

/cerrar-total

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Medido antes de decidir: el worktree nació sobre `origin/2.1` (`df498b7cc`) sin commits propios; la rama se movió a
> `origin/2.2` (`e9a8c3d06`, merge de #581). El camino on-device vive en `Yala/App/Intents/SiriOnDeviceEntry.swift` y lo
> elige `SiriEntryRoute.decide` en `SiriNaturalEntryIntent.perform`. Xcode 27.1 con App Intents Testing; un solo
> simulador, iOS 27.0.

**D1 · ¿Cómo se enciende?** → `SiriOnDeviceEntry.isEnabled` pasa a `true` en todos los builds y se retira la clave DEBUG
`debug.siriOnDeviceFreeEntry`. El interruptor se queda como constante: apagarlo es una línea. Descartado: un flag remoto
(nadie lo pidió y añade una dependencia de red al gate).

**D2 · ¿Qué es «modelo disponible»?** → `SystemLanguageModel.default.availability == .available` **y** el modelo admite el
idioma del teléfono (`supportsLocale`). Los motivos se tipan (`deviceNotEligible`, `appleIntelligenceNotEnabled`,
`modelNotReady`, `languageNotSupported`) y todos llevan a la hoja de Pro. Por qué el idioma: Yala tiene 16 y el modelo no
los cubre todos; sin ese término, un teléfono con Apple Intelligence en un idioma no admitido recibiría siempre el borrador
básico en vez de la hoja de Pro. Descartado: decidir solo por `availability`.

**D3 · Si el modelo falla al leer** → el borrador básico de siempre (lectura local del monto, «Borrador básico creado…»).
Sin copy nuevo. Por qué: el gate ya decidió que el teléfono puede; un fallo puntual no debe tirar el dictado.

**D4 · Señal** → dos canarios por `MetricsService`, sin datos personales: `siriEntryRoute` en cada invocación (`detail =
route=<server|onDevice|upgrade> model=<estado>`) y `siriOnDeviceParse` al leer en el teléfono (`detail = ok|noAmount|
failed:<tipo de error>`, `value` = milisegundos). El intent puede correr sin que el arranque haya puesto en marcha el
servicio: entonces el evento va al spool y sale en el siguiente arranque. Bajo `-uitest` y en tests no se emite nada.
Con esto el gate Pro de Siri deja señal (mitad Siri de `canarios-y-breadcrumbs-sin-emisor`, que se anota allí).

**D5 · Seam de QA** → `-uitest-siri-model <available|deviceNotEligible|appleIntelligenceNotEnabled|modelNotReady|
languageNotSupported>`, solo DEBUG. Con `available` la lectura es un stub fijo (el simulador no tiene el modelo).
El test de la condición (el gate) va aparte y sin seam: la matriz pura en unit.

**D6 · XCUITest** → con App Intents Testing (`#if canImport(AppIntentsTesting)`, iOS 27), molde `SiriIntentsUITests`:
gratis + modelo no disponible → hoja de Pro (`upgrade_prompt_cta`); gratis + modelo (stub) → borrador en la Bandeja y
sin hoja de Pro. El CI compila con Xcode 26.6 y ahí la suite no existe, como su molde.

**D7 · Capturas** → ninguna pantalla de la app cambia: la hoja de Pro y la Bandeja son las de siempre; lo que cambia es a
cuál de las dos llega un usuario gratis desde Siri. Se adjuntan las dos del XCUITest como evidencia si salen.

**D8 · Ticket y tablero** → el ticket pasa a `tickets/qa/` con el resultado y el guion de iPhone; fila en
`docs/TICKETS.md`; card L15-6 a `in qa`, asignada a jurgen, con el guion en la nota (conservando la decisión que ya trae).

Sin ADR: es la ejecución de una decisión de producto ya tomada en la card.

## Resultado

- **Encendido en 2.2.** Sin Pro y con el modelo del iPhone listo (Apple Intelligence disponible e idioma admitido),
  «Anotar con Siri» lee el dictado en el teléfono y deja el borrador en la Bandeja. Sin el modelo —no elegible, apagado,
  sin descargar o sin el idioma—, la hoja de Pro de siempre. Pro no cambia.
- **Señal del gate**: `siriEntryRoute` (`route=… model=…`) en cada invocación y `siriOnDeviceParse` (desenlace y
  milisegundos) en cada lectura en el teléfono, sin datos personales.
- **Tests**: `SiriEntryRouteTests` (matriz Pro sí/no × los seis estados del modelo, interruptor, traducción de
  `FoundationModels`, cableado), dos casos en `MetricsServiceTests`, y `SiriOnDeviceEntryUITests` (3 casos con App
  Intents Testing). Mutante: con el interruptor apagado, el caso del borrador cae.
- **Encontrado por el camino**: bajo `-uitest`, la caché que lee el intent (cuentas, subcategorías) no se escribía tras
  sembrar, y el intent salía sin encolar con «no hay cuentas» (verde a solas, rojo detrás de otro caso). Se reescribe en
  el `defer` de `applyUITestSeed`, junto a la foto de Siri que ya se reescribía ahí. Solo DEBUG/UITest.
- **Pendiente de Jürgen**: el guion de iPhone del ticket (`tickets/qa/siri-free-users-on-device-model-awaits-decision.md`),
  que mide calidad y tiempo frente al servidor en ES y EN.
