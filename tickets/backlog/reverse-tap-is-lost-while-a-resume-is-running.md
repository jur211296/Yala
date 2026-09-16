---
id: reverse-tap-is-lost-while-a-resume-is-running
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-16
source: "review adversarial de `reverse-claim-rejection-has-no-way-out-in-the-client` (2026-09-16), lentes de estado y de pantalla: preexistente, fuera de alcance"
---

# Si «Volver a iCloud» se toca mientras la app retoma algo por su cuenta, el toque no hace nada y no lo dice

## El problema, en lenguaje de usuario

Estoy en «Dónde viven tus datos», toco «Volver a iCloud» y confirmo dos veces. No pasa nada: ni barra, ni aviso. Si lo
vuelvo a intentar un momento después, sí empieza.

## Por qué pasa (medido en el código el 2026-09-16)

- `CloudMigrationController.startReverse` no espera a que termine lo que ya está en marcha: pone `isWorking = true` y
  llama al runner directamente. `cancelReverseUpload`, en cambio, sí espera (`while isWorking`).
- Si en ese momento corre un `resume` —el re-kick de 30 s de la pantalla (`StorageSettingsView`, `rekickIfParked`) o el
  del arranque en su pre-espera de 300 s—, el runner ignora la segunda acción en silencio (`MigrationRunner.runGuarded`,
  guard `isRunning`). Los dos `submit` no hacen nada: no hay reserva, ni salida, ni alerta.
- Variante: si ese `resume` estaba en la pre-espera y entra al runner después del primer `submit`, normaliza
  `reverseConfirm` al origen y deshace el toque.
- Además, el `defer` de `startReverse` pone `isWorking = false` con el otro `resume` todavía corriendo, y vuelve a
  habilitar los botones.

El re-kick solo arranca con una fase transitoria o con efectos pendientes, así que la ventana es estrecha. Desde
`reverse-claim-rejection-has-no-way-out-in-the-client` un rechazo del servidor repone los pendientes del origen, y uno que
falla (el reconcile sin red) los deja ahí: esa es la situación en la que el re-kick corre con la tarjeta de «Volver a
iCloud» a la vista.

## Criterios de aceptación

- [ ] Un toque de «Volver a iCloud» con un `resume` en marcha empieza la vuelta cuando ese `resume` termina, o dice por qué
      no pudo.
- [ ] Los botones no se habilitan mientras siga corriendo algo.
- [ ] Test del orden (molde de `ReverseUploadControllerWiringTests.queuedCancel_runsBeforeTheResume`).

## Relacionado

- `reverse-claim-rejection-has-no-way-out-in-the-client` — la alerta de la salida del claim depende de que el toque llegue
  al runner.
