---
id: settlement-approval-leaves-no-trace-so-a-rebridge-asks-again
status: qa
priority: medium
area: "groups, sync"
created: 2026-09-27
updated: 2026-09-27
source: "review adversarial de `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows` (2026-09-27, lentes de dinero y de sync); leído en código, NO reproducido"
---

# Una liquidación ya aprobada vuelve a pedir su cuenta si otro dispositivo se lleva su pata

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPhone. Vuelven los gastos y las liquidaciones de grupo, y en el Inbox apruebo «Ana me pagó 25» en
mi cuenta del banco. Días después abro el iPad, que procesa el vaciado tarde. Al volver a abrir el iPhone, el Inbox me
pide otra vez a qué cuenta llegó ese pago. Si lo apruebo, el banco suma 25 dos veces. El borrador de una liquidación no
se puede rechazar ni borrar.

## Lo medido (leyendo código)

- Aprobar el borrador de una liquidación crea la transacción real SIN `splitSettlementID` (`DraftService.swift`, D7) y
  borra el borrador. No queda nada que diga «esta liquidación ya se aprobó».
- La convergencia y la devolución por declaración (`GroupsRemoteWipeReturn`) re-puentean solo las liquidaciones que se
  quedaron sin ninguna pata. Esa guarda no ve la real aprobada, así que no la protege.
- Hay dos caminos que llegan aquí:
  1. El receptor tardío importó la pata virtual pero todavía no la real aprobada. Se lleva la virtual, y la liquidación
     queda sin patas donde se re-puentea.
  2. La aprobación ocurre entre el borrado del receptor y la llegada de ese borrado al origen. Es la ventana que ya anota
     `wipe-data-group-rows-return-only-on-the-next-cold-launch`.
- `DraftService` no deja rechazar ni borrar un borrador `groupSettlement`, así que la persona no puede quitarlo del Inbox.

## Qué hay que decidir

La causa es que la aprobación no deja rastro. Hay tres salidas posibles, y las tres cambian D7:

- Que la transacción real conserve un enlace (otro campo, porque `splitSettlementID` la haría «pata» para el bridge).
- Que la aprobación deje una marca durable que viaje por el espejo.
- Que el re-puente de una liquidación no cree borrador cuando la virtual ya se aprobó alguna vez.

## Relacionados

- [[late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows]]
- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]
- [[wipe-data-group-rows-return-only-on-the-next-cold-launch]]

## Resolución (2026-09-27)

**Qué cambia para quien usa la app.** Una liquidación de grupo que ya aprobaste en el Inbox no vuelve a pedirte a qué
cuenta llegó el pago, aunque otro dispositivo procese tarde un «Vaciar datos»: la liquidación recupera su movimiento en la
cuenta de grupos y tu banco sigue contando el pago una sola vez. Si aun así aparece un borrador de un pago ya registrado
(lo creó otro dispositivo antes de enterarse), finalizarlo te dice «Este pago ya está registrado en tus cuentas» en vez de
registrarlo otra vez, y el siguiente arranque lo retira solo. Y el borrador de una liquidación ya se puede rechazar o
borrar deslizando la fila; el rechazado se ve en Archivados, por si quieres deshacerlo.

**Cómo.**
- Aprobar el borrador de una liquidación deja una **marca**: un borrador aprobado NUEVO, enlazado a la transacción real y
  creado en el mismo guardado. Se ve en Archivados y, al tocarlo, abre la transacción. Es un registro nuevo y no el
  pendiente porque el pendiente nació con la pata virtual: un receptor tardío que se llevó la virtual se llevó también el
  pendiente, y su borrado se habría llevado la marca.
- `bridgeSettlement` solo sustituye los borradores pendientes. Con la marca rehace la pata virtual y no crea borrador ni la
  pata real enlazada del Caso C. Con un rechazo no vuelve a preguntar (todo cambio remoto de la liquidación la re-puentea,
  así que sin esto el rechazo no duraba).
