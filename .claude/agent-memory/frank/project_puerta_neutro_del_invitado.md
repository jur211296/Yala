---
name: puerta-neutro-del-invitado
description: Ticket 1 de la cola autónoma, PR #143 — la invitación sobre un teléfono espejado; la review cazó 23 defectos MÍOS y cuatro dejaban el arreglo sin funcionar; device-QA NO simulable.
metadata:
  type: project
---

Aceptar una invitación de grupo en un teléfono que ya espeja el iCloud de otra persona ya no manda
los gastos del invitado a ese iCloud. PR **#143**, sobre la mitad 2 (#139).

**Why:** era el hueco que la mitad 2 dejó abierta a propósito —cerró «Crear mi primer grupo», no la
invitación— y el daño es invisible: sin error, sin aviso, y se ve en el otro dispositivo del dueño
días después.

**How to apply:**

- **La puerta del invitado NO es la del organizador, y confundirlas es el error caro.** Le falta un
  término que aquella no necesita («¿hay sesión privada viva?»): la del organizador vive DENTRO del
  Welcome y el sitio le garantiza el contexto; ésta corre desde `drive`, al que llama el reconciler
  en `.boot`, o sea en cualquier estado. Sin ese término le vacía el teléfono al DUEÑO, contra la
  fila `C · llega una invitación` de la matriz del ADR.
- **Aquí se pregunta, al revés que en la rama de crear**, y la razón es la que hay que recordar: allí
  la persona acaba de tapear una card, aquí puede no haber ningún gesto detrás. Registrado como
  decisión propia en el Paso 0 del ticket — si Jürgen la revisa, ése es el sitio.
- **Device-QA NO simulable**: dos Apple IDs y un tercer dispositivo testigo
  (`tickets/qa/device-qa-groups-invite-neutral-return.md`, 7 recorridos).
- Deja dos tickets: `welcome-chooser-uitests-cannot-reach-the-chooser` (**high**, 7 XCUITest rojos
  preexistentes en `2.1`, bisecados) y `groups-invite-neutral-gate-has-no-way-out-when-the-exit-cell-cannot-wipe`.

**Lo que costó la review** (3 lentes + la regla de área): **23 hallazgos, todos míos**, y cuatro
dejaban el arreglo sin funcionar o peor que antes — ver
[[el-reparador-tan-reejecutable-como-el-destructor]] y [[el-estado-paralelo-al-lado-del-step]]. El
peor: **la pantalla no se renderizaba en su propio estado objetivo**, porque el drain baja el cover
del Welcome y el consumidor lo sube en la MISMA vuelta síncrona ⇒ SwiftUI no renderiza entre dos
escrituras de `@State`, el cover no se desmonta y el `initialStep` se ignora. Era un agujero
GENERAL del container, no mío: hasta ese día, cualquier productor que escribiera el step con el
cover montado era ignorado en silencio.
