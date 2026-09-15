---
id: apple-id-close-notice-does-not-say-what-else-the-close-does
status: backlog
priority: medium
area: "modo-nube, sesiones, copy"
created: 2026-09-15
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

- [ ] Cuando el cierre se lleva grupos del teléfono (D, y C con grupos del canal nuevo), la persona lo sabe
      antes de confirmar.
- [ ] Nada de lo que dice la hoja es falso para la celda C ni para la D.
