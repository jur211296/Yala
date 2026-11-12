# Partir la IA de Yala según modo nube o privado

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Contexto
Jürgen aprobó el 16-oct (22:38) la cola de cards de 2.2. La tarjeta multidivisa ya quedó completa (PR #547 a #550). Esta es la siguiente: partir el uso de IA según el modo de datos. Jürgen la marcó como ventaja diferencial (3-oct): en modo nube Yala IA puede explorar mucho más los datos del usuario, ampliar búsquedas y dar más detalle; en modo privado se mantiene el límite actual. No se cambia de modelo ni de proveedor: eso lo decide Jürgen.
- Card: `tablero-partir-la-ia-segun-modo-nube-o-privado-0y9k` (ya está en in progress). Al cerrar: a done si todo quedó hecho, o a in qa asignada a `jurgen` con el guion de iPhone en la nota si hay algo que probar. Cada decisión que quede para Jürgen va en su propia card asignada a `jurgen` en «espera decisión», con opciones A/B/C y tu recomendación.
- Punto de partida obligatorio: `docs/ai-usage-review-2026-10.md`, sección 6 («Insumo para Partir la IA…») y los tickets que cita (`ai-model-choice-lives-in-the-app-binary`, `gateway-does-not-record-ai-token-usage`, `chat-sends-every-past-turn-to-the-model`, cuotas en `policy.ts` del gateway). Mira también `docs/ux/mapa-de-flujos-2.2.md` (lotes que nombran esta card) y `docs/flows/modo-nube/`. Comprueba en el código de hoy qué tickets de esos ya están hechos.
- Hoy el modo no cambia nada de la IA: en privado el chat manda igual el contexto financiero completo al servicio de IA a través del gateway. El chat es «todo en el prompt», con topes fijos.

## Qué se pide
1. Un documento de diseño corto (`docs/ai-cloud-vs-private-2026-10.md`) en lenguaje de usuario: qué hace Yala IA hoy en cada modo, qué cambia en cada uno, coste por pregunta estimado y el riesgo de privacidad. Con opciones A/B/C y una recomendación para: (a) cómo explora más en nube (por ejemplo, que el modelo pida datos con herramientas desde el gateway contra las tablas del usuario, en lugar de un resumen recortado), (b) qué se manda en privado y cómo se le cuenta al usuario, (c) cuotas por modo.
2. Implementar la opción recomendada que sea reversible, **detrás de un flag apagado por defecto** (en la app y en el gateway), con tests: el modo privado queda exactamente como hoy; el modo nube con el flag encendido usa el camino ampliado. Medición de tokens si hace falta para poder decidir.
3. Si hay texto o pantalla nueva para el usuario (por ejemplo, cómo se explica la IA en modo privado), déjalo como propuesta con capturas o maqueta y decisión pendiente en su card; no lo publiques como definitivo. Cualquier texto nuevo va en los 16 idiomas y sin nombrar a «OpenAI» (se dice «un servicio de IA», con enlace a la política).

## Qué NO hay que tocar
- Ni modelo ni proveedor de IA. Ni encender el flag en ningún entorno real.
- Nada de despliegues a producción (ni Worker/gateway de producción, ni Supabase de producción, ni CloudKit Production, ni publicar el conector MCP). Si hace falta esquema o despliegue, déjalo listo, crea su card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- Grupos como contenedor aparte en Yala IA tiene su propia card más adelante en la cola: no la hagas aquí, solo no la cierres de camino.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, ni `Yala--qa-guiado-2-1-tf17`.

## AUTONOMÍA (fin de semana)
Jürgen no está en el escritorio. Si sale una duda reversible, elige la opción recomendada, impleméntala detrás del flag y anótala en la card y en el PR («Decidido por la sesión: …, porque…»). Lo que cambia coste por pregunta, privacidad de cara al usuario, modelo o proveedor queda como decisión de Jürgen en su card, sin parar la sesión.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- Todo ticket nuevo lleva su card.
- Prueba según /barrido-qa lo que aplique: tests del armado de contexto por modo (privado idéntico a hoy), del camino ampliado con el flag, del gateway (`policy.ts`, herramientas si las hay), los goldens del gateway y del conector si los tocas, y `/l10n-check` si hay texto nuevo.
- Si hay cambio visible, capturas de antes y después en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, y con sus rutas en el resumen de cierre. Si no hay cambio visible, no hay capturas.
- Cierra con /cerrar-total.

## Cómo se sabe que está bien
El documento de diseño en el repo con opciones y recomendación, el camino recomendado implementado detrás del flag apagado con tests en verde (`/gate`, `YalaTests` y los del gateway), el modo privado sin cambios, las decisiones de Jürgen en sus cards en «espera decisión», y el PR contra 2.2 explicando en lenguaje de usuario qué cambiará cuando se encienda.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, fin de semana): las recomendaciones se dan por buenas y se discuten en el PR. Lo que
> cambia coste por pregunta o privacidad de cara al usuario queda además en su card para Jürgen.

