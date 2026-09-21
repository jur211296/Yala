---
id: reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out
status: backlog
updated: 2026-09-21
priority: low
area: "modo-nube, migración"
created: 2026-09-21
source: "review adversarial de `reverse-before-mount-has-no-way-to-abandon-the-return` (2026-09-21), lentes de la máquina, del runner y de las reglas de área"
---

# Al techo de «Volver a iCloud» le faltan dos cosas: avisar en el momento y cubrir la verificación sin red

## El problema, en lenguaje de usuario

**Uno.** Estoy mirando cómo vuelve a iCloud, la barra desaparece de golpe y la pantalla cambia. En algún sitio hay
una nota que explica por qué, pero nadie me la pone delante: tengo que darme cuenta yo. Y si hace tres días hubo
otro intento fallido, la nota que veo puede ser aquella.

**Dos.** Si el paso de verificación se queda sin cobertura una y otra vez, la vuelta no sale por el camino nuevo
—el que devuelve a la nube limpiamente— sino por el viejo: se declara fallida y deja el aviso al servidor
pendiente hasta que la red vuelva.

## Por qué pasa (medido el 2026-09-21, al implementar el techo)

1. **No hay alerta.** El techo journalea `reverseAbortReasonRaw` con `journalReversePreMountStep`, que es un clon de
   `journalReverseClaimExit` **menos** `recordReverseClaimExit`. Sin esa secuencia en memoria,
   `CloudMigrationController.announceReverseClaimExit` no tiene nada que comparar, y la regla del área
   (`.claude/rules/swiftdata-cloudkit.md`, `reverse-claim-rejection-has-no-way-out-in-the-client`, punto 4) dice por
   qué existe esa comparación: **el campo journaleado no distingue una salida de ahora de la nota de un intento
   anterior**. El techo reintroduce esa ambigüedad justo donde el ticket hermano la había cerrado.

2. **`reverseVerify` + red pura se queda fuera del techo**, por la decisión D10 de ese ticket: ese camino ya tiene su
   propio presupuesto (`MigrationPolicy.maxNetworkRetries = 8`) y al agotarlo degrada a `reverseFailedRollback` con
   `.reverseRollback` pendiente. Se dejó fuera para no arrastrar a la IDA, que comparte `verify()`. **Sigue teniendo
   salida** —no es el limbo del ticket padre— pero es la peor de las dos: un terminal que exige un toque en vez de
   devolver el teléfono a sincronizar solo. El techo cubre 7 de las 8 combinaciones fase × causa.

## Qué habría que decidir

- **Si la salida del techo avisa en el momento.** El molde existe entero (`ReverseClaimExit` + `announce…`), y el
  coste es un tipo en memoria más. En contra: la persona que no está mirando —que es para quien existe el techo— se
  encuentra la nota igual, y una alerta más en esa pantalla compite con las otras dos.
- **Si `reverseVerify` + red pura pasa al techo nuevo**, lo que obliga a separar el trato de la IDA en `verify()`.

## Criterios de aceptación

- [ ] Decidido lo de arriba antes de tocar código.
- [ ] Si se hace la alerta: sale con el toque y con un re-kick, y NO se confunde con la nota de un intento anterior.
- [ ] Si se mueve el verify: la IDA no cambia de comportamiento, con test que lo fije.

## Relacionado

- `reverse-before-mount-has-no-way-to-abandon-the-return` — el ticket que dejó estos dos residuales.
- `reverse-claim-rejection-has-no-way-out-in-the-client` — de donde sale el molde de la alerta.
- `forward-verify-reads-an-expired-session-as-network` — el gemelo del segundo punto, por el lado de la ida.
