# En la nube, con solo cambios de grupos y sesión caducada, el aviso de cerrar sesión nombra dónde volver a entrar y esa puerta existe

## Contexto
Acaba de mergear a 2.1 el PR #252 (`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`): el paso 1 del cierre en la nube con cambios personales ya no dice «revisa tu conexión»; nombra el motivo real (retry later / sesión caducada). Residual low personal: el aviso de sesión caducada aún no dice dónde entrar. Este ticket es el hermano de grupos (medium, Cola A real-risk): con cuenta en la nube, sesión caducada y gastos de grupo sin subir, «Vuelve a iniciar sesión» no dice dónde, y a veces no hay ninguna puerta.

Ticket: `tickets/backlog/cloud-session-expiry-with-only-group-changes-has-no-sign-in-door.md`. Léelo entero. Base: rama `2.1` al día (el lanzamiento ya parte de origin).

Cola A autónoma sigue armada. Device-QA en paralelo no frena este encargo.

## Que se pide
1. Reproduce el tráfico de decisión del ticket: con sesión caducada y solo cambios de grupos pendientes, el cierre enseña `groups.errors.sessionExpired` (o el copy que corresponda) y la persona tiene una puerta real para volver a entrar.
2. Decisión de producto (elige TÚ la robusta / buena práctica; no preguntes a Jürgen):
   - El aviso nombra el sitio concreto donde volver a entrar (p. ej. «Dónde viven tus datos» o la puerta de Grupos que realmente abre el sign-in), no un «vuelve a iniciar sesión» genérico.
   - Si el banner de Almacenamiento hoy exige cambios personales pendientes, amplíalo (o añade puerta equivalente) para el caso «solo outbox de grupos + sesión caducada / stoppedUntilSignIn», de modo que la puerta exista al llegar.
   - Si el SDK aún tiene sesión guardada pero el servidor rechaza (p. ej. attest inválido leído como caducidad), no dejes a la persona sin salida: la misma puerta de sign-in debe abrirse.
   - No reabras el debate de «descartar outbox en silencio»: eso es el ticket hermano `groups-outbox-rows-without-a-live-session-have-no-exit` (no lo toques salvo residual mínimo inevitable).
3. Tests de punta a punta que fijen: (a) copy nombra la puerta; (b) la puerta es alcanzable en el caso solo-grupos; (c) no se vuelve al «revisa tu conexión» ni a un callejón sin salida.
4. Locales: si tocas strings, los 16. Respeta voseo en es-AR (`BRAND-VOICE` §9.4).
5. Residuales nuevos → ticket propio en backlog (uno por hallazgo), no empaquetar.
6. Al terminar: gate, PR a `2.1`, merge, board (`tickets/` + `docs/TICKETS.md`), `/cerrar-total`.

## MODO AUTÓNOMO (norma Jürgen 2026-09-22, vigente)
La regla del repo «espera aprobación si >3 archivos» / «¿Sigo?» tras el plan queda suspendida en este encargo. Implementa de punta a punta hasta gate / PR / merge / `/cerrar-total` sin pedir permiso para continuar. No uses AskUserQuestion hacia Jürgen: elige siempre la opción robusta / de buena práctica (Recommended). Solo para si necesitas su dispositivo, secretos o acceso que no tienes.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- El ticket `groups-outbox-rows-without-a-live-session-have-no-exit` (descarte de emergencia / sello userID): aparte.
- Residuales low del #252 (`cloud-signout-personal-session-expiry-does-not-say-where-to-sign-in`, `cloud-signout-upstream-rejections-with-a-healthy-pull-say-a-moment-more`, `push-unexpected-4xx-is-told-to-try-again-later`) salvo solape mínimo inevitable; si solapan, anótalo y deja residual apuntando.
- No edites el árbol principal de Jürgen; trabaja en tu worktree.

## Como se sabe que esta bien
- Criterios del ticket cumplidos (puerta real + copy que la nombra en el caso solo-grupos).
- Tests verdes que cubren el caso.
- PR mergeado a `2.1`, ticket en `done`, `docs/TICKETS.md` al día, `/cerrar-total` limpio.
- Nada pendiente de Jürgen salvo device-QA explícito (este cambio no debería pedirlo si los tests ejercen el flujo).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué puerta?** → La tarjeta «Sincronización» de «Dónde viven tus datos» y su «Iniciar sesión» (`signInToResumeSync`).
Por qué: re-firma con el proveedor de la cuenta y reanuda el motor, que en la nube sube también el outbox de grupos (piggyback).
Descartadas: «Nuevo grupo» (enruta por `hasSession`, no ata la cuenta) y un botón dentro del aviso de cierre (el `.alert`
compartido con botón condicional es el patrón medido como «rompe la app»; y el encargo pide texto + puerta).

**D2 · ¿Qué dice el aviso?** → Motivo nuevo `.cloudSessionExpired`, solo en el cierre en la nube (pasos 1 y 2): «Tu sesión
caducó. Abre «Dónde viven tus datos», aquí en Perfil, y toca «Iniciar sesión»…». Las celdas privadas (C, F) siguen con
`groups.errors.sessionExpired`: su puerta es otra. Solapa con el residual personal (`cloud-signout-personal-session-expiry-
does-not-say-where-to-sign-in`): el motivo y la puerta son los mismos, así que se cubre y se anota allí.

**D3 · El banner exige cambios personales** → cuenta personal vivos + grupos vivos (`GroupSyncOutbox` sin `rejectedReason`).
Lógica pura extraída para medirla. Si cualquiera de los dos recuentos falla, se ofrece firmar sin cifra (molde vigente).

**D4 · La puerta tiene que estar al llegar** → cuando el cierre en la nube bloquea por sesión caducada, para el motor en
`.stoppedUntilSignIn` (`CloudSyncRuntime.stopUntilSignIn()`, solo desde `.running`) y refresca el controller. Es el mismo
veredicto que el siguiente ciclo daría: el JWT es el mismo para `/sync` y `/groups`.

**D5 · Sesión guardada que el servidor rechaza** → el atajo «hay sesión y hay token ⇒ solo despierta» se sustituye por una
prueba real: un ciclo; si vuelve `.sessionExpired`, se firma. Con la sesión borrada se firma directo.

**D6 · Otra cuenta por la puerta** (criterio 3 del ticket) → la firma se ata al dueño del motor (`engine.currentUserID`, el
`sub` con el que arrancó). Si entra otra: se cierra esa sesión local (conservando el proveedor de la cuenta del teléfono),
no se reanuda nada y se avisa. Y el ciclo del motor personal no corre con un `sub` distinto de su dueño (red para las otras
entradas, p. ej. «Nuevo grupo»). El sello por fila del outbox de grupos sigue siendo del ticket hermano; no se toca.

**D7 · Locales** → 2 strings nuevos × 16, voseo en es-AR.

**D8 · (tras la review) ¿Y tras relanzar sin sesión?** → la tarjeta sale también con el motor en `.idleSignedOut` sin sesión,
firmar lo arranca, y sin dueño en memoria el ancla es el sello del claim (el gate de `start()`). El proveedor de la puerta sale
del faro cuando su hash es el del dueño.
Por qué: es el caso principal del ticket y la primera versión lo dejaba sin puerta (tres lentes). Alternativa descartada:
que `stopUntilSignIn` rebajara `.idleSignedOut` — el motor no tiene dueño ahí y el estado ya dice lo mismo.
