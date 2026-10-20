---
id: invite-on-a-fresh-install-mounts-the-icloud-mirror-after-a-relaunch
status: qa
priority: medium
area: "groups, modo-nube, onboarding"
created: 2026-10-19
updated: 2026-10-19
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

## Device-QA (Jürgen, iPad, TestFlight 19)

1. Borra Yala, reinstala sin abrir, abre el enlace de «QA unión».
2. En la hoja de «Unirme», cierra Yala del todo y vuelve a abrir el enlace.
3. Esperado: sigue el recorrido sin «Antes de unirte, este teléfono queda en blanco». Entra con Google `test@yala-app.pe` y únete. No debe esperar minutos en «Conectando con tu grupo…».
