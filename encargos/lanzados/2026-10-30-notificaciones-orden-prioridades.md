---
esfuerzo: high
---
# Notificaciones y avisos in-app: que salgan uno tras otro con una regla de prioridad, sin solaparse ni duplicarse

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `notificaciones-orden-prioridades` · Sesión cola **S27f** · al cerrar → **S27g**.
Card: `tablero ver tablero-notificaciones-y-avisos-in-app-que-salte-usxd`.

## Contexto
Pedido de Jürgen (2026-10-29 05:36 Lima): que las notificaciones salten como se espera, una tras otra, con prioridades. Relacionado (no absorber): card 2.3 «Con Ajustes abierto, un aviso importante (cambio de Apple ID, vaciado remoto) puede perderse…».

## Qué se pide
1. Inventario de todas las notificaciones locales, push y avisos/pop-ups/hojas in-app (Bandeja, paywall, novedades, Apple ID, presupuestos, pagos planificados, Grupos…): quién las dispara y cuándo.
2. Definir tú la regla de prioridad (opción conservadora: la que cambia menos el comportamiento actual; documenta alternativas en el ticket, sin esperar a Jürgen) (qué gana, qué espera, qué se descarta por duplicada) y escribirla en un ticket/doc del repo.
3. Aplicarla: un solo punto que encola los avisos in-app, sin dos hojas a la vez ni duplicados; dedupe de notificaciones locales.
4. Tests de la cola (unit + XCUITest donde se pueda). La apertura desde notificación tocada es de S27g: deja anotado lo que encuentres para ella.
5. Un PR a 2.2 en auto-merge. Card a in progress al empezar; al cerrar, done o in qa.

## Reglas de Mini
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; no toques las de un worktree vivo. Haz un solo fetch y rebase sobre `origin/2.2` antes de abrir el PR, con el simulador apagado; no esperes el CI de otro PR.

## Qué NO tocar (común)
- marketing/ y Web/ (Lola). No lanzar otras sesiones Yala. No rediseñar notificaciones (eso es la card 2.4 «Rediseñar las notificaciones desde cero»).

## Cómo se sabe que está bien
Inventario y regla escritos; dos avisos simultáneos salen en orden de prioridad, nunca juntos ni dos veces; tests verdes.

## Noche autónoma (Jürgen 2026-10-29 22:18 Lima: «que la noche fluya sin pedirme inputs»)
- Se lanza con `--permission-mode bypassPermissions`. No uses AskUserQuestion ni esperes respuesta de Jürgen: es de noche (21:00–6:00).
- Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en el ticket/card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card separada con `cierra-sola` asignada a jurgen explicando la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

/cerrar-total

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, noche): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Hace falta un «punto único que encola» nuevo?** → No. Ya existe: `RouterEntryGate.submit` → `AppRouter` (cola por prioridad y llegada, dedup por `id`, matriz de readiness). Se completa lo que le falta en vez de montar otro.
Por qué: la opción conservadora es la que menos cambia; un segundo coordinador competiría con el primero. Alternativa descartada: una cola nueva de avisos encima del router.

**D2 · Regla de prioridad entre consumidores** → Entre los avisos del shell de una misma ventana (`.contentView` y `.mainTab`) sale primero el que va delante en la cola. Una hoja de MainTab cede ante lo de `.contentView` que vaya delante; un aviso diferible de `.contentView` cede ante una hoja de MainTab que vaya delante. Críticos y respuestas a un toque no ceden nunca. Solo se cede si el otro consumidor está listo en esa ventana.
Por qué: hoy cada consumidor drena lo suyo y gana el que mira antes (Novedades `.low` podía salir antes que «Tu prueba terminó» `.high`). Alternativas descartadas (documentadas en el ticket): cola global estricta que incluya el Panel (las entradas que pidió la persona esperarían detrás de avisos) y un solo consumidor para todo (rehacer los anchors).

**D3 · Aviso de la Bandeja duplicado** → El `id` de `.showInboxAlert` pasa a ser fijo: el aviso nuevo sustituye al que esperaba, con las cifras de ahora.
Por qué: el productor recalcula sobre borradores aún no quemados, así que el segundo aviso contiene al primero; con `id` por cifras salían los dos seguidos. El test `inboxAlert_dedupesBySignature` fijaba el bug como contrato y se reescribe.

**D4 · Notificaciones locales** → Solo se corrige el duplicado que el inventario mida; no se rediseñan (card 2.4).
Por qué: alcance del encargo.

**D5 · Apertura desde notificación tocada** → No se toca; lo encontrado va anotado para S27g en el ticket.
