---
id: welcome-adopt-cancel-dialog-says-from-here
status: backlog
priority: low
area: "modo-nube, onboarding, adopt, copy"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `welcome-adopt-effect-failure-has-no-reason-and-no-cancel` (2026-09-23), lente de SwiftUI y copy"
---

# Al cancelar la entrada a tu cuenta desde la bienvenida, el diálogo dice «desde aquí» y te saca de la pantalla

## El problema, en lenguaje de usuario

Entro en mi cuenta de la nube desde la bienvenida y toco «Cancelar la activación». El diálogo dice «Puedes volver a
activar la nube en este dispositivo desde aquí cuando quieras». Al confirmar, la app me lleva a la pantalla de elegir,
y el «aquí» ya no existe. Puedo volver por «Ya tengo cuenta», pero la frase se escribió para la tarjeta de Almacenamiento.

## Por qué pasa (leído el 2026-09-23)

La bienvenida reusa el cuerpo del diálogo de Almacenamiento (`StorageFailureCopyLogic.cancelMigrationBody`:
`storage.confirm.cancelAdoptBody` / `cancelAdoptEffectBody`), por decisión de Jürgen del mismo día: «mismos textos».
Engañoso, no falso.

## Qué habría que decidir (es de producto)

¿Se deja así, o la bienvenida lleva un cuerpo propio sin «desde aquí» (dos claves nuevas en 16 idiomas)?
