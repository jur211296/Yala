---
id: apple-id-close-notice-does-not-say-what-else-the-close-does
status: done
priority: medium
area: "modo-nube, sesiones, copy"
created: 2026-09-15
updated: 2026-09-29
source: "hallazgo de la review de #159 que viajaba dentro de `apple-id-close-blocked-has-no-visible-outcome`; se separa al cerrar aquel (2026-09-15)"
---

# El aviso del cambio de Apple ID no dice todo lo que hace el cierre

## Qué pasa

La hoja «Cambiaste de cuenta de iCloud» dice que los datos de Yala de este teléfono son de la cuenta de
iCloud anterior, que ahí se quedan guardados y que hay que quitarlos de aquí. **El cierre hace más que
eso, y no lo cuenta:**

- Cierra la sesión de la cuenta de Yala si la hay: `CloudAuthService.signOut()` corre en los dos caminos
  (`CloudSessionSignOut.finalizeSessionExit`).
- En la celda D (sesión privada + cuenta de grupos) olvida el consentimiento de Grupos
  (`GroupsConsentState.clear()`) y **borra los grupos del teléfono** después de subirlos
  (`markSignOutWipeIncludesGroups`).
- En la celda C también los borra si quedan grupos del canal nuevo en el teléfono, p. ej. de una sesión de
  grupos que caducó: `forgetsGroups = kind.pushesGroups || hasBackendGroupRows`
  (`CloudSessionSignOut.armAfterCredentials`). Ajustes ya lo cuenta en su hoja
  (`DestructiveScopeLogic.signOutOperation(forgetsBackendGroups:)`).

Ajustes tiene una pieza que lo cuenta por celda —`DestructiveScopeLogic.signOutOperation`, la hoja de
alcance con sus filas 📱/☁️/👥— y este camino no la usa.

## Por qué no entró en el ticket que arregló el bloqueo

Ninguna variante de esa hoja dice la verdad de este cierre (medido el 2026-09-15):

- «Con copia en iCloud» promete esperar a que lo último llegue a iCloud, y este cierre NO espera: la
  cuenta de destino ya no está (`confirmedWithoutICloudCopy: true`).
- «Sin copia» afirma que no hay copia en ninguna parte, y sí la hay: en el iCloud de la cuenta anterior.

Traerla pide copy nuevo en 16 idiomas y una decisión de producto: qué se le cuenta a alguien que quizá
ni es el dueño de los datos, porque el teléfono puede haber cambiado de manos. No era criterio de aquel
ticket.

## Lo que hay que decidir

1. ¿La hoja del cambio de Apple ID enseña el alcance por celda, o basta con una frase más en el mensaje?
2. Si es el alcance por celda, ¿una operación nueva en `DestructiveScopeLogic`, con sus filas propias?

**Recomendación:** una frase más en el mensaje, solo cuando el cierre se lleva grupos del teléfono: en la
celda D siempre, y en la C cuando queden grupos del canal nuevo, con la misma pregunta que ya se hace
Ajustes. Por ejemplo: «También se quitan de este teléfono tus grupos; siguen en el servidor». La hoja de
alcance completa sirve a quien decide cerrar desde Ajustes. Aquí el cierre lo provoca un cambio de cuenta, y
la pregunta es una sola.

## Criterios de aceptación

- [x] Cuando el cierre se lleva grupos del teléfono (D, y C con grupos del canal nuevo), la persona lo sabe
      antes de confirmar.
- [x] Nada de lo que dice la hoja es falso para la celda C ni para la D.

## Resolución (2026-09-29)

Decidido: una frase más, sin la hoja de alcance (la recomendación de arriba). Cuando el cierre se lleva los grupos,
la pregunta añade en párrafo propio **«También se quitan los grupos que hay en este teléfono.»** En los demás casos el mensaje es el de siempre.

**La frase no dice dónde siguen los grupos, y es a propósito** (review adversarial del 2026-09-29). La primera versión
decía «siguen en tu cuenta de Yala», como Ajustes. En la celda C eso no siempre es cierto: las filas del canal nuevo
pueden ser de una cuenta de grupos borrada, o de otra persona (el bloqueo `groupsChangesFromAnotherAccount`). Y esta
hoja la puede leer alguien que no es el dueño, porque el teléfono pudo cambiar de manos: por eso el mensaje de siempre
tampoco dice «tus datos». «Siguen en el servidor», el ejemplo del ticket, cae por lo mismo y además choca con el
«sin servidores» de la marca.

- **Una sola regla para el cierre y para la hoja**: la fórmula del arm pasa a `CloudSignOutFlowLogic.wipeForgetsGroups`
  (`(sube grupos || filas del canal nuevo) && canal compilado`). La hoja la llama con la celda de ahora, leída con los
  mismos getters que el tap (`AppleIDCloseNoticeView.currentCell`). Si la hoja copiara la fórmula, divergirían.
- `hasBackendGroupRows` falla hacia `true` ante un error de lectura, y el cierre también borra entonces: la frase dice
  lo que pasa.
- Tests: `CloudSignOutFlowLogicTests.wipeForgetsGroupsTable` (3 × 2 × 2), `AppleIDCloseNoticeGroupsLineTests` (D siempre,
  C con y sin filas, sin canal compilado, E y F), `AppleIDCloseNoticeWiringTests` (la hoja y el arm usan la regla
  compartida) y `AppleIDCloseNoticeUITests`: la frase sale con `seed: grupos` (celda C con grupos del canal nuevo) y
  no sale con `minimal`.
- La celda D en un iPhone real va como paso del device-QA del cambio de Apple ID
  (`tickets/qa/device-qa-apple-id-change-closes-private-session.md`, recorrido 1, paso 4).