- La marca cuenta por su estado, no por su transacción enlazada: CloudKit puede traerla antes que la transacción.
  Aprobar un pendiente de una liquidación con marca da error y no crea nada.
- El arranque poda los pendientes que conviven con una liquidación ya resuelta.
- La marca viva no se borra ni vuelve a pendientes desde el Inbox (ni en lote).
- `DraftSourceType.blocksInboxDismissal`: solo `.groupExpense` bloquea rechazar o borrar.
- No es un campo nuevo en `TransactionItem`: pedía desplegar el schema de CloudKit del contenedor personal a Production y
  una columna en el backend (acceso de Jürgen). El borrador aprobado ya viaja por el espejo y por el modo nube.

**Verificado.** 13 tests de comportamiento contra el bridge real (los dos caminos del ticket con los borradores del
receptor modelados, el receptor que se lleva la real y la marca, la convergencia, la marca, la rama opt-in, la
idempotencia con y sin transacción enlazada, el Caso C aprobado y rechazado, rechazar/borrar y las acciones en lote), 5 de
la decisión pura y uno de cableado del arranque. Review adversarial de tres lentes (dinero, sync, tests): tumbó la
idempotencia que exigía la transacción enlazada, el «Eliminar» y el «Devolver a pendientes» de Archivados sobre la marca,
el rechazo invisible y el pendiente que deja un receptor con grupos. Mutantes: ver el PR.

**Lo que queda fuera.**
- Las liquidaciones aprobadas antes de este cambio no tienen marca: pueden volver a preguntar (ahora con salida: rechazar).
- Un dispositivo con una versión anterior de la app no deja marca y, al re-puentear, borra las de los demás.
- El rechazo cambia el registro pendiente: un receptor tardío que lo importó se lo lleva y vuelve a preguntar (sin dinero).
- Si la persona borra la transacción real, no se vuelve a preguntar solo: se re-aprueba tocando la marca en Archivados.
- Dos dispositivos que aprueban el mismo pago antes de verse por el espejo siguen creando dos transacciones (ya pasaba).
- Soltar la cuenta de grupos conservando pasa la marca a `.manual` como cualquier borrador de grupo
  ([[groups-reassociation-does-not-restore-the-bridge-link]]).
- Si otra persona corrige el importe de una liquidación ya aprobada, el banco no se entera
  ([[settlement-amount-edited-after-approval-leaves-the-bank-stale]]).

## Guion de QA (simulador, opcional)

Lo que un solo dispositivo puede enseñar es la parte visible: rechazar, borrar y la marca en Archivados. Que el re-puente
no vuelva a preguntar pide dos dispositivos y un vaciado tardío; lo fijan los tests.

Montaje: Yala Dev en el iPhone 17 Pro, Yala completo activado, un grupo con otra persona y dos liquidaciones confirmadas
en las que esa persona te paga (cada una deja en el Inbox un borrador «¿a qué cuenta llegó?»).

1. Abre el Inbox, pestaña **Pendientes**. Desliza a la izquierda el primer borrador de liquidación y toca **Rechazar**.
   La fila sale de Pendientes y aparece en **Archivados**, marcada como que le falta la cuenta. Tócala: se abre la hoja
   para asignar cuenta (así se deshace un rechazo). Ciérrala sin finalizar.
2. Abre el segundo borrador, elige una cuenta y toca **Finalizar**.
3. Ve a **Archivados**: sale la liquidación aprobada con el nombre de la cuenta. Tócala: abre la transacción, y la cuenta
   muestra el pago una sola vez. Toca el icono del círculo con check (arriba a la derecha), marca esa liquidación y
   prueba **Regresar a pendientes** y luego **Eliminar**: la liquidación aprobada se queda donde está.
4. Crea una tercera liquidación en la que te pagan. Desliza su borrador y toca **Eliminar**: desaparece.
