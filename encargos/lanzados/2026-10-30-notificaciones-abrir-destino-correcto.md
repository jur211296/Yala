---
esfuerzo: high
---
# Tocar una notificación abre exactamente su destino (arreglar Bandeja + pop-up «tienes gastos en bandeja» duplicados)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Si S27f aún no está mergeada, no la esperes: lee su regla de prioridad del PR de S27f (`gh pr diff`) y anota en el PR que depende de él. Slug: `notificaciones-abrir-destino-correcto` · Sesión cola **S27g** · al cerrar → **S28**.
Card: `tablero ver tablero-tocar-una-notificacion-abre-su-destino-e-0443`.

## Contexto
Pedido de Jürgen (2026-10-29 05:36 Lima). Bug reportado: al tocar una notificación automática, la app abre la Bandeja directo y después aparece el pop-up «tienes gastos en bandeja» (orden/duplicación incorrecta). Usa la regla de prioridad que dejó S27f.

## Qué se pide
1. Mapa de cada tipo de notificación → destino y estado esperado.
2. Reproducir y arreglar el caso Bandeja + pop-up: si la notificación ya te lleva a la Bandeja, el aviso no debe salir después.
3. Cubrir cada tipo con app cerrada (arranque en frío), en segundo plano y abierta; XCUITest donde se pueda, el resto en tabla de device-QA para Jürgen.
4. Un PR a 2.2 en auto-merge. Card a in progress al empezar; al cerrar, in qa (device-QA en iPhone) o done.

## Reglas de Mini
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; no toques las de un worktree vivo. Haz un solo fetch y rebase sobre `origin/2.2` antes de abrir el PR, con el simulador apagado; no esperes el CI de otro PR.

## Qué NO tocar (común)
- marketing/ y Web/ (Lola). No lanzar otras sesiones Yala. No rediseñar notificaciones (eso es la card 2.4 «Rediseñar las notificaciones desde cero»).

## Cómo se sabe que está bien
Cada tipo abre su destino en los tres estados de app; el pop-up ya no sale tras abrir la Bandeja desde la notificación; tests verdes.

## Noche autónoma (Jürgen 2026-10-29 22:18 Lima: «que la noche fluya sin pedirme inputs»)
- Se lanza con `--permission-mode bypassPermissions`. No uses AskUserQuestion ni esperes respuesta de Jürgen: es de noche (21:00–6:00).
- Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en el ticket/card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card separada con `cierra-sola` asignada a jurgen explicando la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

/cerrar-total

## Paso 0 — decisiones (autónomo, de noche; auto-contestadas por la opción conservadora)

- **D1 · Qué es la «notificación automática».** La de la automatización de Apple Pay (y la de Siri en lenguaje
  natural): las dos llevan `deepLink: "inbox"`, y al volver a la app el mismo `.active` convierte lo encolado en
  borradores y pide `.showInboxAlert`. Es la única familia de notificaciones que abre la Bandeja.
- **D2 · Dónde se corta el aviso.** En la cola, no en la vista: (a) un `.showInboxAlert` que llega con
  `.navigate(.inbox)` o `.presentInboxSheet` ya en cola se descarta al entrar (hoy solo se tira el que llegó antes);
  (b) al aparecer la hoja de la Bandeja —por notificación, por el botón del Panel o por el aviso— se retira de la cola
  cualquier `.showInboxAlert` que esperase. Con eso cubre los cuatro órdenes posibles. Descartado: un flag de «la
  Bandeja se está abriendo» en `SceneNavigation` (si UIKit no llega a presentar, el flag se queda y apaga el aviso toda
  la sesión).
- **D3 · Lo visto en la Bandeja se da por avisado.** Al aparecer la Bandeja se queman las firmas pendientes del aviso
  (`commitPendingInboxAlertSignatures`), y un chequeo que corre con la Bandeja ya abierta las quema sin pedir aviso.
  Sin esto, el aviso tirado volvía a salir al siguiente primer plano con los mismos borradores (el residual que
  documentaba `commitPendingInboxAlertSignatures`). Reversible: solo cambia cuándo se marca «ya avisado».
- **D4 · Sin rediseño.** Solo el destino y el orden; textos y tipos de notificación no se tocan (card 2.4).
- **D5 · S27f (#696) en cola de auto-merge, sin mergear al empezar.** Se trabaja sobre `origin/2.2`; su regla de
  prioridad no cambia nada de esto (el aviso de la Bandeja sigue siendo `contentView · high`). Si al rebasar sigue
  abierta, el PR lo dice.
- **D6 · Cobertura de los tres estados.** XCUITest con el toque fingido por `routeTap` (el camino real del toque) en
  frío, en primer plano y tras volver de segundo plano donde el simulador lo permita; lo que necesite el banner real de
  iOS va a la tabla de device-QA del ticket.
