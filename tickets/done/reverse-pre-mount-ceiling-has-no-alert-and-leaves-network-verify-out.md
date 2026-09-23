---
id: reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out
status: done
updated: 2026-09-23
priority: low
area: "modo-nube, migración"
created: 2026-09-21
source: "review adversarial de `reverse-before-mount-has-no-way-to-abandon-the-return` (2026-09-21), lentes de la máquina, del runner y de las reglas de área"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - la alerta pide 15 min de espera; ReversePreMountExitLogicTests
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

- [x] Decidido lo de arriba antes de tocar código. — Jürgen, 2026-09-21: las dos cosas se hacen.
- [x] La alerta sale con el toque y con un re-kick, y NO se confunde con la nota de un intento anterior.
- [x] El verify se mueve: la IDA no cambia de comportamiento, con test que lo fije.

## Relacionado

- `reverse-before-mount-has-no-way-to-abandon-the-return` — el ticket que dejó estos dos residuales.
- `reverse-claim-rejection-has-no-way-out-in-the-client` — de donde sale el molde de la alerta.
- `forward-verify-reads-an-expired-session-as-network` — el gemelo del segundo punto, por el lado de la ida.

## Decisión Jürgen (2026-09-21)

**El techo avisa en el momento** (alerta al disparar, no silencio).

**verify + red entra al techo nuevo** — no quedan fuera del techo pre-montaje.

Listo para cola A cuando toque (serie; no adelantar a `abandoned-restore-no-longer-clears-the-session-window-clock`).



---

## Lo que se hizo (2026-09-21)

**Una.** La salida del techo ahora **avisa en el momento**. `MigrationRunner` deja un testigo en memoria,
`lastReversePreMountExit` (`ReversePreMountExit`, molde de `ReverseClaimExit` y de `ForwardClaimRefusal`), que escribe
`reportReversePreMountExit` **solo al dejar la etapa**: bajo presupuesto no hay salida, así que el re-kick de 30 s no
repite alerta mientras la vuelta sigue esperando. `CloudMigrationController.announceReversePreMountExit` compara la foto
tomada ANTES de llamar al runner, en `startReverse` (el toque) y en `resume` («Retomar» y el re-kick). La `sequence` es
lo que impide confundirla con la nota journaleada de un intento de días atrás.

**El término que no tiene el helper del claim:** el motivo pasa por `ReverseUploadWaitingCopyLogic.abortNote` antes de
traducirse. «Cancelar y seguir en la nube» vive también en estas cuatro fases y journalea `cancelled`, que
`L10n.Storage.ReverseAbort.note(for:)` agrupa con `stalled` — sin el filtro, cancelar a propósito sacaba una alerta de
error. El testigo se queda factual y quién lo enseña lo decide un solo sitio.

**Dos.** `reverseVerify` + red pura **entra al techo**. `driveReverseVerify` manda `.networkTimeout` a
`observeReversePreMountStall(blocker: nil)` ⇒ techo LARGO (72 h), como la red del drenaje y la del congelado. Era la
única de las ocho combinaciones fase × causa que quedaba fuera. En la VUELTA el único contador S9 vivo pasa a ser el del
mismatch, así que `reverseVerifyOutcome(.networkTimeout)` **dejó de ser un par legal** desde `reverseVerify`
(`.invalid`): dejar la rama viva sin emisor es código muerto que afirma lo contrario del ticket.

**La IDA no hizo falta separarla, y eso desmiente la premisa del encargo.** D10 dejó el verify fuera «para no arrastrar
a la IDA, que comparte `verify()`», pero `driveVerify` y `driveReverseVerify` son funciones distintas desde siempre y la
IDA ya agrupaba `.networkTimeout`, `.sessionExpired` y `.blocked` en su rama de red con el porqué escrito. Mover el
verify de la vuelta no toca una línea de la ida. Se fija con test en las dos capas en vez de tocar nada.

**Verificado:** build ×2, 208 unit en 3 suites, y **8 mutantes muertos** (el aviso quitado de `resume`; el filtro de
`cancelled` retirado; la foto tomada después de llamar al runner; la secuencia que no sube; el testigo anotado también
al holdear; la red de la vuelta devuelta al presupuesto; la red de la IDA dejando de gastarlo; y la rama muerta de la
máquina revivida). De paso, el entorno: los tres primeros veredictos salieron «no compila» y era **el disco** —24 Gi, por
debajo del umbral— tumbando el lanzamiento del simulador; se liberó DerivedData y se repitieron reformulados para que
compilaran.

---

