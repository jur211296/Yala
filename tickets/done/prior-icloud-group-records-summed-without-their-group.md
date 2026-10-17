---
id: prior-icloud-group-records-summed-without-their-group
status: done
priority: medium
area: "modo-nube, grupos, inbox"
created: 2026-10-15
source: "decisión de `reverse-to-icloud-merges-prior-icloud-data-without-asking` (2026-10-15) · nota de Jürgen en la card 4nt6"
updated: 2026-10-16
---

# Los movimientos de grupo que llegan de iCloud sin su grupo no se pueden quitar de la Bandeja

## El problema, en lenguaje de usuario

Vuelvo a iCloud y elijo «Sumarlos a mis datos». Entre lo que había en mi iCloud venían gastos de grupo de grupos en los
que no estoy con esta cuenta. Aparecen en la Bandeja como gastos de grupo, pero no hay grupo que los explique, y no los
puedo rechazar ni borrar.

## Por qué pasa

- Los borradores `.groupExpense` no se pueden descartar desde la Bandeja (`DraftSourceType.blocksInboxDismissal`).
- El barredor de huérfanas (`OrphanedBridgedTxSweeper`) solo mira zonas del canal backend que este teléfono conoce: un
  movimiento de un grupo que aquí no existe no es candidato y no se repara nunca.

## Por qué no se borran al sumar

Decidido en `reverse-to-icloud-merges-prior-icloud-data-without-asking`: en iCloud esas filas pueden ser las de otro
dispositivo con el mismo Apple ID que sí tiene esos grupos. Borrarlas de iCloud al sumar se las quitaría a él, incluidas
transacciones reales que aprobó.

## Lo que hay que decidir

Una salida para estas filas en ESTE teléfono que no se propague a quien sí tiene el grupo. Por ejemplo, dejar descartar un
borrador de grupo cuando su grupo no existe aquí y el canal de grupos está al día. Cualquier borrado local viaja por el
espejo, así que la salida tiene que ser algo que no le quite nada al otro dispositivo.

## Cómo se sabe que está bien

Tras sumar los datos de antes, la persona puede quitar de la Bandeja los gastos de grupo que no puede explicar, y el otro
dispositivo con esos grupos no pierde nada.

## Resuelto (2026-10-16)

**Qué cambia para el usuario.** En la Bandeja, un gasto de grupo cuyo grupo no está en este teléfono ofrece al deslizarlo
una sola acción, «Quitar de aquí». Lo quita de la Bandeja y del contador del Panel **solo en este teléfono**. Si el grupo
llega después, vuelve a aparecer solo.

**Qué se eligió y por qué.** Ocultarlo en una lista local (`InboxGroupDraftsHiddenHere`, `UserDefaults` sin sincronizar,
clave = el gasto), no rechazarlo ni borrarlo. Rechazar o borrar cambian la fila, y la fila viaja por el espejo de iCloud y
por el canal de la nube: en el otro dispositivo el borrador del Caso A es lo único que crea la pata real del gasto. La
lista local no le quita nada a nadie y es reversible. No espera a que el canal de Grupos esté al día: al ser reversible no
hace falta, y esperar dejaría sin salida a quien no tiene sesión de Grupos. La clave es el gasto y no el borrador porque el
otro dispositivo crea borradores nuevos del mismo gasto al re-puentear.

**Evidencia.** `InboxGroupDraftsHiddenHereTests` (quitarlo no deja el contexto sucio ni cambia la fila; vuelve si llega el
grupo; un borrador nuevo del mismo gasto sigue oculto; la Bandeja y el Panel no lo cuentan; «Vaciar datos» retira la
lista) y `GroupRowsWithoutGroupUITests` (quitarlo, y sigue quitado tras relanzar). Capturas en
`_capturas/2026-10-16-grupos-icloud/` (`antes-2-sin-salida.png` → `despues-2-quitar-de-aqui.png`).
