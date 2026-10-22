---
id: orphaned-group-records-stay-out-of-the-notice
status: done
priority: low
area: "accounts, groups, bridge"
created: 2026-10-15
updated: 2026-10-16
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

## Resuelto (2026-10-16)

**Qué cambia para el usuario.** La parte real de un gasto de grupo que pagó desde una cuenta que luego eliminó sale ahora
en «Movimientos sin cuenta» y se puede mover a otra cuenta: vuelve al saldo. Una parte virtual (el espejo en «Grupos»)
nunca sale ahí.

**La regla común** (`GroupLegKindLogic` + `GroupLegEvidence`). Con cuenta, manda la cuenta. Sin cuenta, solo se afirma lo
que se puede probar: virtual si su subcategoría es de sistema y no es «Liquidación enviada»; real si es «Liquidación
enviada» en una liquidación, o si el gasto sigue aquí, lo pagué yo, no es saldo inicial, no hay otra pata real y la fila
vale exactamente `-total` en la divisa del gasto. Si no, «no se sabe». La única virtual con ese importe (mi parte igual al
total, sin préstamo) deja el mismo neto: tratarla como real no cuenta nada dos veces.

**Los cuatro sitios la usan.** El aviso solo incluye las reales probadas; al moverlas conservan sus punteros (siguen siendo
la pata real del gasto), no cambian de divisa (con su propia nota en la hoja) y el gasto se re-puentea: si mientras no
tenía cuenta un re-puente dejó en la Bandeja «¿de qué cuenta salió?», ese borrador se va (aprobarlo creaba una segunda
pata real). La pata real de una liquidación con un borrador pendiente suyo no entra: la salida es la Bandeja. El barredor de huérfanas, el desasociar (`.keep`) y la retirada de legacy
ya no sueltan una fila sin cuenta «por si es real»: con «no se sabe» no la tocan, con virtual la borran y con real la
sueltan. Eso cierra el caso contrario de la review (una virtual soltada entraba en el aviso como movible). Lo que el
desasociar deja intacto entra en el libro de conservados, para que re-asociar la cuenta no cree otra pata al lado.

**Evidencia.** `GroupLegWithoutAccountTests` (la regla, el aviso, mover con punteros sin convertir, virtuales que nunca
salen, liquidación, Panel, barredor y desasociar), los tests actualizados de `GroupsAssociationDetachTests` y
`LegacyGroupsRetirementTests`, y `GroupRowsWithoutGroupUITests` (el aviso cuenta 3 y al mover «Banco QA» pasa a 882).
Con los arreglos revertidos caen 21 aserciones de las tres cards. Capturas `antes-5`/`despues-5` en
`_capturas/2026-10-16-grupos-icloud/`.

**Residual.** Una pata real sin cuenta cuyo gasto ya no está en el teléfono no se puede probar real: queda con su puntero
muerto y su salida es el editor (`BridgedEditPolicy.pointerResolves`), como antes.