## QA en iPhone

**Por qué en iPhone:** igual que su ticket padre, llegar a estas fases exige una cuenta en la nube de verdad y el
simulador no las crea sin el secreto de attest (`.claude/rules/gateway-attest.md`). **El techo de 72 h no se recorre a
mano**: lo fijan los unit tests con reloj inyectado. Aquí se ve la ALERTA —que es lo único que este ticket añade a la
pantalla— y que cancelar sigue sin sacarla.

**Montaje:** el mismo del ticket padre. Un iPhone de pruebas con un build que incluya este cambio (`Yala Dev` desde
Xcode, contra staging), con una cuenta en la nube y algunos movimientos. El id de la cuenta, en el SQL Editor de
Supabase (staging): `select id from auth.users where email = '<correo>';`, y apunta el estado de partida:
`select kind, reverted_at, migration_in_progress, reverse_in_progress, leader_device_id, reverse_frozen_at from public.profiles where id = '<id>';`

**Caso A · la alerta sale con el toque.** Monta un relevo de otro dispositivo, que dispara el techo CORTO (15 min):
`update public.profiles set leader_device_id = 'qa-otro-dispositivo', migration_updated_at = now() where id = '<id>';`

1. **Ajustes → «Dónde viven tus datos» → «Volver a iCloud»**, pasa las dos confirmaciones. La barra se para en el 62 %.
2. **Deja la app abierta 15 minutos**, con la pantalla de Almacenamiento delante. La pantalla se re-consulta cada 30 s,
   y ese re-kick es el que dispara el techo.
3. **Al vencer, sale una ALERTA encima**, no solo la nota: «No pudimos terminar de volver a iCloud: otro de tus
   dispositivos tomó el relevo. Cuando termine, podrás hacerlo en este.» **Antes de este cambio la barra desaparecía y
   la pantalla cambiaba sin decir nada.** Captura.
4. Ciérrala. Debajo, la tarjeta «Volver a iCloud» lleva la MISMA frase con su triángulo naranja: alerta y nota dicen lo
   mismo porque salen de una sola función.

**Caso B · la alerta no es la nota vieja.** Con la nota del caso A todavía en la tarjeta:

5. Deshaz el relevo: `update public.profiles set leader_device_id = '<el que apuntaste>', reverse_in_progress = false where id = '<id>';`
6. Toca «Volver a iCloud» otra vez y **deja que avance**. **No debe salir ninguna alerta** al tocar: la nota de hace un
   rato sigue en el journal, pero no hubo salida nueva. Ese es el criterio del ticket.

**Caso C · cancelar NO saca alerta.** Vuelve a montar el relevo del caso A y toca «Volver a iCloud».

7. Con la barra en el 62 %, toca «Cancelar y seguir en la nube» y confirma con «Sí, seguir en la nube».
8. La pantalla vuelve a «Tu cuenta en la nube» **sin ninguna alerta** y la tarjeta queda **sin nota**: lo decidiste tú.
   Si aquí sale un aviso de error, el filtro de `cancelled` se rompió.
9. Deshaz el relevo (paso 5).

**Caso D · sin cobertura, la vuelta espera en vez de fallar.** Lo que cambia la segunda mitad del ticket.

10. Toca «Volver a iCloud» y, **en cuanto la barra pase del 50 %** («Comprobando que todo llegó…»), pon el iPhone en
    **modo avión**.
11. Espera un par de minutos con la pantalla delante. La barra **se queda en el 50 %**. Captura.
12. **No debe aparecer nunca** la pantalla de «No pudimos volver a iCloud» con su botón de reintentar: antes de este
    cambio, ocho re-consultas sin cobertura —cuatro minutos— acababan ahí.
13. Quita el modo avión. La vuelta **sigue sola** desde donde estaba y termina en modo privado.

### Criterios de aceptación de QA

- [ ] Al vencer el techo sale una ALERTA en el momento, con la pantalla delante, y no solo la nota.
- [ ] La alerta y la nota de la tarjeta dicen exactamente lo mismo.
- [ ] Un intento NUEVO no saca la alerta por la nota de un intento anterior.
- [ ] «Cancelar y seguir en la nube» desde una fase previa al montaje no saca alerta ni deja nota.
- [ ] Sin cobertura en la verificación, la vuelta ESPERA y no cae a «No pudimos volver a iCloud».
- [ ] Al volver la cobertura, la vuelta continúa sola y termina en modo privado.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). La alerta pide 15 minutos de espera y el resto necesita SQL. Lo cubre `ReversePreMountExitLogicTests`.
