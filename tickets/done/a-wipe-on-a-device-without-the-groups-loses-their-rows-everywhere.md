---
id: a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere
status: done
priority: medium
area: "groups, sync"
created: 2026-09-28
updated: 2026-09-28
source: "review adversarial de `late-remote-wipe-signal-also-wipes-rows-created-after-it` (lentes de grupos y de sync, 2026-09-28); inferido leyendo código, NO reproducido"
qa-status: not-replicable
qa-date: 2026-09-28
qa-notes: barrido 2026-09-28 sin device-QA - pide iPhone y iPad con el mismo Apple ID; cubierto por GroupsRemoteWipeDivisionTests y GroupsBridgeRestoreConvergenceTests
---

# «Vaciar datos» en un dispositivo sin los grupos deja al resto sin los gastos de grupo

## El síntoma, en lenguaje de usuario

Uso los grupos en el iPhone. En el iPad, que nunca entró en Grupos, pulso «Vaciar datos» para empezar de nuevo. En el
iPhone desaparecen de mis cuentas los gastos y las liquidaciones de grupo, y no vuelven.

## Lo medido (2026-09-28, leyendo código)

- «Vaciar datos» borra toda `TransactionItem`, también las que el bridge puso en lo personal, y pide la convergencia
  para reponerlas (`DataWipeService.wipePersonalDataKeepingGroups`). La convergencia re-puentea desde el store LOCAL de
  Grupos (`GroupsBridgeRestoreConvergence.convergeIfPending`), que no viaja por iCloud (`cloudKitDatabase: .none`).
- Un origen que no tiene esos grupos —nunca entró, o tiene el canal parado— converge sobre nada. Su borrado viaja por
  el espejo al iPhone.
- El iPhone recibe la señal. Si la procesa ANTES de que haya nada de grupo posterior a la señal (el orden normal), no
  pide la convergencia (`remoteWipeTakesRowsTheOriginReconverged` sale `false`): lo que se lleva lo da por repuesto por
  el origen, que no lo va a reponer.
- En el orden tardío sí lo cubre: con una fila de grupo posterior, el receptor pide su convergencia y re-puentea sus
  grupos (desde el 2026-09-27, mantenido el 2026-09-28).

Es el espejo de `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows` (el RECEPTOR sin grupos).

## Qué hay que decidir

Quién sabe que el origen no tiene esos grupos. Una salida: el origen escribe en la señal si su convergencia puede
reponer (tiene grupos y el canal vivo), y el receptor con grupos pide la suya cuando el origen dice que no. Pedir
siempre ya se descartó el 27-sep: dos convergencias que se cruzan antes que el espejo duplican.

## Relacionados

- [[late-remote-wipe-signal-also-wipes-rows-created-after-it]]
- [[late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows]]
- [[wipe-data-keeps-groups-but-drops-their-bridged-rows]]

## Decisión (Frank, 2026-09-28, en el encargo)

El origen no declara un sí/no: declara QUÉ repone, y el receptor repone el resto. Un booleano no cubría al origen con una
parte de los grupos ni el gasto que el origen aún no conocía al vaciar.

## Qué cambia para el usuario

Uso Grupos en el iPhone y vacío mis datos en el iPad, que nunca entró en Grupos. En el iPhone los gastos y liquidaciones
de grupo desaparecen un momento de mis cuentas y vuelven, una vez, al cerrar y abrir la app (en el flujo típico, al
segundo arranque en frío), con el Inbox preguntando de qué cuenta salió cada gasto. Si el iPad tenía los mismos grupos, los
repone él y el iPhone no, sin copias dobles. Si tenía una parte, cada uno repone lo suyo.

## Qué se hizo

- **El origen escribe el reparto.** «Vaciar datos», cuando avisa a los demás dispositivos, escribe en el iCloud-KV
  (`groupsWipeDivision`) la hora de la señal y los gastos y liquidaciones que su convergencia repone, con los filtros de
  ella. Sin grupos, o con el dominio cerrado, va vacío. La señal sale con la misma hora (`GroupsRemoteWipeDivision.declare`,
  `PreferenceSyncService.signalWipeInitiated(at:)`).
- **El receptor del orden normal espera el reparto.** Antes de borrar apunta la señal que procesa
  (`GroupsRemoteWipeDivision.awaitOrigin`). En el arranque, justo antes de la convergencia, lo resuelve: con el reparto de
  esa señal pide su convergencia sin esos ids, con las liquidaciones; sin él, espera, y a los 30 días lo suelta
  (`resolveIfArrived`).
