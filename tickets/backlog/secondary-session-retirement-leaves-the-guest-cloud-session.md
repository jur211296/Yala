---
id: secondary-session-retirement-leaves-the-guest-cloud-session
status: backlog
priority: low
area: "sesiones, nube, keychain"
created: 2026-09-13
source: "review adversarial del PR-B del paso 12 (`shell-derives-from-two-session-axes`), lente «lo que queda en disco» · F3"
---

# La retirada de la sesión de visita no cierra la sesión de nube que la visita dejó

## Qué queda vivo

`SecondarySessionRetirement.purgeIfNeeded` limpia lo que la visita dejó **en el contenedor de la app**:
los tres stores `*-Secondary`, sus cuatro keys `cloudSync.secondary*`, las dos keys de modo de onboarding
y los cajones `yala.session.*`. Lo que **no** toca es el Keychain.

Y el Keychain no está particionado por sesión: `CloudAuthKeychainStorage` usa un único
`kSecAttrService = "com.yala.cloudauth"` para todo el proceso (medido). Así que si la persona invitada
llegó a firmar con su cuenta durante la visita, su JWT sigue ahí después de la retirada: el arranque
siguiente del dueño corre con **la sesión de nube de la otra persona**, y desde ahí el canal de Grupos
sube y baja firmado como ella.

## Por qué es `low` y no `high`

**La población es de desarrollo, y eso está medido, no supuesto.** En Release la entrada a la visita era
constante `false`: `secondarySessionCompiledDefault` está en `false` desde el 12-sep y el percent remoto
de producción estaba en `0` con el default fail-closed, así que **nadie en producción pudo abrir nunca una
sesión de visita** — es la misma premisa que hizo barato el PR-B entero. Quedan los teléfonos de QA y las
builds Dev/staging donde el flag sí estuvo encendido a mano.

Añadido a eso: la retirada corre **una vez**, en el arranque, y su marca ya se habrá escrito en esos
teléfonos cuando alguien lea este ticket. O sea que el arreglo no es «añadir un paso a la retirada» sin
más — habría que decidir si se re-abre la marca o si se limpia a mano.

## Opciones

- **A — limpiar a mano los teléfonos de QA** (`Ajustes → Yala → cerrar sesión`, o reinstalar). Es lo
  barato y probablemente lo correcto dado el alcance.
- **B — un segundo one-shot** con su propia `doneKey`, que cierre la sesión de nube si el teléfono trae
  huella de visita. Cuesta más de lo que vale salvo que aparezca un caso real.

## Criterio de aceptación

- [ ] Decidido A o B, escrito en el ticket, y el docblock de `SecondarySessionRetirement` deja de
      implicar que la retirada devuelve el teléfono al estado del dueño **por completo**: hoy alcanza al
      contenedor, no al Keychain.
