---
esfuerzo: high
---
# Widget y app usan la misma divisa por defecto, Exportar con «Ocultar» vacía lo marcado y animaciones caso por caso

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Slug: `divisa-widget-exportar-animaciones` · Sesión cola **S27p** · al cerrar → **S28**.
Cards (+ `tablero-banco-de-versiones-el-mutante-fijo-3-fal-8pyt`, tarea 5b): `tablero-sin-divisa-principal-guardada-el-widget-2jj6`, `tablero-exportar-en-ocultar-con-lo-marcado-por-d-k4iz`, `tablero-animar-caso-por-caso-las-animaciones-pre-8atf` (léelas con `tablero ver <id>`).

## Contexto
Decisiones de Jürgen del 2026-10-30 06:39 Lima:
1. **Divisa por defecto (2jj6, prioridad alta).** Sin `defaultCurrencyCode` guardado, la app cae a PEN, `CurrencyDefaults` a la región y `WidgetDataCache` a USD (y reconvierte todo el histórico). Ventana: entre «Empezar de cero» y el onboarding. Ticket: `tickets/backlog/widget-cache-falls-back-to-usd-while-the-app-falls-back-to-pen.md`. Relacionado: la card 2h3c («Si falta la divisa preferida, cada parte de la app supone una distinta»), donde Jürgen ya eligió el 2026-10-08 la opción A: si falta la divisa preferida, usar la de la región del dispositivo. Aplica ese criterio.
2. **Exportar en «Ocultar» (k4iz, prioridad alta), opción A.** El asistente de Exportar arranca con todo marcado; en «Ocultar» lo marcado se oculta y sale «Ninguno con estos filtros» sin tocar nada. Decisión: al pasar a «Ocultar», vaciar lo marcado. Ticket: `tickets/backlog/export-hide-mode-with-the-defaults-exports-nothing.md`.
3. **Animaciones (8atf, prioridad media), opción B de la card 1yhi.** `ContentView` apaga la animación dentro de las pestañas (`.transaction { $0.animation = nil }`) desde el 15-ene-2026, contra un parpadeo al cerrar hojas y en la pestaña temporal de Buscar. Unos 45 `withAnimation` no animan. Decisión: **no quitar el apagado global**; animar caso por caso con animación implícita `.animation(_:value:)` solo donde valga la pena (banners que se cierran, avisos, «Más opciones» de formularios, flujo de caja…). Patrón: PR #656 (chips de Estadísticas).

## Qué se pide
1. Cards a in progress al empezar (`tablero mover <id> --a "in progress" --agente frank`).
2. **Divisa:** que los tres lectores (app, `CurrencyDefaults`, `WidgetDataCache`) caigan al mismo valor cuando falta la divisa guardada, con un solo punto de verdad. Test de paridad que falle hoy y pase después.
3. **Exportar:** al pasar a «Ocultar» se vacía lo marcado; elegir «Ocultar» sin tocar nada exporta todo y lo que marques después es lo que se quita. Test (unitario del view model o UI test).
4. **Animaciones:** recorre los `withAnimation` que hoy no animan, elige los que valen la pena y anímalos caso por caso sin tocar el apagado global. Lista en el PR cuáles animaste y cuáles dejaste y por qué. Test donde sea posible (al menos que el apagado global sigue presente) y captura o vídeo de antes y después en `capturas/`. Comprueba que no vuelve el parpadeo al cerrar hojas ni en la pestaña temporal de Buscar.
5. **Tarea extra, solo docs:** #691 ya resolvió dos tickets. Muévelos de `tickets/backlog/` a `tickets/done/` y actualiza `docs/TICKETS.md`:
   - «La subcategoría de transferencias no se reconoce en japonés, neerlandés, polaco, chino y portugués» (`transfer-subcategory-unrecognized-in-five-languages.md`)
   - «Si el import falla al final, lo insertado se queda sin deshacer» (`import-failure-leaves-unsaved-inserts-in-the-main-context.md`)
   Verifica en el código de origin/2.2 que de verdad están resueltos antes de moverlos; si alguno no lo está, déjalo en backlog y dilo en el PR.
