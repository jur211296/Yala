---
id: welcome-beacon-reads-owner-icloud-in-secondary
status: discarded
priority: medium
area: modo-nube
created: 2026-09-07
updated: 2026-09-09
---

# El faro de «Soy nuevo» lee el iCloud del DUEÑO, también cuando quien elige es la visita

Why: Discarded 2026-09-09. Superado por el ADR 2026-09-09 «Sesiones — dos ejes» (docs/DECISIONS.md): la sesión de visita (M1) se retira del modelo. Sin sesión de visita, quien elige en el Welcome es siempre el dueño del Apple ID; y el faro pasa a solo encaminar (`beacon-routes-only-never-blocks`).

## Qué se midió, y qué NO

**Medido (2026-09-07, sobre `ed82e044`):** `CloudBeacon` lee y escribe en el iCloud key-value del
Apple ID del **dispositivo** (`Yala/Services/CloudSync/CloudBeacon.swift:85-86`), y **no contiene ni
una referencia a la sesión secundaria** — ni a `SecondarySessionStore`, ni a `SessionDefaults`
(comprobado por grep sobre el fichero entero). En el móvil del dueño, ese faro es el del dueño.

Y el faro **decide antes que nada** en la rama «Soy nuevo»
(`WelcomeAccountChoiceLogic.routeNewBranch:109`):

```
if beaconLinked && cloudEntryAvailable {
    return .cloudSignIn(...)     // ← antes del bypass y antes del sub-chooser
}
```

⇒ Con el dueño teniendo cuenta nube vinculada y la entrada de nube disponible, la visita que elige
«Es mi primera vez» **no llega a la rama privada**: se la encamina al sign-in de nube con el
provider del faro del dueño.

**NO medido, y es lo que hay que medir antes de llamarlo bug:** qué le pasa a la visita al aterrizar
ahí. `WelcomeCloudSignInView` tiene guard cross-cuenta y `SecondarySlotOccupancyLogic`, y la visita
**ya tiene sesión** (es lo que la hizo secundaria), así que el slot está ocupado por ella misma.
Es perfectamente posible que el destino la encauce bien y no haya nada que arreglar. También es
posible que le pida re-entrar a una cuenta que no es la suya.

## Por qué salió esto, y cuánta pantalla se pierde

Al construir la pantalla de aviso de la rama privada
([[welcome-privacy-branch-has-no-secondary-door]]) hubo que comprobar que la rama es **alcanzable**:
si el faro desviara siempre, la pantalla nueva sería decorativa.

**Es alcanzable, pero no siempre, y el reparto importa** (corregido el 2026-09-07 tras medirlo — la
primera versión de este ticket decía que la entrada de nube apagada salvaba la rama, y eso es falso:
`CloudSyncFlags.secondarySessionEntryAvailable` **exige** `CloudRemoteFlags.cloudModeEnabled`, así que
sin modo nube no se puede *crear* una sesión secundaria; solo sobrevive una ya activa cuando el kill
llega después):

| Dueño del teléfono | ¿Se ve el aviso? |
|---|---|
| Usuario de iCloud **sin** cuenta nube (faro sin `linked`) | **Sí** — y es el caso probablemente mayoritario |
| Usuario **de nube** (faro `linked`) | **No**: el faro encamina al sign-in antes de `handleNewOption` |

⇒ la pantalla **falta justo donde más importa**: la visita en el móvil de otro usuario de nube. Eso
no es un defecto del cambio del 7-sep —el `if` está en su sitio; lo que pasa por delante es
anterior— pero sí es la mitad del hueco que sigue abierta.

## Criterio de hecho

- [ ] Reproducir en simulador: descriptor secundario vivo + faro `linked` + entrada de nube
      disponible, y **ver dónde aterriza la visita**. El panel DEBUG de `CloudSyncDebugView` tiene
      las tres palancas.
- [ ] Si aterriza bien: dejarlo escrito en el docblock de `routeNewBranch`, que hoy no dice nada de
      la sesión secundaria, y cerrar.
- [ ] Si no: decidir si el faro se lee o no en sesión secundaria — que es una decisión con dos
      lados, porque el faro también sirve para no ofrecerle a un 2º device una elección que ya está
      tomada.

## Relacionados

- [[welcome-privacy-branch-has-no-secondary-door]] — de ahí salió la medición
- [[welcome-private-card-promises-icloud-in-visit]] — el otro residual del mismo sub-chooser


## Dos más del mismo sub-chooser, encontrados a la vez

Los dejo aquí y no en tickets sueltos porque comparten el objeto —qué se le ofrece a la visita en el
chooser— y probablemente comparten decisión:

1. **`case .cloudAccount` de `handleNewOption` no está gateado.** Con el percent > 0, la visita puede
   tapear «cuenta en la nube» y arrancar un alta born-cloud con el slot secundario ya ocupado por
   ella misma. La asimetría entre las dos ramas que el 7-sep quitó del nivel 1 sigue viva **dentro**
   del nivel 2.
2. **Desde el chooser, la visita puede restaurar del iCloud del DUEÑO.** «Ya tengo una cuenta» →
   bypass → `.restoreICloud` sobre su store secundario. Es anterior a todo esto, pero el «volver» de
   la pantalla nueva lo deja a un toque.