- **La convergencia tiene alcance.** `GroupsBridgeRestoreConvergenceStore.markPending(excluding:)` guarda qué no repone; la
  convergencia salta esos gastos y esas liquidaciones. Una petición entera gana siempre, y una con reparto nuevo sustituye a
  la vieja.
- **El orden tardío no cambia** (#284/#289): pide la convergencia entera. El mecanismo de declaraciones del 27-sep tampoco.

## Verificado

- Unit: el ticket (origen sin grupos → el receptor repone, una vez; control sin reparto: espera y no pide), origen con los
  mismos grupos (el receptor no repone nada suyo), origen con una parte (repone solo el resto), orden tardío (entera, suelta
  la espera), la espera sobrevive al reset de preferencias en `.standard`, los filtros del reparto del origen, el formato del
  KV con un JSON literal, el plazo y sus vecinos, el alcance (entera gana, sustitución, ilegible = entera, `clear`, relevo)
  y cuatro scans de cableado.
- Review adversarial de tres lentes (sync, grupos/dinero, tests), ninguna con hallazgo alto. Cambió dos cosas: con una
  entera puesta el reparto ya no pide las liquidaciones (la de restaurar las deja fuera a propósito) y dos repartos se
  sustituyen en vez de intersecarse. El resto, a ticket o a la cabecera de `GroupsRemoteWipeDivision.swift`.
- Mutantes: 31/31 muertos (el reparto, la espera, el alcance, el arranque, el formato del KV, el plazo, los filtros y el
  cableado).
- Gate: builds Yala y Yala Dev sin warnings nuevos, `YalaTests` entero (8392 tests en 799 suites) en verde y 16 XCUITest
  de las áreas tocadas en verde, con el centinela solo. Dos scans que fijaban el cuerpo viejo de «Vaciar datos» se
  actualizaron al nuevo.

## Fuera, con ticket

- El origen que declara y no llega a converger: `wipe-division-exclusion-trusts-the-origin-to-converge`.
- Lo que el origen recibe por su canal después de vaciar lo puentean los dos: `wipe-division-complement-can-be-bridged-twice`.
- Dos vaciados seguidos con una entera pendiente: `consecutive-wipes-whole-convergence-ignores-the-second-division`.
- La cuota del iCloud-KV y la clave que no se retira: `wipe-division-kv-key-has-no-quota-ceiling`.

## Guion de device-QA (hacen falta dos dispositivos con el mismo Apple ID, en modo iCloud y sesión privada)

1. En el iPhone, entra en tu cuenta de grupos y crea un grupo con un gasto que pagues tú y una liquidación confirmada.
   Comprueba que salen en Registros.
2. En el iPad NO entres en Grupos. Espera un par de minutos con los dos abiertos (que el iPad reciba las filas por iCloud).
3. En el iPad: Perfil → Ajustes → «Vaciar datos». Confirma y completa la bienvenida que aparece.
4. En el iPhone, sin tocar nada, espera un minuto: también se vacía (el vaciado vale para todos tus dispositivos) y el
   gasto y la liquidación de grupo desaparecen de Registros. Si te muestra la bienvenida, complétala.
5. Cierra la app del iPhone desde el selector de apps y vuelve a abrirla. Si todavía no están, repítelo una vez más: en el
   flujo típico vuelven al segundo arranque.
6. Comprueba en el iPhone: el gasto y la liquidación de grupo están en Registros, una sola vez cada uno, y el Inbox tiene
   un borrador por cada uno.
7. Control del caso sin copias dobles (opcional): repite con el iPad DENTRO de la misma cuenta de grupos. Tras el paso 5,
   cada gasto y liquidación sale una sola vez en los dos dispositivos.

## Barrido de `qa` · 2026-09-28 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido semanal (encargo `2026-09-28-barrido-qa-in-qa-semanal`), con el criterio del 2026-09-23 (#224). El guion pide dos dispositivos con el mismo Apple ID (un iPhone con grupos y un iPad que nunca entró en ellos). Lo cubren `GroupsRemoteWipeDivisionTests` y `GroupsBridgeRestoreConvergenceTests` (31/31 mutantes). El camino de un solo iPhone, «Vaciar datos» con grupos, se queda en el guion con `wipe-data-keeps-groups-but-drops-their-bridged-rows`.
