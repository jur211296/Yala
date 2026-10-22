---
id: late-notice-witness-survives-a-welcome-restore-over-device-data
status: backlog
priority: low
area: "onboarding, modo-nube, groups"
created: 2026-09-27
updated: 2026-10-08
source: "Paso 0 de `late-notice-of-a-welcome-private-session-purges-groups-joined-later` (2026-09-27); inferido por lectura, NO reproducido"
---

# El testigo del espejo tardío sobrevive a «Restaurar» en el Welcome

## El síntoma, en lenguaje de usuario

Abro Yala en un teléfono que ya tiene datos (de otra persona, o míos de antes) y elijo «Es mi primera vez → privado» sin
iCloud. La app me deja seguir, me avisa de que hay datos en el teléfono y cancelo. De vuelta en el Welcome elijo
«Restaurar». Días después, con iCloud, me sale «Encontramos datos tuyos en iCloud», y su «Empezar de cero» deja en el
teléfono los grupos que ya estaban antes de empezar.

## Lo medido (2026-09-27, leyendo código)

- El testigo (`StorageModePersistence.markPrivateChoseWithoutICloud`) lo escribe `continueWithoutValidating` antes de salir
  hacia el onboarding privado. Con el espejo ya montado la puerta no mide el teléfono (`deviceCorpusGate` es `nil`).
- `startFreshPrivateOnboarding` encuentra datos y enseña el alert; «Cancelar» devuelve al chooser **con el testigo puesto**.
- Solo cuatro sitios lo retiran (los tres desenlaces del aviso y la reanudación), y ninguno está en «Restaurar».
- Desde `late-notice-of-a-welcome-private-session-purges-groups-joined-later`, «Empezar de cero» del aviso es
  `.importedRows`: la premisa es que todo grupo del teléfono es de la persona de la sesión, y en este rincón no lo es
  necesariamente. Antes el `.handover` los purgaba por accidente.

## Qué hay que decidir

Si el testigo debe retirarse al cancelar el alert (la persona no siguió adelante por esa puerta) o al entrar por
«Restaurar» (ahí no hay validación aplazada: restaurar ES traerse el iCloud).

## Criterios de aceptación

- [ ] Quien sale del Welcome por un camino que no es el onboarding privado no se lleva el testigo del espejo tardío.
- [ ] El testigo de quien sí sigue al onboarding privado sin iCloud no se pierde.

## Relacionados

- [[late-notice-of-a-welcome-private-session-purges-groups-joined-later]]

## Medido en 2.1 (triage 2026-10-08)

- El testigo lo escribe `WelcomePrivateICloudGateView` y lo retiran cuatro sitios: `onKeep` de la hoja, el éxito del borrado tardío, `.standDown` de `runLateICloudMirrorCheck` y `LateICloudMirrorNoticeView`. Ninguno está en Restaurar ni en el «Cancelar» del alert de `startFreshPrivateOnboarding`.
- Decisión pendiente. A) retirarlo al cancelar el alert, porque la persona no siguió por esa puerta y, si vuelve a elegir privado, `continueWithoutValidating` lo escribe otra vez; B) retirarlo al entrar por Restaurar. Recomendada: A, porque cubre Restaurar y cualquier otra salida posterior con un solo punto. Con A sigue en `low`.

Triage 2026-10-08: abierto · low → low · `markPrivateChoseWithoutICloud` lo sigue escribiendo solo `WelcomePrivateICloudGateView`, y solo lo retiran el aviso tardío (×3) y su hoja; Restaurar y el «Cancelar» del alert no lo tocan.
