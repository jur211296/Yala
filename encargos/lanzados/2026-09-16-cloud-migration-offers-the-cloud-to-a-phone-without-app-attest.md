# Sin App Attest, no ofrecer «Migrar a la nube»

## Contexto
Ticket: `tickets/backlog/cloud-migration-offers-the-cloud-to-a-phone-without-app-attest.md`.
Último camino al alta completa que no mira la puerta: #180/#181 ya gatean chooser y pantalla de entrar. La card de migración en Ajustes (`StorageRowGateLogic.offersCloudMigrationEntry`) solo mira remoteEnabled/isEngaged; sin Attest la migración reintenta sin fin.

## DIURNO (Lima 6:00–21:00)
Puedes usar AskUserQuestion si necesitas decisión de producto o acceso de Jürgen.

## Decisión recomendada (si no preguntas)
**Opción 1:** extender la puerta del alta a la card de migración — sin App Attest no se ofrece «Migrar a la nube». Alinea con #180/#181.

## Que se pide
1. Gatear la card / entrada de migración con el mismo criterio Attest que el alta.
2. Tests según el repo.
3. Gate, commit, `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1 si OK, `/cerrar-total`. Bugs → ticket. No Kanban/store.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/`/cerrar-total` sin preguntar por gate/commit. Solo parar ante decisión/acceso real (AskUserQuestion de día). UI tests CI advisory.

## Que NO
marketing/; no reopen #180/#181 salvo patrón.

## Como se sabe que esta bien
Sin Attest: no se ofrece Migrar a la nube. Con Attest: igual. Board + `/cerrar-total`.

## Avisos Frank
Webhook Mini (URL/key local): (1) decisión/acceso; (2) PR/preview; (3) `/cerrar-total` + resumen usuario; (4) sin siguiente — una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> Sesión diurna (07:04 Lima). La decisión de alcance (D1) se le preguntó a Jürgen y eligió la recomendada; lo demás es
> técnico y se discute en el PR.

### Lo medido antes de decidir

- **La tarjeta tiene dos caras, y es una sola tarjeta.** `migrateCard` pinta «Migrar a la nube» o, si el mirror trae el
  marcador de un líder (`markerDecision() == .secondaryDeviceCloudLogin`), «Activar la nube en este dispositivo». Las dos
  arrancan el MISMO flujo (consent → `proceedToSignInStep` / `onChooserDismissed` → `startMigration`), y quien decide
  migrar o adoptar es el servidor en el claim.
- **Un solo candado para el render y para la acción**: `offersCloudMigrationEntry` gatea el `if` de la tarjeta en
  `case .idle` y los dos arranques (`abortIfCloudEntryClosed`). Llamadores de `startMigration(consentPath:signIn:)` en
  `Yala/`: tres, los tres en `StorageSettingsView`. `CloudSyncDebugView`, entero bajo `DEV_BUILD`, arranca el runner
  compartido sin pasar por la tarjeta: es depuración. *(Corregido tras la review: decía «su propio runner».)*
- **Sin App Attest las dos caras acaban igual (leído, sin ejecutar).** El claim va por `requireUser`, sin attest
  (`gateway/src/sync/account.ts`), así que pasa: «Migrar» deja la cuenta **creada** en el servidor (`created`). Después
  todo sube o baja por `/sync/push|pull`, que en producción exige attest: `SyncPushClient` no manda el header con token
  `nil`, el gateway responde 401 y el cliente lo lee `.sessionExpired`, que `MigrationSnapshotUploader` y
  `enumerateBackendSyncIDs` (adopt) tratan como transitorio. El runner reintenta; el modo no se persiste. En staging
  (`ENFORCE = "observe"`) pasa y no se ve.
- **Producción sirve `cloudModeRolloutPercent: 100`** (`curl …/config`, 2026-09-16): la fila y la tarjeta se ven hoy para
  todo el que esté en iCloud. La cabecera de `StorageRowGateLogic` todavía dice «percent 0», y eso ya tiene ticket propio
  (`storage-row-gate-comment-says-rollout-zero`).
- **Bajo XCUITest con `Yala Dev` la tarjeta SÍ se pinta hoy** (`absentDefault` = `true`), y ningún XCUITest la nombra:
  `grep storage_migrate_button YalaUITests` → cero. Con `Yala` la fila no existe (`testing.md` L163).

### Decisiones

**D1 · ¿Se esconde también «Activar la nube en este dispositivo»?** → **Sí, la tarjeta entera** (Jürgen, 07:1x, la
recomendada). Por qué: las dos caras terminan en el mismo reintento sin fin y el teléfono se queda en iCloud. Coste
aceptado: un segundo dispositivo sin App Attest de alguien que ya migró se queda sin aviso; hoy ve un botón que no termina.
Descartada: solo «Migrar», con el criterio del Welcome de no gatear entrar a una cuenta que ya existe.

**D2 · ¿Dónde vive el término?** → En `StorageRowGateLogic.offersCloudMigrationEntry`, con un parámetro nuevo sin default:
`isEngaged || (remoteEnabled && AttestSyncGate.shouldOfferCloudOnly(isAttestSupported:))`.
Por qué: es el candado que ya comparten el render y los dos arranques, y la decisión pura es la misma función que lee el
Welcome. `isEngaged` se queda fuera del término a propósito, como con el kill: la puerta corta la ENTRADA, y quien está
engaged conserva su panel (un adopt pendiente no lo está: ver D9). Descartadas: `(remoteEnabled || isEngaged) && attest`, que le cerraría el flujo a un engaged; y
un `if` suelto en la vista, que es una segunda puerta.

**D3 · ¿Qué entrada lee?** → `UITestHooks.fakeAttestSupport || AppAttestClient.canObtainSessionToken`, la misma expresión
que `WelcomeNewOptionsGate.live`. **No** `WelcomeNewOptionsGate.offersCloudSignUp`: arrastra el kill del alta
(`cloudOnboardingChoiceEnabled`), la constante born-cloud y la exclusión de uitest, que no son de la migración.
Por qué no un lector compartido: tocaría el cableado y los scans del #180. En su lugar, un scan de paridad exige que las
dos expresiones sean idénticas.

**D4 · ¿Qué ve quien no tiene App Attest?** → La pantalla sin la tarjeta: «iCloud privado» y, si aplica, la sección de
Grupos. Sin texto nuevo, como en #180/#181. La fila de Perfil no cambia: la fila no promete migrar. *(Corregido tras la
review: decía «igual que bajo el kill», y bajo el kill la fila ni se ve sin cuenta de grupos; y «la pantalla sigue
teniendo contenido», que en una sesión solo-grupos es solo «iCloud privado» — ticket aparte.)*

**D5 · ¿Hereda el kill del alta?** → No. `cloudOnboardingChoiceEnabled` es la pantalla de elección del onboarding; la
migración tiene su kill (`cloudModeEnabled`) y ya lo lee.

**D6 · ¿Cómo se prueba?** → (a) la tabla pura 2³; (b) source-scan del término entero, sobre código sin comentarios, y
paridad de la entrada con el Welcome; (c) un XCUITest con el predicado real del simulador: sin seam la tarjeta no está —con
la pantalla montada y la sección de Grupos, que va en el mismo `case`, como presencia—, y con `fakeAttestSupport` sí.
(d) Mutantes: quitar el término, invertirlo, `true` literal, cerrarlo de más, y quitar el seam en Ajustes.
Por qué: en el host de test la capacidad vale `false`, así que el lado bueno solo lo ven el seam y el scan.

**D7 · ¿En qué estado queda el ticket?** → `qa`, con un paso en iPhone real: con App Attest la tarjeta sigue saliendo. Es
el fallo caro y ningún simulador lo prueba. Comparte montaje con el paso de #180.

**D8 · ¿Qué documentación caduca?** → Los docblocks que dicen que la puerta no cubre Ajustes o que el seam solo finge el
Welcome: `AttestSyncGate` (cabecera, `classify`, `shouldOfferCloudOnly`), `AppAttestClient.canObtainSessionToken`,
`UITestHooks.fakeAttestSupport`; los de `StorageRowGateLogic` y `StorageSettingsView` que hablan solo del kill; y «La
puerta del alta» de `.claude/rules/gateway-attest.md`. **La cabecera de `StorageRowGateLogic` (percent 0) no**: la corregí
y la devolví tras la review, porque es el primer criterio de `storage-row-gate-comment-says-rollout-zero` y el segundo
—barrer las demás menciones— es otro alcance.

**D9 · ¿Quien ya tocó la tarjeta sin App Attest?** → Fuera, sin medir cuántos son, y al ticket como «lo que no cubre».
**Corregida tras la review**: decía que conserva su progreso, y eso solo vale para «Migrar». En «Activar en este
dispositivo» el claim devuelve la fase a `notStarted` con el adopt pendiente, la pantalla lo pinta `.idle` y sin App
Attest pierde la tarjeta sin ver progreso mientras el adopt se reintenta en segundo plano. Antes tenía un botón que
relanzaba el mismo bucle.

### Tras la review (tres lentes: producto, tests y mutantes, reglas y docblocks)

**D10 · El colateral de Grupos** → Anotarlo en `groups-block-has-no-route-to-storage-settings` (Jürgen, 08:0x, la
recomendada). La pantalla «Esa cuenta ya tiene Yala completo» dice «Se decide en Ajustes, en «Dónde viven tus datos»», y
sin App Attest allí ya no hay tarjeta. Ese ticket va a cambiar la frase por un botón y ahí se condiciona a la puerta.
Descartada: esconder la frase ya, que se rehace cuando llegue el botón.

**Lo que se arregló sin preguntar, por ser técnico:**
- **Tres redes nuevas contra cerrar de más** (la lente de tests encontró mutantes vivos): la pantalla lee App Attest una
  sola vez —una segunda lectura en el botón o en un arranque le quitaba la tarjeta o el flujo a un iPhone con App Attest
  con todo en verde—; el término y la capacidad se declaran una sola vez —una copia bajo `#if DEBUG … #else` pasaba los
  `contains` con la de Debug—; y el cuerpo entero de `abortIfCloudEntryClosed`. El XCUITest positivo mira además que el
  botón esté habilitado.
- **Documentación que afirmaba de más**: «conserva su panel» (arriba, D9), el docblock de `classify` —la tarjeta de
  Ajustes nunca llegó ahí: `classify` solo corre en modo nube—, la frase del ticket sobre los sitios que reclaman una
  cuenta completa, y el mensaje y la cabecera del XCUITest.
- **Ticket nuevo por un defecto anterior**: `groups-only-session-storage-screen-says-data-lives-in-icloud`.
- **Aceptado y dicho en el PR**: un `#if DEBUG` alrededor del botón dentro de `migrateCard` sigue sin red; no es de la
  puerta sino de la tarjeta entera, y fijar su cuerpo ata cualquier cambio de diseño. Y la regla no amplía sus `paths:`
  a `StorageRowGateLogic`: el docblock y el scan de paridad ya avisan a quien toque ahí.
