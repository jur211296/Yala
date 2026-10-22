# Si la sesión caduca en «Volver a iCloud», la barra no se queda muda

## Contexto
Ticket: `tickets/backlog/reverse-before-mount-stays-stuck-with-an-expired-session.md` (medium, callejón).
Cola A→B→C hasta el lunes QA de Jürgen: priorizar callejones/puertas rotas.
Hermano de `reverse-claim-rejection-has-no-way-out-in-the-client` (ya cerrado): este es el canal de **sesión caducada**, no el rechazo del claim.

Problema: durante «Volver a iCloud», si la sesión de nube caduca en claim/drain/verify/freeze, la barra se para muda; «Retomar» no ayuda; no hay puerta a volver a entrar.

## Decisión de producto
La pantalla debe decir que hay que volver a entrar y ofrecerlo; tras entrar, retomar la vuelta. En verify, no gastar reintentos de red ni acabar en fallo con abort pendiente. Criterios del ticket mandan.

## Qué se pide
Implementar según criterios de aceptación del ticket. Tests de comportamiento. PR a `2.1`. Actualizar ticket + `docs/TICKETS.md`. Al terminar: `/cerrar-total`.

## Modo día (6:00–21:00 Lima)
Puedes AskUserQuestion si aparece decisión de producto/acceso no cubierta. No inventes ambigüedades: el ticket ya define el outcome.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando:
  (1) decisión de producto/acceso de Jürgen;
  (2) PR abierto o preview listo;
  (3) terminaste y vas a /cerrar-total — resumen corto en lenguaje de usuario;
  (4) tramo acabado sin siguiente paso claro — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.

## Qué NO hay que tocar
marketing/, Web/ (Lola). No reabrir el canal de rechazo de claim ya cerrado salvo acoplamiento real.

## Cómo se sabe que está bien
Criterios del ticket + PR mergeable a 2.1 + board al día.

## Paso 0 — decisiones (2026-09-17, aprobadas por Jürgen en la sesión)

Ocho nodos. Las cuatro fases del ticket se midieron primero contra el código y el ticket acertaba: claim
`return false` sin evento, drain lo lee `.transient`, verify lo lee `.networkTimeout` y gasta reintentos de
red, freeze devuelve `false`.

### D1 · Qué separa «tu sesión caducó» de «no hay red»

