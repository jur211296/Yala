---
id: private-gate-back-from-found-keeps-a-resumed-arm
status: backlog
priority: medium
area: "onboarding, modo-nube"
created: 2026-09-27
source: "review adversarial de `private-gate-leave-after-a-halfway-wipe-forgets-the-zone` (2026-09-27, lente de estados durables); inferido por lectura, NO reproducido"
---

# Volver desde «Encontramos datos tuyos» tras un corte deja armado el borrado, y la nube lo termina a ciegas

## El síntoma, en lenguaje de usuario

Confirmo borrar mis datos de iCloud en «Es mi primera vez → privado» y la app se cierra a mitad (antes de tocar
iCloud). Al volver, la app me enseña otra vez «Encontramos datos tuyos en iCloud». Me arrepiento, toco «volver» y elijo
crear una cuenta en la nube. En el arranque siguiente la app termina aquel borrado sin preguntar: se lleva mi iCloud
privado, lo del teléfono (ya de mi cuenta nube) y mis grupos.

## Lo medido (2026-09-27, leyendo código)

- `WelcomePrivateICloudGateView.leaveGate()` solo desarma desde `.wipeFailed`, `.deviceWipeFailed`, «faltan cambios de
  grupos» y «no se pudo preguntar». Desde `.found`, `.confirmingWipe`, `.foundDevice` y `.confirmingDeviceWipe` sale
  con el arm tal cual. En el uso normal no importa: el arm se pone al entrar en `.wiping`. Tras un kill en `.wiping`,
  sí: el arranque lleva a la puerta con el arm puesto (`presentNextOnboardingScreen`) y la puerta vuelve a medir.
- «Soy nuevo → nube» (`onSelectCloudAccount`) no relanza ni pasa por un destino pendiente, así que nada retira el arm
  por ese camino. «Restaurar» sí lo retira (`onRestore` y `handleExistingOption`).
- `WelcomePrivateICloudGateLogic.lateWipeLaunch` devuelve `.resume` con arm en cualquier `storageMode`, y el modo nube
  cuenta como sesión privada: `runLateICloudMirrorCheck` corre `performICloudCorpusWipe(.handover)`.
  `LateICloudWipeLeftHalfwayLogicTests.launch` no fija esas filas a propósito.

## Qué hay que decidir

1. ¿`leaveGate` retira el arm desde cualquier fase (salvo `.wiping`, que no tiene «volver»)? La persona que vuelve
   atrás ha retirado su petición, igual que en un fallo. Ojo: si la zona ya se había ido en el intento cortado,
   `disarm()` lo recuerda.
2. ¿`lateWipeLaunch` deja de reanudar en `.cloud`? Tras el paso anterior sería un cinturón.

## Criterios de aceptación

- [ ] Volver desde cualquier fase de la puerta no deja un borrado armado.
- [ ] Ningún arranque en modo nube termina un borrado del iCloud privado sin preguntar.

## Relacionados

- [[private-gate-leave-after-a-halfway-wipe-forgets-the-zone]]
- [[late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed]]
