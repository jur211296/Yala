---
id: reverse-of-a-migrated-account-sums-records-written-after-the-migration
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-10-15
source: "hallazgo de `reverse-to-icloud-merges-prior-icloud-data-without-asking` (2026-10-15). INFERIDO: medir antes de trabajarlo"
updated: 2026-10-15
---

# La vuelta a iCloud de una cuenta migrada suma lo que otro dispositivo escribió en ese iCloud después de migrar

## Lo que se infiere

Desde `reverse-to-icloud-merges-prior-icloud-data-without-asking`, solo la vuelta de un teléfono NACIDO en la nube pregunta
a iCloud qué sumaría. Una cuenta migrada no pregunta, a propósito: su zona es su propio corpus y la vuelta está construida
sobre él (el mapa de coordenadas, la reconciliación).

Pero si otro dispositivo con el mismo Apple ID siguió en modo privado y escribió en esa zona después de la migración, esos
registros no son del corpus de la cuenta y el espejo los suma igual al volver, sin aviso.

## Medir primero

1. ¿Puede otro dispositivo seguir escribiendo en modo privado en esa zona tras la migración? El marcador de la migración le
   llega por el espejo y lo encamina al adopt; falta medir qué pasa si no lo procesa.
2. Si puede, ¿cuántos registros ajenos ve la pregunta de la vuelta (`ICloudPersonalCorpusProbe.foreignCorpusForReverse`)
   en una cuenta migrada? Con un metadato local del espejo por cada fila migrada, lo ajeno debería ser solo eso.

## Y la misma familia en un teléfono nacido en la nube

La pregunta se hace al tocar «Volver a iCloud». Si la vuelta se para antes de montar el espejo (las fases previas tienen
techo de 72 h) y se retoma días después, no se vuelve a preguntar, y lo que otro dispositivo escribiera en ese tiempo se
suma sin aviso. Volver a preguntar al entrar en la fase de montaje lo cerraría.

## Cómo se sabe que está bien

La vuelta de una cuenta migrada no suma sin avisar registros que no eran de su corpus.