5b. **Tarea extra pequeña (card `tablero-banco-de-versiones-el-mutante-fijo-3-fal-8pyt`):** `qa/scripts/versiones-embebidas-test.sh` muta `CURRENT_PROJECT_VERSION` a un valor fijo `3`; si el proyecto ya está en 3, el caso «configuraciones distintas» deja de fallar y coverage-index sale rojo (atascó el #665, ya cerrado). Que el mutante use el valor actual + 1 (o + 100) en vez de 3. Test: el banco tiene que pasar con el proyecto en build 3 y en el build actual (simúlalo en el test o en una copia temporal). Card a done al cerrar.
6. Un solo PR a `2.2` con todo. Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR. Activa auto-merge.
7. Al cerrar: 2jj6, k4iz y 8atf a done (o in qa si algo pide mirarlo en el iPhone, con guion corto).

## Reglas de Mini
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim. Un solo simulador. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; no toques las de un worktree vivo. Al cerrar, apaga y borra los datos del sim que usaste.

## Qué NO tocar
- marketing/ y Web/ (Lola). No lanzar otras sesiones Yala. No quitar el apagado global de `ContentView`. No tocar ramas ni PR de otras sesiones. No empujar a `2.2` directo.

## Cómo se sabe que está bien
Tests nuevos en verde en local y en el CI del PR; widget y app muestran la misma divisa sin divisa guardada; Exportar en «Ocultar» sin tocar nada exporta todo; las animaciones elegidas animan y no vuelve el parpadeo; los dos tickets en `tickets/done/` con `docs/TICKETS.md` al día; PR único a 2.2 con auto-merge.

## Noche autónoma (Jürgen 2026-10-29 22:18 Lima: «que la noche fluya sin pedirme inputs»)
- Se lanza con `--permission-mode bypassPermissions`. No uses AskUserQuestion ni esperes respuesta de Jürgen.
- Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card separada con `cierra-sola` asignada a jurgen explicando la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

/cerrar-total

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿A qué valor caen los lectores sin divisa guardada?** → La de la región del dispositivo, decidida en un solo sitio (`CurrencyDefaults.preferred(storedRaw:regionCode:)`).
Por qué: es el criterio que Jürgen eligió el 2026-10-08 (card 2h3c, opción A) y el que el encargo manda aplicar. Alternativa descartada: soles para todos (contradice esa decisión).

**D2 · ¿Solo los tres lectores del ticket o todos los que leen la key con su propio `??`?** → Todos: app, `CurrencyDefaults`, `WidgetDataCache` y también `ExchangeRateService` (caía a PEN).
Por qué: «buscar todas las instancias del patrón»; dejar uno fuera mantiene la divergencia. Un source-scan impide que vuelva. Alternativa descartada: solo los tres (quedaría un cuarto default).

**D3 · ¿`AppPreferences` vuelve al default cuando la key desaparece con la app abierta?** → Sí, solo esta key (el resto sigue releyéndose por presencia). Sin escribir nada (`isLoadingFromDefaults`).
Por qué: «Empezar de cero» borra la key en caliente; sin esto la app seguiría en la divisa anterior y los widgets en la región. Alternativa descartada: dejarlo por presencia (la paridad solo valdría en un arranque nuevo).

**D4 · Fuera de alcance: el `?? "USD"` de `YalaWidgets/WidgetDataService.preferredCurrencyCode`** (solo cuando no hay snapshot) y la quinta dimensión del ticket 2h3c (`.standard` frente a `SessionDefaults`). Se anotan en el PR.

**D5 · Exportar: ¿qué pasa al volver de «Ocultar» a «Mostrar solo»?** → Se vuelve a marcar todo, como al abrir.
Por qué: simétrico con la opción A; «Mostrar solo» sin nada marcado no deja exportar (el botón exige cuentas). Alternativa descartada: conservar lo marcado en «Ocultar» (invertiría su significado en silencio).

**D6 · Exportar en «Ocultar» con nada marcado.** → Se permite exportar (antes el botón exigía al menos una cuenta marcada), las monedas ofrecidas son las de lo que queda a la vista, los estados dicen «Ninguna seleccionada», marcar cuentas no marca sus monedas y la hoja de categorías no se autollena. «Ocultar» con TODAS las etiquetas o necesidades marcadas oculta lo que las tiene (antes «todas» se colapsaba a «sin filtro»).
Por qué: son consecuencias directas de vaciar lo marcado; sin ellas el modo sale roto de otra forma (54 chips de moneda, botón apagado, «Todas» cuando no hay nada). Alternativa descartada: solo vaciar (dejaría la pantalla incoherente).

**D7 · Animaciones: ¿cuáles?** → Las que cambian algo visible dentro de una pestaña y hoy saltan: cierre de banners y avisos (Panel, Grupos, detalle de grupo, guías contextuales, tarjeta de avisos de grupo), «Más opciones» de formularios y el flujo de caja. Se mide en vídeo qué hojas heredan el apagado antes de tocarlas. Se dejan: pantallas de éxito, Welcome/onboarding y otras fuera del `TabView` (ya animan), scrolls programáticos y animaciones `repeatForever`.
Por qué: decisión 1yhi opción B; animar solo donde aporta. Alternativa descartada: quitar el apagado global (prohibido por el encargo).

**D8 · 5b, banco de versiones:** el mutante usa el build actual + 100 en vez de un `3` fijo.
Por qué: nunca coincide con el real, sea cual sea. Alternativa descartada: +1 (coincide con el siguiente bump si alguien lo prepara en paralelo).
