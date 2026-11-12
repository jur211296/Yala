# Integrar Yala con el nuevo Siri con IA de iOS 27, junto con las frases de Siri en portugués

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Contexto
Jürgen aprobó el 16-oct (22:38) la cola de cards de 2.2. Ya quedaron hechas la tarjeta multidivisa (PR #547 a #550) y partir la IA según modo nube o privado (PR #551). Esta es la siguiente: el foco de 2.2 incluye Siri con IA (pedido de Jürgen del 12-oct). Va agrupada con dos cards pequeñas de Siri, porque tocan el mismo código y se avanza más rápido juntas.
- Cards de esta sesión (todas asignadas a frank, cierre autónomo):
  1. `tablero-integrar-yala-con-el-nuevo-siri-con-ia-d-egjm` · Integrar Yala con el nuevo Siri con IA de iOS 27 (high).
  2. `tablero-las-frases-de-siri-que-la-app-ensena-en-eol6` · Las frases de Siri que la app enseña en portugués no activan Siri. Ticket `tickets/backlog/siri-phrases-shown-in-portuguese-do-not-trigger-siri.md`: `AppShortcutsProvider` solo tiene frases en español e inglés.
  3. `tablero-con-el-iphone-en-espanol-los-errores-de-ymwo` · Con el iPhone en español, los errores de «Anotar con Siri» se oyen en inglés (ticket `siri-shortcut-error-replies-speak-english-on-a-spanish-iphone`).
  Ponlas en in progress al empezar. Al cerrar, cada una a done si quedó hecha, o a in qa asignada a `jurgen` con el guion de iPhone en la nota (Siri real casi siempre necesita un iPhone: dilo en el guion, paso a paso y corto).
- Relacionadas que esperan decisión de Jürgen y **no se deciden aquí**: L15-4 «Siri y Atajos enseña frases pero no deja hacer nada» (`…-zsx1`), L15-5 «En 10 de los 16 idiomas, ninguna frase de Siri funciona» (`…-wewa`), L15-6 «Sin Pro, Siri dice Activa Yala Pro» (`…-2yze`), L15-7 «Un dictado de Siri no avisa dentro de la app» (`…-vhat`). Léelas con `tablero ver` para no contradecirlas. Si tu trabajo cambia lo que se puede decidir en alguna (por ejemplo, el portugués queda resuelto y solo faltan otros idiomas), actualiza su nota en una línea; no cambies su columna.
- Puntos de partida: `docs/entry-points.md`, `docs/ux/mapa-de-flujos-2.2.md` (lote 15), `docs/ai-usage-review-2026-10.md` (lo que diga de Siri) y el código de App Intents y App Shortcuts de hoy. Lee la documentación oficial de Apple de iOS 27 sobre Siri con IA y App Intents (dominios / esquemas de intents, entidades, consultas, acciones en pantalla, lo que aplique) antes de diseñar: la fuente es Apple, no la memoria.

## Qué se pide
1. Un documento corto `docs/siri-ios-27-2026-10.md` en lenguaje de usuario: qué puede hacer hoy un usuario de Yala con Siri, qué abre iOS 27 con Siri con IA, y qué propones integrar en 2.2, con opciones A/B/C, recomendación, coste de mantenimiento y riesgo de privacidad (qué datos ve Siri o el sistema). Cuida que funcione igual en modo nube y en modo privado, y en solo gastos.
2. Implementar la opción recomendada que sea reversible y no necesite decisión de producto: las App Intents, entidades y consultas que Siri con IA necesita para entender y usar Yala (por ejemplo, anotar un gasto, consultar cuánto gasté, abrir una cuenta), con tests. Si una parte cambia lo que el usuario ve o paga (Pro), déjala como propuesta en su card a `jurgen` en «espera decisión».
3. Frases de Siri en portugués: localizar las frases del `AppShortcutsProvider` a pt (y pt-BR si aplica) y comprobar que la app enseña frases que existen. No amplíes a los otros idiomas de L15-5 sin decisión; anótalo.
4. Los errores de «Anotar con Siri» se oyen en el idioma del iPhone, no en inglés.
5. Cualquier texto nuevo va en los 16 idiomas (`/l10n-check`) y sin nombrar a «OpenAI» (se dice «un servicio de IA», con enlace a la política).

## Qué NO hay que tocar
- Ni modelo ni proveedor de IA. Nada de despliegues a producción (gateway, Supabase, CloudKit Production, conector MCP). Si hace falta esquema o despliegue, déjalo listo, crea su card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- Nada del iPhone Duo ni del runtime iOS 27.1 (no se descarga hasta 2.2 Duo).
- Las decisiones L15-4 a L15-7: no las implementes.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, ni `Yala--qa-guiado-2-1-tf17`.

## AUTONOMÍA
Jürgen no está en el escritorio. Si sale una duda reversible, elige la opción recomendada, impleméntala y anótala en la card y en el PR («Decidido por la sesión: …, porque…»). Lo que cambia lo que se cobra (Pro), la privacidad de cara al usuario, el modelo o el proveedor queda como decisión de Jürgen en su card, sin parar la sesión.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- Todo ticket nuevo lleva su card.
- Prueba según /barrido-qa lo que aplique: tests de las App Intents y entidades, de las frases por idioma, del idioma de los errores, `/gate` y `/l10n-check`.
- Si hay cambio visible (por ejemplo, la pantalla «Siri y Atajos» o lo que Siri muestra), capturas de antes y después en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, con sus rutas en el resumen de cierre. Si no hay cambio visible, no hay capturas.
- Cierra con /cerrar-total.

## Cómo se sabe que está bien
El documento en el repo con opciones y recomendación, la integración recomendada implementada con tests en verde (`/gate`, `YalaTests`), las frases en portugués y los errores en el idioma del iPhone arreglados, las decisiones de Jürgen en sus cards en «espera decisión», guion corto de iPhone en las cards que lo necesiten, y el PR contra 2.2 explicando en lenguaje de usuario qué podrá hacer el usuario con Siri.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** SDK de iOS 27.1 (Xcode 27.1) y documentación de Apple de WWDC26: Siri con IA
usa App Intents; lo que entra en la «caja de herramientas» de Apple Intelligence son las intents y entidades que
adoptan un **esquema** (`@AppIntent(schema:)`). Los dominios son audio, calendario, cámara, reloj, correo, mapas,
mensajes, notas, teléfono, fotos, recordatorios y «sistema y búsqueda en la app» (`.system.open`, `.system.searchInApp`,
solo iOS 27). **No hay dominio de finanzas.** Lo demás (App Shortcuts con frases, Spotlight, acciones en pantalla)
sigue funcionando como antes.

**D1 · ¿Subir el suelo a iOS 27?** → No. Lo de iOS 27 va con `@available(iOS 27, *)`.
Por qué: lo único exclusivo de 27 que usamos es `.system.open`. Alternativa descartada: subir el suelo (deja fuera a iOS 26 por una sola acción).

**D2 · ¿Qué opción se implementa?** → B: consultas sin abrir la app (cuánto gasté, cuánto tengo) + la entidad
«cuenta» con búsqueda por nombre + «abrir una cuenta» con el esquema `.system.open` en iOS 27. Indexar en Spotlight,
anotar la pantalla y buscar dentro de la app (opción C) quedan como propuesta en la card de Jürgen.
Por qué: B es reversible y no saca datos nuevos del teléfono; C mete importes y nombres en el índice del sistema, y eso es privacidad de cara al usuario. Alternativa descartada: A (solo arreglar frases), porque el encargo pide integrar.

**D3 · ¿De dónde leen las consultas?** → De una foto propia en el App Group (`siri_finance_snapshot`), escrita en el
mismo `WidgetDataCache.updateCache` y borrada en el mismo `clearCache`. Sin SwiftData en el intent.
Por qué: un segundo `ModelContainer` en el intent ya vació la UI una vez (`siri-intent-dual-container`); y una clave aparte no puede romper el decode de los widgets. Alternativa descartada: añadir campos al snapshot de widgets (DTO duplicado en dos targets; un error apaga todos los widgets).

**D4 · ¿Consultas gratis o Pro?** → Gratis, como los widgets que ya enseñan esos mismos números. Queda como pregunta en la card de Jürgen.
Por qué: no cambia nada de lo que hoy se cobra y se revierte en una línea. Alternativa descartada: Pro (es una decisión de precio que no me toca).

**D5 · ¿Se responde con el iPhone bloqueado?** → No: `authenticationPolicy = .requiresAuthentication` en las consultas.
Por qué: Siri diría saldos en voz alta a quien tenga el teléfono en la mano. Es el lado conservador y reversible.

**D6 · ¿Qué pasa en solo gastos, solo grupos o sin datos?** → Solo gastos: «cuánto tengo» responde con lo gastado este
mes (lo mismo que enseña el Panel en ese modo). Solo grupos: dice que en este iPhone Yala solo tiene grupos. Sin foto:
pide abrir Yala una vez. Foto de otro período (mes cambiado sin abrir la app): no inventa, pide abrir Yala.
Modo nube y privado: igual en los dos, la foto sale del store local que existe en ambos.

**D7 · Errores de «Anotar con Siri» en inglés** → Todas las respuestas y la pregunta se resuelven en la app
(`String(localized:)`), el camino que ya se oye en español. Red: un scan que prohíbe la clave literal en `dialog:` y en `requestValue`.
Por qué: el éxito ya sale en español por ese camino (medido en el ticket); la causa del lado del sistema no está aislada. Los títulos de parámetros en la ficha de Atajos se miden en el simulador y, si siguen en inglés, quedan como residual con ticket.

**D8 · Frases en portugués** → `AppShortcuts.xcstrings` con pt, pt-BR y pt-PT, más es y en en identidad (las frases
de hoy, sin cambiar). Los otros 7 idiomas no se tocan (L15-5). Test: cada frase que enseña la pantalla en pt existe.
Por qué: es como Apple localiza las frases; la identidad en es/en evita que crear el catálogo cambie su comportamiento.

**D9 · ¿Se toca la pantalla «Siri y Atajos»?** → No. Es L15-4, pendiente de Jürgen. Las consultas nuevas tienen sus frases de Siri, pero la pantalla no las enseña hasta que decida.
