---
id: adopt-claim-stays-parked-with-no-ceiling
status: backlog
priority: high
area: "modo-nube, migración, adopt"
created: 2026-09-22
updated: 2026-09-22
source: "review adversarial de `forward-migration-steps-have-no-ceiling-and-no-exit` (2026-09-22), lente de consumidores"
---

# Al entrar en tu cuenta de la nube, el paso del 22 % se puede quedar parado para siempre si la cuenta no está disponible

## El problema, en lenguaje de usuario

Cuando entras en una cuenta de la nube que ya existe —«Ya tengo una cuenta» en la bienvenida, o «Activar la nube en
este dispositivo» en Ajustes—, la app hace el mismo paso del 22 % que «Migrar a la nube». Si la red falla, esperar está
bien: en cuanto vuelve, la app reintenta sola y termina. Pero si el motivo es de los que esperar no arregla —la sesión se
borró, la cuenta la rechaza con un 403—, la barra se queda al 22 % sin salida, igual que antes del ticket
`forward-migration-steps-have-no-ceiling-and-no-exit`.

## Por qué quedó fuera de ese ticket (medido el 2026-09-22)

Ese ticket le puso techo y «Cancelar» al paso del claim, pero **solo con «Migrar a la nube»**
(`ForwardClaimIntent.migrateOnly`, término en `MigrationRunner.driveClaim` y en `ForwardCancelScope`). Con la
intención de adoptar, la salida del techo era un callejón:

- La salida (`failedRollback` → «Reintentar» → `notStarted`) deja la pantalla de Almacenamiento en `.idle`, que solo
  ofrece «Activar la nube en este dispositivo» con marcador de CloudKit (`StorageSettingsView`). Sin él, la tarjeta es
  «Migrar a la nube», y la puerta de identidad la bloquea porque la cuenta ya tiene datos.
- En una reinstalación que entra por el Welcome, el onboarding ya está marcado (`onAdoptStarted`) y no hay forma de
  volver a él.
- El texto de la tarjeta de fallo y el del diálogo de cancelar dicen «tus datos siguen en este dispositivo», que en un
  teléfono recién instalado es falso: los datos están en la nube.

El Welcome ya separa dos de esos motivos por su cuenta (`CloudWelcomeSignInFlow.phase`: 403 → `accountBlocked`, 401 →
error con reintento), pero solo mientras esa pantalla está delante; al salir de ella, el journal sigue en
`claimingMigration`.

## Qué habría que decidir

1. **A dónde sale un adopt que se rinde.** No puede ser «Migrar»: tiene que volver a un sitio desde el que la persona
   pueda entrar en su cuenta otra vez.
2. **Si se ofrece «Cancelar»** en ese paso, y con qué texto: la frase de hoy no sirve.
3. Si el 403 y la sesión borrada tienen que avisar ANTES del techo (hoy solo lo hace la pantalla del Welcome).

## Criterios de aceptación

- [ ] El claim de un adopt tiene techo y una salida desde la que se puede volver a entrar en la cuenta.
- [ ] Ningún texto le dice a la persona que sus datos siguen en un teléfono donde no los hay.
- [ ] Test con el fallo persistente, midiendo que la fase cambia.

## Relacionado

- `forward-migration-steps-have-no-ceiling-and-no-exit` — el techo de «Migrar», y el que dejó esto fuera.
