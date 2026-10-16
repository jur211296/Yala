---
id: orphaned-group-records-stay-out-of-the-notice
status: backlog
priority: low
area: "accounts, groups, bridge"
created: 2026-10-15
updated: 2026-10-15
source: residual de las cards tablero-los-movimientos-que-quedaron-sin-cuenta-sovw y tablero-eliminar-una-cuenta-todavia-puede-dejar-mjzx
---

# Los movimientos de grupo que se quedaron sin cuenta no salen en el aviso «Movimientos sin cuenta»

## Qué le pasa al usuario

Si antes de la 2.1 eliminó una cuenta en la que había apuntado la parte real de un gasto de grupo (una «pata real» con
puntero a un gasto o una liquidación), ese movimiento se quedó sin cuenta igual que los demás, pero el aviso del Panel no
lo cuenta ni lo deja mover. Sigue fuera del saldo.

## Por qué se dejó fuera

Una fila de grupo sin cuenta es ambigua: la pata VIRTUAL vive en una cuenta de sistema de Grupos, y con esa cuenta aún
sin hidratar se lee igual (`BridgedEditPolicy` la trata así). Moverla a una cuenta real la convertiría en pata real y el
gasto contaría dos veces. Distinguir una de otra pide mirar el puente (si existe la pata virtual hermana, si el grupo es
de esta persona), y eso es del puente de grupos, no del aviso.

## Inferido, sin medir

Cuántas personas tienen una pata real de grupo sin cuenta: no hay canario. Antes de #512 la hoja de eliminar no existía,
así que cualquiera que eliminara una cuenta con gastos de grupo apuntados en ella está en este caso.

## Y el caso contrario, inferido por la review adversarial (2026-10-15)

`GroupsAssociationDetach.action(for:)` y `OrphanedBridgedTxSweeper.decide` tratan `account == nil` como cuenta real y
sueltan los punteros de grupo. Una pata VIRTUAL cuya cuenta de sistema aún no se había hidratado, al desasociar o al
barrer, se queda sin cuenta y sin puntero: entonces SÍ sale en el aviso, y moverla la convierte en un gasto real (el doble
conteo que el aviso evita con las filas de grupo). Esos caminos son anteriores al aviso; lo nuevo es que ahora hay una
acción que lo materializa. Sin medir cuántas filas hay así.
