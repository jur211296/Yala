---
id: activation-private-gate-leaves-a-late-notice-that-purges-groups
status: done
priority: medium
area: "groups, onboarding, modo-nube"
created: 2026-09-27
source: "review adversarial de `private-gate-leave-after-a-halfway-wipe-forgets-the-zone` (2026-09-27, lente de alcance); inferido por lectura, NO reproducido"
updated: 2026-09-28
qa-status: not-replicable
qa-date: 2026-09-28
qa-notes: barrido 2026-09-28 sin device-QA - activar sin red y esperar el aviso tardio es un caso raro; cubierto por ActivationLateNoticeKeepsGroupsTests
---

# Activar Yala completo sin poder mirar iCloud deja un aviso cuyo borrado se lleva los grupos

## El síntoma, en lenguaje de usuario

Estoy en solo-grupos y activo Yala completo → privado, sin red (o sin iCloud). La app me deja seguir, termino la
activación y conservo mis grupos. Días después, con iCloud funcionando, aparece «Encontramos datos tuyos en iCloud». Si
elijo borrarlos, el borrado se lleva también mis grupos: justo lo que la activación existía para conservar.

## Lo medido (2026-09-27, leyendo código)

- La puerta privada de la activación sale por `unverifiedExit: .proceedWatchingTheMirror`
  (`FullModeActivationView.swift`), así que `continueWithoutValidating` escribe el testigo del espejo tardío
  (`markPrivateChoseWithoutICloud`).
- `completeFullActivation` retira el arm, la marca «a medias» y el neutro solo-grupos, pero no ese testigo.
- Tras la activación la sesión es privada: `runLateICloudMirrorCheck` sondea y presenta `.corpus`, cuyo borrado es
  `performICloudCorpusWipe(.handover)` (dominio de Grupos incluido).
- La puerta de «Restaurar → Empezar desde cero» lo evitó a propósito con `.returnWithoutClaimingAWipe`; la privada no.
  Es el mismo criterio de `private-gate-leave-after-a-halfway-wipe-forgets-the-zone` por otra puerta.

## Qué hay que decidir

¿El aviso tardío de quien activó borra con otro alcance (`.importedRows`, sin purgar Grupos), o la activación no deja
el testigo y valida de otra forma? La primera conserva la validación aplazada; la segunda la pierde.

## Criterios de aceptación

- [x] Ningún aviso que vea quien activó Yala completo ofrece un borrado que purgue sus grupos.
- [x] La validación de iCloud que no se pudo hacer al activar sigue ocurriendo cuando se pueda.

## Relacionados

- [[private-gate-leave-after-a-halfway-wipe-forgets-the-zone]]
- [[activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable]]

## Decisión (2026-09-27, MODO AUTÓNOMO)

**Opción (a)**: el aviso de quien activó borra con `.importedRows` (zona de iCloud y lo personal del teléfono;
preferencias y grupos intactos). La (b) perdía la validación aplazada o la bloqueaba, y no poder preguntar a iCloud
jamás bloquea (ADR §9). El copy del aviso ya describe ese alcance: nombra registros, cuentas y presupuestos, no grupos.

**El alcance lo decide de dónde nació la sesión, no quién dejó el testigo.** `completeFullActivation` escribe
`PrivateSessionMark.markBornFromFullActivation()` antes de encender el eje, y la marca muere con el eje. Atarlo al
testigo no valía: el mismo aviso termina el borrado a medias de la puerta del Welcome, sin testigo y con su `.handover`.

## Qué cambia para el usuario

Quien activó Yala completo sin poder mirar iCloud sigue viendo «Encontramos datos tuyos en iCloud» cuando iCloud vuelve.
Si elige «Empezar de cero», se borran sus registros, cuentas y presupuestos (en iCloud y en el teléfono) y vuelve al
onboarding personal; **sus grupos se quedan**. Sus gastos y liquidaciones de grupo reaparecen en lo personal en el arranque siguiente.
Lo mismo vale para «Terminar de borrar» y para un borrado cortado por un kill que el arranque reanuda.

## Verificado

- Unit: `YalaTests/CloudSync/ActivationLateNoticeKeepsGroupsTests` (tabla, vida de la marca, grupos que sobreviven con
  control positivo, cableado) + los scans ajustados de `ActivationRestoreDiscardTests`,
  `WelcomePrivateICloudGateWiringTests` y `LateICloudWipeLeftHalfwayWiringTests`.
- Mutantes: 11/11 muertos (tabla, vida de la marca, marca ausente o detrás del eje, aviso y reanudación con `.handover` a mano, sin convergencia, sin liquidaciones, señales bajadas, condición invertida, Welcome sin retirar la marca).
- Gate: build de las dos schemes sin warnings nuevos; 8274 unit en 793 suites; 14 XCUITest (onboarding, Welcome,
  chooser de la activación), centinela solo.
- Review adversarial de tres lentes: alcance (sin caminos reales), después del borrado (las patas de las liquidaciones no
  volvían: arreglado aquí, y el mismo hueco en «Empezar desde cero» de la activación va a
  `activation-start-fresh-drops-group-settlement-legs`) y kill-safety/tests (un test que se ponía rojo, el `.handover`
  del Welcome a medias que el aviso habría terminado con `.importedRows`, y tres tests endurecidos).

## Guion de QA en iPhone (opcional; no bloquea)

Hace falta un Apple ID con datos viejos de Yala en iCloud y una sesión solo-grupos con al menos un grupo.

1. Con Yala en solo-grupos, activa el modo avión.
2. Grupos → «Activar Yala completo» → «Es mi primera vez» → privado. Debe salir «No pudimos revisar tu iCloud» →
   «Seguir así». Termina el onboarding.
3. Quita el modo avión y cierra Yala del todo (deslizar en el selector de apps). Ábrela.
4. Debe salir «Encontramos datos tuyos en iCloud». Toca «Empezar de cero» → «Borrar todos los datos».
5. **Comprueba**: vuelves al onboarding personal (no al Welcome), y en Grupos siguen tus grupos y sus saldos.
6. Termina el onboarding, cierra y abre Yala: los gastos de grupo vuelven a salir en Registros.

## Barrido de `qa` · 2026-09-28 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido semanal (encargo `2026-09-28-barrido-qa-in-qa-semanal`), con el criterio del 2026-09-23 (#224). Pide activar Yala completo en modo avión, con datos viejos en iCloud, y esperar el aviso tardío: un caso raro que el propio ticket marca como opcional. Lo cubre `ActivationLateNoticeKeepsGroupsTests` (11/11 mutantes).
