---
id: duplicates-mode-rows-dont-say-their-date
status: done
priority: low
area: "registros"
created: 2026-10-17
updated: 2026-10-25
source: "barrido del lote 8 de la auditoría UX 2.2 en el simulador (2026-10-17)"
---

# En modo duplicados, sin el criterio «Fecha», no se ve de qué día es cada registro

## El problema, en lenguaje de usuario

En Registros › ··· › «Identificar duplicados», la lista va por grupos («11 registros iguales · Se queda el primero»)
y ya no por días. Con los cuatro criterios no importa: los de un grupo son del mismo día. Pero si quitas «Fecha» de
«Coincidir por», cada grupo junta registros de días distintos y ninguna fila dice de cuál es: no se puede decidir si
de verdad están repetidos antes de «Quitar repetidos».

## Qué se sabe

Medido en el simulador el 17-oct con el perfil `realista` y «Coincidir por» sin Fecha ni Nota: «1297 posibles
duplicados en 295 grupos», filas «Bus · S/ -29» sin fecha.

## Qué hacer

Con «Fecha» fuera de los criterios, que cada fila del modo enseñe su fecha corta (o que la cabecera del grupo diga el
rango de días).

## Cerrado (cola 2.2 · lote 12.5, 2026-10-25)

Con «Fecha» fuera de «Coincidir por» y un grupo que junta días distintos, cada fila del modo dice su día con año («20 oct 2026»), y VoiceOver lo lee (`RecordsDuplicateLogic.rowDateCaption`). Si todo el grupo es del mismo día, la cabecera ya lo dice y la fila no lo repite. Medido en el simulador (`capturas/antes-3`/`despues-3` del PR). Tests: `DuplicatesRowDateCaptionTests` y `RecordsLote8BUITests.test_duplicates_removeRepeated_asksFirst_andLeavesOnePerGroup`.
