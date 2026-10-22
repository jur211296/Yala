---
id: adopt-terminal-claims-ready-without-checking-engine
status: backlog
priority: low
created: 2026-09-07
updated: 2026-10-08
source: review adversarial de `reentry-killswitch-closes-both-doors` (2026-09-07)
---

# «Tu cuenta está lista» se afirma sin comprobar que el motor arrancó

Sale de la review adversarial del chip del kill-switch, que hizo que la re-entrada terminara en una
pantalla de «listo» en vez de pedir un relanzamiento.

## El hueco

La terminal se deriva de `uiState` (`.cloudActive` → `.reentryReady`), y `uiState` sale de
`CloudMigrationUIStateDeriver.derive`, que solo conoce **par persistido + fase + mount**. Nunca
pregunta por el runtime. El arranque, en cambio, es una `Task` no esperada y sin resultado
(`startRuntimeIfStable`), y `startShared` puede ser un **no-op total** por motivos que `derive` no
puede ver:

- `guard CloudSyncFlags.syncRuntimeEnabled` — hay un kill-switch por medio;
- `guard let userID = session.currentUserID` → `.idleSignedOut`;
- `session.claimAction == nil` → `runtimeBlockedByUnclaimedIdentity`. Y `runAdoptFlow` **tolera
  explícitamente** no haber estampado el claim: sigue adelante dejando el breadcrumb
  `claim-stamp skipped: nil userID`.

⇒ el usuario puede leer «todo listo, continúa», quedar persistido en `.cloud`, y no tener motor.

## Lo que acota el daño (y por qué esto es backlog y no bloqueante)

No es permanente: `resumeIfNeeded` en el boot y `rekickIfParked` en **cada** vuelta a primer plano
vuelven a intentarlo, así que es degradación temporal, no pérdida. Antes del chip la terminal era el
relanzamiento, que garantizaba un boot fresco — el chip cambia «reintento garantizado e inmediato»
por «reintento en el siguiente foreground».

## Un residual hermano, del mismo cambio

El testigo de mount se captura **una vez** al construir el container, así que el proceso se queda con
`neutralNoMirror` toda la sesión aunque ya esté en modo nube. Con eso, `shouldOfferICloudRestart`
pasa su `guard !isCloudModeMount` y —con cuenta iCloud en el OS— `checkForICloudMismatch` puede
ofrecer «reinicia la app» en cada vuelta a primer plano. La condición **ya existía** en el mount
neutro antes del adopt; lo que cambia el chip es que ahora el usuario **se queda horas en ese
proceso** en vez de matarlo en el minuto uno.

## Qué haría falta

- Que la terminal de «listo» observe el estado REAL del runtime (`CloudSyncRuntime.shared?.state`)
  en vez de derivarlo del journal, y degrade a un mensaje honesto si el motor no arrancó.
- O, más barato: un canario cuando la terminal se pinta con el runtime en `.idle`, para saber si
  esto ocurre en la práctica antes de construir la pantalla.
- Decidir qué hacer con `shouldOfferICloudRestart` sobre un proceso que ya es de modo nube.

## Relacionados

- [[reentry-killswitch-closes-both-doors]] — el chip del que sale

## Medido en 2.1 (triage 2026-10-08)

- `CloudWelcomeSignInFlow.phase(for:)` sigue derivando `.reentryReady` del `uiState` (~200), y `readyContent` no mira `CloudSyncRuntime`.
- El residual hermano sigue: `shouldOfferICloudRestart` usa `isCloudModeMount`, que da `false` con `.neutralNoMirror`; sale una vez por proceso (`iCloudMismatchAlreadyDetected`).

Triage 2026-10-08: abierto · sin prioridad → low · degradación temporal: resumeIfNeeded y rekickIfParked reintentan en el siguiente primer plano.
