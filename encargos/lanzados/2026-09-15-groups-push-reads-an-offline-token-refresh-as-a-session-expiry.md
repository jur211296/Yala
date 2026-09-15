# Implementar ticket: groups-push-reads-an-offline-token-refresh-as-a-session-expiry

## Contexto
Cola autónoma bypass. Tras #170. «Tu sesión caducó» también sale cuando solo estás sin conexión (token refresh offline leído como expiry).

## Decisión de Jürgen (2026-09-15)
**Separar en el cliente** «sin conexión» de «sesión caducada». No aceptar que offline diga caducada.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board repo (`tickets/` + `docs/TICKETS.md`), merge, `/cerrar-total`. NO sync store/Kanban del panel. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank. Device-QA → `tickets/qa/` si aplica.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.
No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer ticket + cadena token refresh / classify sessionExpired.
2. Separar offline vs caducada en copy/clasificación.
3. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Store/Kanban panel. Wipe de prod.

## Como se sabe que esta bien
Sin red ≠ copy de sesión caducada; sesión caducada de verdad sigue el copy correcto; tests; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones

> Con Jürgen delante (sesión diurna, 2026-09-15). D4, D5 y D6 las contestó él por `AskUserQuestion`, las tres con
> la recomendada. El resto son técnicas y las tomé yo con lo medido. Se discuten en el PR.

**Lo medido que las sostiene** (código de la app y supabase-swift 2.50.0). El SDK solo borra la sesión guardada ante
cuatro respuestas del servidor —`session_not_found`, `session_expired`, `refresh_token_not_found`,
`refresh_token_already_used`—, y la borra antes de lanzar (`Internal/APIClient.swift`, `sessionCleanupErrorCodes`).
Sin red lanza y la deja donde estaba. `CloudAuthService.accessToken()` convierte cualquier fallo en `nil`, y el
push y el pull de Grupos leían ese `nil` —y el refresh forzado nulo tras un 401— como `.sessionExpired`.

**D1 · ¿Con qué se distingue «sin conexión» de «sesión caducada»?** → Con lo que el SDK conserva cuando el token no
llega (`CloudAuthService.canRenewSession`, inyectado en `GroupsSyncClient`).
Por qué: el SDK ya separa los dos casos al decidir si borra. Alternativa descartada: clasificar el error que lanza,
que re-deriva su taxonomía en la app y se rompe al actualizarlo.

**D2 · ¿`hasSession` o `canRenewSession`?** → `canRenewSession`.
Por qué: `hasSession` lleva el seam `-uitest-fake-cloud-session`, que dice «hay sesión» sin ninguna guardada. Con
él, un XCUITest con sesión fingida y cambios de grupos pasaría del bloqueo inmediato a 45 s de reintentos. En
producción valen lo mismo. Alternativa descartada: reusar el `sessionCheck` del cliente, que es `hasSession`.

**D3 · ¿Qué ramas cambian?** → El token nulo del push y del pull, y el refresh forzado que devuelve `nil` tras un 401,
también en los dos. El 401 cuyo refresh devuelve el MISMO token sigue siendo sesión caducada.
Por qué: las cuatro son «la renovación falló y el SDK no borró la sesión». El mismo token no es «no llegó»: llegó y
el servidor lo rechaza. Alternativa descartada: solo las dos guardas que cita el ticket, que dejaban la mentira viva
si la red cae entre el 401 y el refresh.

**D4 · ¿Qué dice el aviso sin red fuera de la nube?** → (Jürgen) El mismo texto en Ajustes, la hoja del Apple ID y
la puerta de Grupos del Welcome: «Un momento más · Todavía estamos terminando de guardar unos cambios…». El Welcome
gana una rama propia para `.transient` que lee `SignOutBlockedCopy`.
Por qué: su rama por defecto dice «Vuelve a entrar con esa cuenta», así que arreglar el push no bastaba ahí. Que
«espera unos segundos» no encaje sin red ya pasa hoy con la sesión vigente, y va a ticket aparte.
Ajuste de la review: el mensaje es el compartido y el título, el de las otras ramas de esa pantalla («Faltan cambios de
tus grupos por subir»), para no tener dos títulos para el mismo hecho.

**D5 · ¿Entran salir de un grupo, aceptar una invitación y crear un grupo?** → (Jürgen) No: ticket aparte.
Por qué: es otro cliente (`GroupsMembershipClient`), con RPC de un solo intento cuya lectura de un fallo pasajero
hay que medir pantalla a pantalla.

**D6 · ¿Cuándo suben los cambios al volver la red?** → (Jürgen) En el siguiente reintento: backoff de 5 s a 5 min, o
al momento si hay un guardado local. Sin vigilante de conexión.

**D7 · ¿Y los otros clientes con el mismo patrón?** → Merkle y el registro del push token no cambian: tratan igual
los dos casos y no hay nada observable. El canal personal y los servicios de cuenta → ticket `medium`.
Corrección de la review: escribí «Modo Nube apagado», y no lo está. La tarjeta de alta en la nube se ofrece en
producción desde el 2026-09-09 (`CloudSyncFlags.bornCloudChoiceEnabled`), así que puede haber cuentas `.cloud`, y en
ellas Grupos cicla dentro del runtime personal, que sigue parándose sin red. Sigue siendo otro objeto y no entra aquí,
pero el ticket sube de `low` a `medium`.

**D8 · ¿Cómo se prueba?** → Unit en las dos direcciones (push, pull y 401 sin refresh). El loop que no para y sube la
fila en la vuelta siguiente, sin re-arrancar. Un test de contrato del SDK con `AuthClient` en memoria: la premisa de
D1, ejecutada en vez de leída. Y un escaneo acotado de la rama nueva del Welcome. Los tests que hoy paran el loop con
un 401 reciben `canRenewSession: { false }` explícito: sin eso leerían el singleton y, en un simulador con sesión
guardada, colgarían. Mutantes: las cuatro ramas, el predicado invertido y la rama del Welcome.
La review añadió dos mutantes (el mismo token tras un 401 y el botón de salida del Welcome) y un fusible en los tests
de loop: con el predicado invertido colgaban en vez de dar rojo.

**D9 · ¿Qué documentos afirman el bug vivo?** → Se corrigen en el PR: el docblock de `BlockReason.sessionExpired`, el
de `canRenewSession` (gana un segundo consumidor con el contrato inverso), el ticket
`cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` y una regla nueva en
`.claude/rules/swiftdata-cloudkit.md`. `docs/ESTADO.md` no se toca desde el worktree (ADR-008).

**D10 · ¿Device-QA?** → Aplica y no es simulable: pide una sesión real de Supabase con el token caducado y el teléfono
sin red. El ticket va a `tickets/qa/` con su guion.

**D11 · Hallazgos que salen de medir** → tickets nuevos, sin implementar: las acciones de grupo (D5), el canal personal
(D7), el «espera unos segundos» sin red (D4) y el 401 por App Attest ausente, que el canal también lee como sesión
caducada (`gateway/src/groups/routes.ts` responde 401 `yala_attest_required` en producción).

**D12 · Entrega** → rama y PR a `2.1`, gate completo, review adversarial (toca sync y sesión), merge y
`/cerrar-total`, como pide el encargo.
