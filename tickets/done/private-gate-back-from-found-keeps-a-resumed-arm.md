---
id: private-gate-back-from-found-keeps-a-resumed-arm
status: done
updated: 2026-09-28
priority: medium
area: "onboarding, modo-nube"
created: 2026-09-27
source: "review adversarial de `private-gate-leave-after-a-halfway-wipe-forgets-the-zone` (2026-09-27, lente de estados durables); inferido por lectura, NO reproducido"
qa-status: absorbed
qa-date: 2026-09-28
qa-notes: barrido 2026-09-28 absorbed por welcome-private-fresh-start-skips-icloud-check - su no-regresion es el paso C4 del guion; el corte no se provoca a mano
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

- [x] Volver desde cualquier fase de la puerta no deja un borrado armado.
- [x] Ningún arranque en modo nube termina un borrado del iCloud privado sin preguntar.

## Relacionados

- [[private-gate-leave-after-a-halfway-wipe-forgets-the-zone]]
- [[late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed]]

## Resuelto (2026-09-27)

**Qué cambia para quien usa la app.**

- **Volver desde la puerta retira siempre el borrado pedido.** Da igual en qué pantalla esté: «Encontramos datos tuyos»,
  su «¿seguro?», el aviso de datos en el teléfono o un fallo. Quien vuelve atrás ha retirado su petición. Si el intento
  cortado ya había vaciado iCloud, la app lo recuerda como antes («El borrado quedó a medias»).
- **Una cuenta de la nube nunca termina un borrado del iCloud privado.** Si al arrancar en la nube queda uno pendiente, se
  retira sin borrar ni preguntar: lo del teléfono y los grupos ya son de esa cuenta.
- **La salida de siempre no cambia.** Volver desde «Encontramos datos» sin ningún borrado pendiente no toca nada.

**Qué se tocó.**

- `WelcomePrivateICloudGateView.leaveGate()`: desarma en todas las fases. Solo `.wiping` y `.wipingDevice` no tienen
  «volver», y esas son las únicas donde el arm debe sobrevivir. Salen los cuatro predicados que filtraban por fase.
- `StorageModePersistence` (`CloudSyncFlags.swift`): el neutro durable tiene dos dueños, el cierre de sesión y este
  borrado. Una marca nueva (`cloudSync.icloudCorpusWipeOwnsNeutralMount`) dice si lo armó el borrado, y
  `clearICloudCorpusWipeArm` solo retira el suyo. Sin eso, volver desde «Encontramos datos» tras un kill en el Welcome de
  un dispositivo recién vaciado se llevaba el neutro del cierre de sesión, y el arranque siguiente montaba el espejo.
- `WelcomePrivateICloudGateLogic.lateWipeLaunch`: la nube se mira primero. `.retireLeftHalfway` pasa a `.retireInCloud` y
  cubre arm y «a medias».
- `ContentView.runLateICloudMirrorCheck`: `.retireInCloud` retira el arm (con su marca de zona) y la marca «a medias».

**Decisiones asumidas** (encargo autónomo, opción robusta):

- Punto 1 y punto 2 los dos, no uno. El cinturón en la nube no es redundante: la puerta no es el único que arma. El
  arranque deja el arm puesto tras un fallo `.untouched` para reintentar (medido en `runLateICloudMirrorCheck`), y una
  migración a la nube entre dos arranques lo llevaría hasta ahí (inferido, no recorrido).
- En la nube se **retira** el arm y no se pregunta. En la nube no hay espejo que ofrecer ni corpus privado que describir.
- La propiedad del neutro entra en este PR porque el punto 1 extiende a cinco fases más un desarme que se lo llevaba.
  **El parque:** un dispositivo que actualice con un borrado ya armado no tiene la marca nueva, así que desarmarlo deja
  el neutro puesto hasta que el Welcome lo inhabilite. Se prefirió eso a llevarse el del cierre de sesión.

**Verificado.** Suites de la puerta, el aviso tardío, «Empezar de cero» y la activación. Mutantes muertos: sin desarmar
en `leaveGate`, filtrar por fase otra vez, la nube sin retirar el arm y la nube reanudando. Review adversarial de tres
lentes: un medio aplicado (el neutro del cierre de sesión), un hueco de test cerrado (el «volver» oculto en `.wiping`,
que ahora es la única red) y dos preexistentes a backlog.

**Fuera de alcance, en backlog.**

- `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`: un borrado del aviso tardío que espera al
  import y una migración a la nube entre dos arranques. Ahora se retira sin avisar (antes se ejecutaba sobre la cuenta).
- `cloudsync-witnesses-survive-the-sign-out-wipe`: instancia medida añadida, el arm sobrevive al cierre de sesión.
- Sin ticket, gravedad baja: «Restaurar» en la puerta de la activación no retira el arm (lo retiran el arranque y
  `completeFullActivation`); el Welcome con destino pendiente retira el arm a secas y olvida la zona (es la decisión de
  #278: «Restaurar» elige quedarse con lo que hay).

## Guion de device-QA (opcional)

El corte a mitad del borrado **no se puede provocar a mano** con fiabilidad. Lo que se puede mirar es que el camino de
siempre no cambió:

1. iPhone con datos de Yala en iCloud. Borra la app e instálala desde TestFlight.
2. Abre Yala → «Es mi primera vez» → «Privado». Sale «Encontramos datos tuyos en iCloud».
3. Toca la flecha de volver. Esperado: vuelves a la elección privado / nube.
4. Elige otra vez «Privado». Esperado: vuelve a salir «Encontramos datos tuyos en iCloud». Nada se borró.
5. Toca «Traer mis datos». Esperado: se restauran como siempre.

## Barrido de `qa` · 2026-09-28 · absorbido

Sale de la cola de device-QA por el barrido semanal (encargo `2026-09-28-barrido-qa-in-qa-semanal`), con el criterio del 2026-09-23 (#224). El corte a mitad del borrado no se provoca a mano, y su guion de no-regresión (volver desde «Encontramos datos tuyos» y ver las mismas cifras) es el paso C4 del guion, que recorre `welcome-private-fresh-start-skips-icloud-check`. Lo cubre `LateICloudWipeLeftHalfwayLogicTests`.
