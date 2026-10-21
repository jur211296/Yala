---
id: invite-on-a-fresh-install-mounts-the-icloud-mirror-after-a-relaunch
status: done
priority: medium
area: "groups, modo-nube, onboarding"
created: 2026-10-19
updated: 2026-10-21
source: "tablero-unirse-por-enlace-en-una-instalacion-nue-t2q8 (QA guiado 2026-10-19)"
---

# Entrar por un enlace en una instalación nueva monta el espejo de iCloud si Yala se relanza a mitad

## En lenguaje de usuario

Borro Yala, la reinstalo y abro un enlace de invitación. A mitad del recorrido Yala se cierra (o la cierro). Al volver, me dice «Aquí hay datos guardados que se sincronizan con un iCloud…» y me pide dejar el teléfono en blanco, aunque yo solo quería unirme a un grupo con otra cuenta.

## Lo medido (2026-10-19)

- El primer arranque por enlace monta el store **neutro**, igual que el Welcome: el contenedor se decide antes de procesar el enlace y la ruta de invitación no marca el chooser. La hipótesis de la card («el enlace monta el espejo») es falsa para el primer proceso.
- El neutro de instalación nueva **dura un proceso**: el montaje crea el archivo del store, y el arranque siguiente, sin nada armado, adjunta el espejo (`SwiftDataConfiguration.personalStoreDecision`).
- Telemetría del iPad `5fc8fa9f`: primer arranque 21:33, y a las 21:39:26 el espejo ya exportaba en otro proceso de la misma instalación. Después, la puerta del invitado con `inviteNeutralBody` y la espera de ~8 min por `importNotQuiescent`.

## Lo que cambia

`GroupBackendInviteEntryHandler.persistIntent` arma el neutro durable del cierre de sesión (`StorageModePersistence.armNeutralMountIfUnarmed`) si este proceso montó neutro, sin onboarding y sin chooser (`GroupInviteNeutralGateLogic.armsDurableNeutralOnEntry`). Caduca solo con `hasShownWelcomeChooser`, como tras un cierre de sesión. Si ya estaba armado no toca nada, ni la marca de quién lo armó.

El neutro se retira al adoptar una cuenta completa (`onAdoptStarted` → `retireNeutralMountOnChoice`): por el enlace el chooser no se marca, y sin eso el neutro sobrevivía a la nube y «Volver a iCloud» habría montado sin espejo (hallazgo alto de la review adversarial).

## Tests

`InviteFreshInstallEntryTests`: tabla con controles (espejo montado, onboarding hecho, chooser elegido); el segundo arranque sigue neutro solo con el arma, y caduca al elegir en el Welcome; el arma no le quita la marca a su dueño. `InviteFreshInstallEntryWiringTests` fija el cableado.

## Encontrado y no tocado

El mismo hueco existe en el Welcome: matar Yala en el Welcome de una instalación nueva antes de elegir monta el espejo en el arranque siguiente. Ticket `welcome-fresh-install-neutral-mount-lasts-one-launch`.

## Vuelta del QA guiado del TF19 (2026-10-20): dos puertas seguían fallando

El enlace directo pasó. Fallaban (a) la bienvenida › «Vengo por un grupo › Tengo una invitación» con una cuenta completa, que pedía reabrir y al reabrir montaba el espejo, y (b) el relanzamiento a mitad («Conectando con tu grupo…», cerrar Yala, reabrir el enlace).

### Lo medido

- **(a)** «Tengo una invitación» sale por `leaveWelcome(to: .inviteRecovery)`, y `WelcomeMirrorRelaunchLogic.requiresMirror(.inviteRecovery)` era `true`, razón de la era CKShare. En una instalación nueva eso pedía reabrir, marcaba el chooser y el arranque siguiente montaba el espejo del iCloud del aparato.
- **(b), leído en el código (sin device)**: el CTA de la hoja (`performSilentSetup`) siembra las categorías del invitado y, justo después, el `drive(.userAction)` de ese mismo CTA vuelve a medir la puerta, que las cuenta como corpus de otra persona: el join no sale (por eso «Conectando con tu grupo…» no avanzaba) y al reabrir pide dejar el teléfono en blanco. El montaje, en cambio, SÍ era neutro.

### Lo que cambia

- `.inviteRecovery` deja de pedir el espejo, y «Tengo una invitación» ya no marca el chooser: el enlace pegado arma el neutro duradero igual que el directo.
- La puerta del invitado gana el término `signUpStartedOnCleanStore`, que apaga solo el del corpus (nunca el del espejo). Lo apunta el CTA en el intent (`PendingJoinEntry.signUpOnCleanStoreAt`) ANTES de sembrar, y solo si el detector del Welcome no ve nada y no hay espejo: no puede cubrir un corpus que ya estaba.
- El sign-in del invitado (sesión abierta aquí, sin onboarding y con el canal arrancando al firmar, o sea no con una cuenta completa) apunta la marca de grupos de quien entra (`LateNoticeKeptGroupsMark`, la de `onEnterGroupsOnly`), para el relanzamiento entre firmar y el CTA.

### Residual, inferido

Una SEGUNDA invitación tras un kill a mitad de la primera: su intent no lleva la marca del alta, y las categorías que sembró el CTA de la primera la frenan. Pasa también si se actualiza desde un build anterior con un alta a medias.

### Tests

`InviteThreeDoorsTests`: las tres puertas como secuencia de escrituras + montaje + puerta, con sus controles (el CTA sin la marca se bloquea a sí mismo; el recorrido viejo de la bienvenida montaba el espejo; sin la marca del sign-in los grupos propios bloqueaban; el corpus de otra persona y el espejo siguen bloqueando). `InviteSignUpCleanStoreMarkTests` (la marca en el intent, back-compat). Tabla de `GroupInviteNeutralGateLogicTests` a 32 celdas.

## Device-QA (Jürgen, iPad, TestFlight 20 o Yala Dev contra staging): las tres puertas

1. **Enlace directo**: borra Yala, reinstala sin abrir, abre el enlace de «QA unión 19» › firma con Google test@ › «Unirme». Esperado: «Esperando aprobación», sin «queda en blanco».
2. **Bienvenida**: borra Yala, reinstala, ábrela › «Vengo por un grupo» › «Tengo una invitación» › pega el enlace. Esperado: no pide reabrir Yala, sigue a «Conecta tu cuenta» y acaba en «Esperando aprobación».
3. **Relanzamiento a mitad**: borra Yala, reinstala sin abrir, abre el enlace › firma con Google jur211296 › consentimiento › «Unirme». En «Conectando con tu grupo…» cierra Yala del todo y vuelve a abrir el enlace. Esperado: sin «queda en blanco», acaba en «Esperando aprobación».

## Device-QA anterior (Jürgen, iPad, TestFlight 19)

1. Borra Yala, reinstala sin abrir, abre el enlace de «QA unión».
2. En la hoja de «Unirme», cierra Yala del todo y vuelve a abrir el enlace.
3. Esperado: sigue el recorrido sin «Antes de unirte, este teléfono queda en blanco». Entra con Google `test@yala-app.pe` y únete. No debe esperar minutos en «Conectando con tu grupo…».

Cerrado en el QA guiado 2026-10-21 (iPhone de QA e iPad Air, Yala Dev @ e47b5cca9, staging): las tres puertas acaban en «Esperando aprobación» sin «queda en blanco»: enlace directo (test@), bienvenida › «Tengo una invitación» (jur211296, sin «Abre Yala otra vez») y cerrar Yala en «Conectando…» y reabrir el enlace (test@).
