# Si la sesión en la nube sobrevive a «Cerrar sesión», el teléfono queda como recién instalado con esa sesión dentro

## Contexto
Cola A autónoma (riesgo real): tras «Cerrar sesión» el boot-wipe borra stores y preferencias pero **no** toca el llavero de CloudAuth (`com.yala.cloudauth`). La sesión de Supabase puede sobrevivir a `signOut(scope: .local)` y un refresh la repone. El teléfono se ve «nuevo» con la sesión anterior viva: la siguiente persona (o otra cuenta) puede bajar Grupos de quien cerró.

Ticket: `tickets/backlog/sign-out-exits-do-not-verify-the-cloud-session-closed.md`.
Hermano ya mergeado: `detach-does-not-verify-the-cloud-session-actually-closed` (PR #255) — ahí nació este residual.

**Decisión de producto ya tomada (Frank, robusta, 2026-09-26): AMBAS.**
1. Los cierres comprueban que `signOut()` dejó la sesión fuera **antes** de armar el wipe.
2. El boot-wipe también purga el llavero de sesión (y los pares SIWA/Google que `purgeAll()` se lleva), como ya hace el retiro de «Empezar desde cero».
No preguntes a Jürgen. No abras AskUserQuestion por este techo: ve con las dos capas.

Hora Lima diurna (antes de 21:00): AskUserQuestion solo si aparece un bloqueo de acceso/secreto/dispositivo que no puedas resolver; producto/techos los eliges tú (opción robusta / Recommended).

**MODO AUTÓNOMO (override Jürgen 2026-09-22):** la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan **queda suspendida**. Implementa hasta gate → PR → merge a `2.1` → `/cerrar-total` sin pedir continuar. Solo para si hace falta un secreto/dispositivo de Jürgen o una decisión demasiado grave para asumir (esta no lo es).

## Que se pide
- Cerrar el agujero: tras cualquier «Cerrar sesión» / camino que arma `armSignOutWipe`, la sesión de nube no puede quedar viva en el teléfono.
- Capa 1: los cierres de `CloudSessionSignOut` (y caminos equivalentes) **comprueban** el resultado de `CloudAuthService.signOut()` (`sessionIsGone` / fallo cerrado) antes de armar el wipe; si la sesión sigue, no finjas el cierre — reintenta o falla de forma que el usuario no quede con un teléfono «vacío» y la sesión dentro.
- Capa 2: `performSignOutWipeIfArmed` (boot-wipe) también purga el llavero de CloudAuth y los pares SIWA/Google, alineado con `CloudSessionRetirement` / «Empezar desde cero».
- Tests de comportamiento que fallen si alguien vuelve a descartar `sessionIsGone` o si el wipe deja el llavero intacto.
- Actualiza reglas en `swiftdata-cloudkit.md` / docs de sesión si aplica.
- Al terminar: board al día (`tickets/` + `docs/TICKETS.md`), PR a `2.1`, merge, `/cerrar-total`.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi
- No inventar PASS de device-QA
- No ampliar a rediseño UI (Cola B) ni a mediums sin riesgo real (Cola C)
- No revocar ni rotar secretos de staging/prod por tu cuenta

## Como se sabe que esta bien
- Gate verde en las áreas tocadas; mutantes del contrato de sign-out/wipe muertos.
- Un test demuestra: wipe armado + sesión superviviente en llavero → tras el boot-wipe la sesión ya no está.
- Un test demuestra: signOut que no deja `sessionIsGone` no arma el wipe «todo bien» a ciegas.
- Review adversarial sin hallazgos altos abiertos.
- Ticket movido (done o qa según guion) e índice `docs/TICKETS.md` al día.
- Cierre con `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Cierre voluntario con la sesión superviviente: ¿qué pasa?** → No se arma el borrado. La fase queda `.blocked` con un
motivo NUEVO (`.signOutSessionSurvived`) y reintentar es el gesto entero. Aplica a `finalizeSessionExit` (C, D, F) y a
`performCloudSecureSignOut` (E). El bloqueo va en el mismo punto que el bloqueo S2 que ya existe (tras el teardown), así que
no crea un estado intermedio nuevo.
Por qué: el encargo pide «no finjas el cierre». Alternativa descartada: armar igual y confiar en la purga del arranque: si el
llavero no borra, la purga tampoco, y el teléfono quedaría vacío con la sesión dentro.

**D2 · ¿Por qué un motivo nuevo y no `.sessionNotClosed`?** → Motivo propio y copy propio en los 17 idiomas.
Por qué: `ProfileView` silencia `.sessionNotClosed` a propósito (es del desasociar), así que el cierre quedaría mudo; y el
mensaje genérico dice «hay cambios sin subir, revisa tu conexión», que aquí es falso.

**D3 · Cierres tras borrar la cuenta (`closeLocalAfterAccountDeletion*`)** → No bloquean. Si la sesión sobrevive, arman el
retiro durable (`CloudSessionRetirement.arm`), que el arranque siguiente purga pre-mount, antes de que exista el SDK.
Por qué: la cuenta ya se borró en el servidor; bloquear dejaría a la persona sin salida tras un paso irreversible, y ese
camino exige relanzar igualmente. Alternativa descartada: bloquear como en D1.

**D4 · Capa 2: dónde purga el borrado del arranque** → `performSignOutWipeIfArmed` arma el retiro y lo consume con
`purgeAll()` + `isEmpty()`, justo después del guard S3. Si no queda vacío, el arm del retiro sobrevive y lo termina el
`purgeIfArmed()` del arranque siguiente.
Por qué: reusa el mecanismo probado de «Empezar desde cero» y verifica, porque en el swap sin relanzar el SDK está vivo.
Tras el guard S3 porque un abort significa «el cierre no ocurrió». Se lleva los pares SIWA/Google: decisión del encargo.

**D5 · ¿El borrado solo-grupos (`performGroupsOnlySignOutWipeIfArmed`) también purga?** → No.
Por qué: solo lo arma el cierre tras borrar la cuenta solo-grupos, que ya cubre D3. Queda fuera de alcance.

**D6 · Tests** → Unit de comportamiento para la capa 2 (llavero real con un service de test: sesión guardada → tras el
borrado ya no está; el abort S3 no purga). XCUITest de la celda F con `-uitest-sign-out-keeps-session` para la capa 1: sale el
aviso y no la pantalla de reabrir. Source-scan del orden «comprobación antes del arm» en los cuatro sitios, al molde de
`GroupsDetachSessionSurvivesTests`. Mutantes sobre las cuatro comprobaciones y la purga.