Hechos medidos antes de decidir (árbol `origin/2.2`, 2026-10-18):
- La elección de modelo ya vive en el gateway (`ai-model-choice-lives-in-the-app-binary` en `done/`): `chat.answer` va
  con `gpt-6-luna`, sin razonamiento y con tope de 512 tokens de salida. El gateway ya registra tokens por petición en
  `wrangler tail` (`ai_route`), pero no los guarda (`gateway-does-not-record-ai-token-usage` sigue en backlog).
- `chat-sends-every-past-turn-to-the-model` sigue abierto (backlog).
- El conector MCP (`mcp/`) ya tiene seis lecturas de solo lectura sobre las tablas del usuario en Supabase, con
  paridad medida contra la app (`mcp/test/golden/app-parity.json`). Su código de cálculo no tiene dependencias.
- El consentimiento del chat de hoy promete «un resumen de tus últimos 13 meses: saldos y nombres de tus cuentas,
  totales por categoría, comercios frecuentes, presupuestos y pagos recurrentes». En privado y en nube.

**D1 · Cómo explora más Yala IA en modo nube** → A: el modelo pide datos con herramientas desde el gateway contra las
tablas del usuario, y recibe además el mismo resumen de hoy.
Por qué: es lo único que quita los topes (cualquier periodo, cualquier comercio, búsqueda por nota) y solo cuesta de
más cuando la pregunta lo necesita. Alternativas descartadas: B herramientas ejecutadas en el iPhone (sirve en los dos
modos y deja el diseño en el binario); C un resumen fijo más grande (paga tokens en cada pregunta y sigue con topes).

**D2 · Herramientas: reusar las del conector MCP** → se separa su núcleo (`mcp/src/toolCore.ts`, sin `zod`) y el
gateway lo importa por ruta relativa. Por qué: un solo cálculo de las finanzas en TypeScript, con su paridad contra la
app ya medida; copiarlo divergiría. Alternativa descartada: copiar el código al gateway.

**D3 · Qué se manda en modo privado** → exactamente lo de hoy. Cómo se le cuenta al usuario es decisión de Jürgen
(card), con propuesta de texto en 16 idiomas en el documento. Alternativas: B mandar menos (solo agregados), C modelo
en el iPhone (no cabe el contexto).

**D4 · Cuotas por modo** → implementado: la misma cuota `chat` (75/día Pro), una pregunta = un uso aunque haga varias
llamadas, con topes por pregunta (3 rondas, 4 herramientas, 16 000 caracteres por resultado). Cambiar la cuota es decisión de
Jürgen (card), porque cambia el coste por usuario.

**D5 · El consentimiento de hoy no cubre el camino ampliado** (movimientos con su nota, más de 13 meses) → no se toca
ningún texto; el flag no se puede encender sin que Jürgen decida el texto nuevo. Card propia.

**D6 · El flag** → uno solo, `AI_CLOUD_EXPLORE_ROLLOUT_PERCENT` en el gateway (ausente = 0, también en staging),
servido en `/config` como `aiCloudExploreRolloutPercent`. La app lo lee con su cohorte y falla cerrado en TODOS los
builds (no hereda el «ausente = encendido» de DEV). Con el gateway apagado, una petición `chat.explore` se contesta
como `chat.answer`, sin herramientas: nunca un error para el usuario.

**D7 · Identidad para leer** → la app manda el JWT de Supabase en `X-Yala-User-Token`; el gateway lo verifica (JWKS) y
lee con él, solo `GET` a tablas por la lista cerrada del conector. Nunca `service_role`. Sin token, la app usa el
camino de hoy.

**D8 · Zona horaria** → la app la manda en `X-Yala-Time-Zone`; el modelo no puede elegirla.

**D9 · Tiempo** → el camino ampliado espera hasta 30 s en la app (hoy 20 s); el gateway deja de pedir herramientas a
los 12 s (consultas de una ronda en paralelo, 6 s como mucho cada una) y contesta con lo que tenga. Reversible.

**D10 · Medición** → cada pregunta del camino ampliado deja en `ai_route` rondas, herramientas usadas, bytes devueltos
y tokens sumados. El coste se estima con los precios del banco y con el tamaño medido de las respuestas de las
herramientas sobre los datos de prueba. Sin llamadas de pago ni despliegues en esta sesión.

**D11 · Grupos** → ninguna herramienta de grupos (tiene su card más adelante).

**D12 · Pantallas** → ningún cambio visible: con el flag encendido el chat se ve igual. Sin capturas.
