---
id: late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed
status: qa
priority: medium
area: "groups, modo-nube"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently` (2026-09-26)"
---

# Salir del aviso del espejo tardío tras un borrado fallido deja armada la reanudación a ciegas

## El problema

En `LateICloudMirrorNoticeView`, la fase `.failed` sale con «Dejarlo por ahora» (`dismiss()`) o con «Cerrar» en la
barra (`onKeep()` + `dismiss()`). Ninguna retira el arm (`StorageModePersistence.armICloudCorpusWipe`). En el arranque
siguiente, `ContentView.runLateICloudMirrorCheck` ve el arm y reanuda `performICloudCorpusWipe(.handover)` a ciegas,
sin pantalla. Borra la zona de iCloud, las filas personales y el dominio de Grupos, aunque la persona dijo «déjalo
así». El comentario de la fase promete lo contrario: «el aviso vuelve en el próximo arranque».

## Lo medido (2026-09-26)

Lo encontraron dos lentes de la review de `fresh-start-wipe-kills-unsent-group-writes-silently`, leyendo el código.
Ese ticket lo cerró para su fase nueva (`.groupsPending`), donde no se había borrado nada, así que desarmar era seguro.
En `.failed` NO lo es sin más: el fallo puede llegar después de borrar la zona, y el arm es lo que termina un borrado
a medias. Por eso no se tocó.

## Por dónde va

Distinguir el fallo antes de la zona del fallo después. Solo desarmar el primero, y en el segundo decirle a la
persona que el borrado quedó a medias en vez de reanudarlo en silencio.

## Arreglado (2026-09-26)

**Para quien usa la app:** si «Empezar de cero» desde el aviso de «Encontramos datos tuyos en iCloud» falla, salir ya no
deja el borrado pendiente para el próximo arranque. Si falló antes de tocar iCloud, no se borró nada y el aviso vuelve a
preguntar. Si falló después de borrar iCloud, la app lo dice —«El borrado quedó a medias»— y deja elegir entre terminar
de borrar o quedarse con lo que hay en el teléfono; si sales sin elegir, la pregunta vuelve al abrir la app. Nunca se
termina en silencio un borrado que la persona vio fallar. «Terminar de borrar» va en el botón rojo y pide un
«¿seguro?», porque la pantalla puede salir días después con datos nuevos en el teléfono.

- **Quien cruza la zona lo apunta**: `ContentView.performICloudCorpusWipe` escribe `cloudSync.icloudCorpusWipeZoneDone`
  justo tras borrarla. Es sub-estado del arm y muere con `clearICloudCorpusWipeArm`. No se deduce del motivo del fallo.
- `WelcomePrivateICloudGateLogic.classifyLateWipeFailure` (grupos pendientes · nada tocado · a medias) y `lateWipeLaunch`
  (reanudar · preguntar · nada). La marca «a medias» es `cloudSync.icloudCorpusWipeLeftHalfway`.
- La pantalla cambia el estado **al entrar en el fallo**, no al salir: botón, barra, deslizar o matar la app dan lo mismo.
- Fase nueva `.leftHalfway` con copy propio en 16 idiomas: el de `.failed` («Tus datos siguen en iCloud, intactos») era
  falso tras la zona. «Cerrar» en `.failed` pasa a ser «luego», como «Dejarlo por ahora» (antes retiraba el testigo).
- El arranque: arm → reanuda como siempre (un kill a mitad, nadie vio el fallo). Si esa reanudación falla tras la zona →
  «a medias» y la pregunta, no otro intento a ciegas. Sin arm y con «a medias» → la pregunta.
- «A medias» muere con la sesión (hook de cierre, junto al testigo del aviso) y con cualquier `wipeAllUserData`
  («Vaciar datos» incluido): la clave es `cloudSync.*` y el barrido de preferencias no la toca.
- `.groupsPending` conserva sus salidas, y además **desarma al entrar** (`disarmFailedICloudCorpusWipe`): un kill
  mirando esa pantalla reanudaba a ciegas. Si la zona ya se había ido, queda «a medias».

**La review adversarial (tres lentes) cambió cuatro cosas**: el cuerpo ya no promete «tus datos siguen aquí» (un borrado
local puede fallar a mitad), «Terminar de borrar» pasa por su «¿seguro?» y la salida que no borra va arriba, el desarme
de grupos pendientes al entrar, y «Vaciar datos» retirando la marca. Tres bajos van a tickets propios:
`groups-pending-screen-says-nothing-was-deleted-after-a-halfway-wipe`,
`late-icloud-sheet-buttons-may-leave-the-screen-at-large-dynamic-type` y
`finish-halfway-wipe-early-failure-shows-no-feedback`.

## Relacionado

- `late-icloud-wipe-can-re-export-between-its-two-halves`: un kill entre las dos mitades re-exporta lo local a iCloud.
  Por eso el copy de «a medias» dice «puede quedar todo o parte» y no promete el estado exacto.

**Verificado:** tests de lógica, marcas, «Vaciar datos» y cableado (`LateICloudWipeLeftHalfway*Tests`); suite unitaria
completa; mutantes y review adversarial (detalle en el PR).

## Device-QA (pendiente, no bloquea)

Solo se puede provocar el fallo de ANTES de la zona (sin red). El de después (`localWipeFailed`) no se puede forzar en un
iPhone: lo cubren los tests.

**Montaje**: en el Mac, trae `2.1` al día (`git pull`) y lanza `Yala Dev` desde Xcode en un iPhone de pruebas cuyo Apple ID
**ya tenga datos de Yala en iCloud** (de una instalación anterior). Borra Yala del iPhone antes de empezar.

1. Ajustes del iPhone → tu nombre → iCloud → apaga iCloud Drive (o cierra la sesión de iCloud). Abre Yala.
2. Elige **«Privado»** → sale «No pudimos revisar tu iCloud» → **«Seguir así»** → termina el onboarding.
3. Crea un par de movimientos.
4. Vuelve a activar iCloud en Ajustes y reabre Yala. **Esperado**: «Encontramos datos tuyos en iCloud».
5. Pulsa **«Empezar de cero»**. En la segunda pantalla («¿Seguro?…»), **antes de confirmar**, activa el **modo avión**
   desde el Centro de control. Ahora pulsa **«Vaciar definitivamente»**.
6. **Esperado**: «No pudimos borrar todo». Pulsa **«Dejarlo por ahora»**.
7. Cierra Yala del todo (desliza hacia arriba desde el selector de apps). Quita el modo avión. Abre Yala.
8. **PASS**: vuelve a salir «Encontramos datos tuyos en iCloud» y tus movimientos del paso 3 siguen ahí.
   **FAIL**: Yala te manda al inicio (onboarding) o tus movimientos desaparecen — es el borrado reanudado a ciegas.
9. Repite 5-7 pero sal con **«Cerrar»** (arriba a la derecha) en vez de «Dejarlo por ahora». Mismo PASS.

### Criterios de aceptación de QA

- [ ] Tras un fallo sin red y salir, el siguiente arranque vuelve a preguntar y no borra nada (botón y barra).