**El token nulo NO basta.** `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (16-sep) midió
que sin red la renovación devuelve `nil` con la sesión guardada intacta. Decide `canRenewSession`: solo cuando
el SDK BORRÓ la sesión, o cuando el gateway responde 401 de verdad, es «vuelve a entrar».

- En `reverseDrainAll` y `reverseVerify` la separación **ya existe**: la hacen `SyncPushClient` y
  `SyncPullClient` desde ese ticket, y `CloudMigrationController.makeExecutor` les pasa el `canRenewSession`
  del proveedor de sesión. Aquí solo hay que dejar de colapsar su `.sessionExpired` en `.transient`.
- En `reverseClaimLeader` y `reverseFreezeBackend` **hay que hacerla aquí**: esos dos pasos tienen su propio
  `guard let jwt = await session.accessToken()`, y ese `nil` es exactamente el falso positivo del ticket
  hermano. `/account/migration` no exige App Attest (medido en `CloudAccountClient`), así que su 401 es JWT y
  no hay que separar el segundo 401 del attest, como sí hubo que hacer en `/sync/*`.

**Descartado:** tratar todo token nulo como caducada. Es el bug que se cerró ayer, y lo reintroduciría en la
vuelta a iCloud.

### D2 · Dónde se le dice

**Caption + botón dentro de la tarjeta de progreso de la vuelta**, molde exacto de la espera de
`reverseUpload`.

**Descartado: alerta al momento.** El hermano del claim (`reverse-claim-rejection-has-no-way-out-in-the-client`)
sí usa alerta, y la razón no se traslada: allí la fase VUELVE al origen y la barra solo parpadea, así que sin
alerta el gesto parecería no hacer nada. Aquí la barra se QUEDA, con la tarjeta delante, y el estado dura
mientras la sesión no vuelva. Una alerta sobre un estado que no cambió por su toque es un modal de más.

### D3 · El hecho vive en memoria, no en el journal

Molde de `lastClaimBlocker` y `lastReverseUploadSample`: describe la observación, no el estado durable. El
journal sigue en su fase, retomable, y cada paso que avanza limpia la observación.

**Quién la repone tras cerrar y abrir Yala:** el resume del arranque y el re-kick de 30 s de la pantalla —
medido, `MigrationBootDecision.decide` da `.resume` para las cuatro fases. **El precio, dicho:** en un proceso
nuevo cuyo boot-resume no llegó a producirla, la tarjeta enseña la barra de siempre hasta el primer re-kick
(≤30 s).

**Descartado: journalearla.** Habría que borrarla en cada paso con éxito, y un testigo que sobrevive a lo que
describe es el bug-class de `reverse-claim-exit-with-a-restored-failing-effect-keeps-the-engine-off`.

### D4 · El proveedor del sign-in no se elige

`CloudAuthService.storedProvider()`, determinista, igual que `signInToResumeSync`, con su mismo belt: si la
sesión revivió por otra entrada mientras el botón seguía en pantalla, no se re-firma — se despierta y se
retoma. Ofrecer chooser a mitad de una vuelta que pertenece a un `sub` concreto invita al mismatch R9.

### D5 · Tras volver a entrar, la vuelta se retoma sola

Criterio del ticket. El botón firma y llama al `resume()` de siempre; no hay un segundo gesto que buscar.

### D6 · La IDA no cambia, y se fija con un test

`verify()` es compartido: sus llamadores son `driveVerify` (ida) y `driveReverseVerify` (vuelta), contados. El
`.sessionExpired` nuevo lo mapea `driveVerify` al trato de hoy (`networkTimeout`, que gasta reintento y puede
degradar a `failedRollback`), con un test que lo fija para que el mapeo no se caiga en silencio.

**Descartado por alcance:** extenderlo a la ida. Es otro objeto —otra superficie (`lastClaimBlocker`, la
pantalla de adopt) y otro terminal, que sí revierte—, con su propia QA. Residual con ticket.

### D7 · En `reverseVerify` se corta retomable SIN evento

Es el criterio 3 del ticket y el molde de `driveReverseClaim`: sin evento no se gasta `verifyNetworkRetries`,
así que la fase nunca degrada a `reverseFailedRollback` y nunca queda el `.reverseRollback` pendiente —que con
la sesión caducada lanza en cada resume.

### D8 · Canario nuevo, `cloudReverseBlockedByExpiredSession`

`detail` = la fase (`claim`/`drain`/`verify`/`freeze`), más un breadcrumb por fase. Sin canario no se sabe si
esto le pasa a alguien, y el hermano del claim ya lleva el suyo (`cloudReverseClaimRejected`).

### Copy

Una sola clave nueva: `storage.progress.reverseNeedsSignIn` = «Tu sesión caducó. Vuelve a entrar para terminar
de volver a iCloud.» El botón **reusa** `storage.sync.signInButton` («Iniciar sesión»), que es el literal que
ya usa el banner hermano de esta misma pantalla: una clave menos en 16 idiomas y cero divergencia entre dos
botones que piden lo mismo.

### Lo que la review adversarial corrigió del Paso 0 (2026-09-17)

Cuatro lentes (máquina y journal · sesión y transporte · pantalla y tests · las reglas de área contra el diff)
tumbaron dos decisiones de arriba. Se dejan con su enunciado original para que se vea qué cambió:

- **D2 decía que las dos esperas de la tarjeta iban antes que la sesión caducada**, porque «describen lo que está
  pasando AHORA mientras la sesión caducada es una observación del último intento». **Falso, y medido:**
  `resumeWaitingForImport` no depende de la fase y su tope de 300 s la deja encendida **a propósito**, así que una
  vuelta parada por la sesión decía «esperando a que iCloud termine…» con el botón útil apagado debajo, para siempre
  si el tope vencía. ⇒ la sesión caducada va PRIMERA: de dos cosas ciertas a la vez, manda la que la persona puede
  desatascar.
- **D4 decía «molde de `signInToResumeSync`, con su mismo belt».** El molde **no vale aquí, y su belt tampoco**:
  1. Su belt comprueba `hasSession && accessToken() != nil`, y la observación que enciende la tarjeta la produce sobre
     todo un 401 del gateway **con la sesión intacta** — ahí los dos son ciertos y `accessToken()` devuelve el mismo
     JWT rechazado. El belt saltaba la firma y el botón no firmaba **en el caso principal del ticket**. El rescate
     correcto es `forceRefreshAccessToken()`, que rota de verdad (el molde real es el retry del 401 de Grupos).
  2. Su seguridad de identidad no viaja con el método: `signInToResumeSync` termina en `handleBecameActive()`, cuyo
     gate deja el motor `.idle` si la cuenta no es la del device. Aquí se conduce el runner directo —la fase de la
     vuelta no es estable— y `reverseDrainOnce` sube un outbox sin dueño. ⇒ hace falta un guard propio: el `sub` se
     captura antes de firmar y, si cambia, **no se retoma**.
  3. Su `isWorking` va antes del primer `await`; el mío iba después, y el re-kick de 30 s se colaba en medio.

**La lección, que es la que se repite:** decir «molde de X» no traslada las precondiciones de X. Este Paso 0 citó tres
veces a `signInToResumeSync` y las tres veces heredó algo que en su sitio era cierto y aquí no.
