---
id: reverse-prior-icloud-scan-has-a-fixed-deadline
status: backlog
priority: low
area: "nube, vuelta a iCloud"
created: 2026-10-19
updated: 2026-10-20
source: hallado al arreglar `reverse-discard-wipe-cuts-a-large-icloud-at-two-minutes`
---

# La pregunta a iCloud antes de «Volver a iCloud» tiene un plazo total de 60 s

## Qué le puede pasar al usuario

Con un iCloud muy grande (la copia propia también se recorre), la pregunta «¿qué sumaría?» puede pasar de 60 s y
acabar en «No pudimos revisar tu iCloud… Puede ser la conexión», sin que la conexión tenga nada que ver.

## Lo medido (2026-10-19)

`ICloudPersonalCorpusProbe.scanForeignCorpus` corta con `ForeignScanError.deadline` al pasar
`foreignScanDeadline = 60` s **totales**, el mismo patrón que tenía el borrado. En el QA guiado del 19-oct, con 1.541
movimientos, la pregunta sí contestó: no está medido a partir de qué tamaño falla.

## Qué hay que decidir

Si pasa al molde del borrado (plazo sin avance) y si su texto de fallo deja de mencionar la conexión cuando fue el
plazo. Antes, medir cuánto tarda con un corpus grande en device.

## Hecho el 2026-10-20 (la mitad del plazo)

Con la card blqa del QA guiado del TF19 la pregunta pasó al molde del borrado: `scanForeignCorpus` va por `ICloudZoneScan` con un plazo **sin avance** de 60 s (`foreignScanStallLimit`), sin plazo total. Su motivo pasa de `scanDeadline` a `scanStalled`.

## Lo que queda

El texto de fallo de la vuelta a iCloud sigue diciendo «Puede ser la conexión» también cuando fue el plazo. La puerta privada del Welcome ya tiene el suyo (`welcome.privateICloud.stalledTitle`); falta decidir el de Almacenamiento.
