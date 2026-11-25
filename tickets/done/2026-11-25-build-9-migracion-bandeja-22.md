---
id: 2026-11-25-build-9-migracion-bandeja-22
status: done
priority: high
area: "tests, migracion, bandeja, release"
created: 2026-11-25
updated: 2026-11-25
source: "Encargo de Jürgen (25-nov, 8:25 Lima): el PR de la build 9 queda en rojo por la prueba de migración de la Bandeja desde 2.2"
---

# Build 9: la prueba de migración de la Bandeja desde 2.2 deja el PR en rojo

## Qué pasa

El PR de la build 9 (https://github.com/jur211296/Yala/pull/1171) no entra en `2.3`: el check `tests` cae en
`BandejaUnirMigracion22Tests.unaBaseDe22_abreConElModeloDeHoy_conSusBorradores()`, también al repetirla
(https://github.com/jur211296/Yala/actions/runs/45611092032). En `2.3` la misma prueba pasa.

## Causa (medida)

Es la prueba, no la migración.

- Reproducido en local sobre la rama del PR: la única aserción que cae es el control de la línea 60,
  `removed["InboxDraft"]?.contains("joinRecordRaw") == true`. El resto de la prueba pasa.
- La prueba armaba «el modelo de 2.2» quitando del modelo de hoy lo que no está en el esquema VIVO de Producción
  (`Cloudkit Schemas/yala-production.ckdb`). El PR re-exporta ese esquema con `CD_InboxDraft.CD_joinRecordRaw` ya dado de
  alta en Producción: desde ahí no se quitaba nada, el «modelo de 2.2» era el de hoy y el control (bien puesto) avisaba de
  que la prueba ya no probaba migración alguna.

## Arreglo

- El esquema de Producción de 2.2 queda congelado junto a la prueba: `YalaTests/BandejaUnirAlLlegar/yala-production-2.2.ckdb`,
  copia exacta del de `Cloudkit Schemas/` en el tag `v2.2`. La prueba lo lee a él, no al vivo.
- Ahora el «modelo de 2.2» quita todo lo que 2.3 añadió (11 campos en 5 tablas, `InboxDraft.joinRecordRaw` incluido) y el
  control sigue en pie. Añade otro: que el esquema congelado se leyó y trae la Bandeja.

## Medido contra la 2.2 publicada

- Con el código del tag `v2.2` (copia por `git archive`, compilada aparte) se escribió una base personal real: una cuenta y
  tres borradores pendientes de la Bandeja (uno con cuenta vinculada), sin columna `joinRecordRaw`.
- Con el código de la build 9 (rama del PR) se abrió una copia de esa base: los tres borradores siguen, con nota, monto,
  estado, origen, `syncID` y la cuenta vinculada; `joinRecordRaw` nace vacío y se guarda.
- Las pruebas de la medición fueron temporales y no se commitean.

## Verificación

- `BandejaUnirMigracion22Tests`, `PersonalCloudKitSchemaParityTests` y la medición: 9 pruebas en 3 suites, verde.
- `PersonalCloudKitSchemaParityTests` sin editar.
- Gate completo sobre la rama del PR con `2.3` mergeada: build `Yala` y `Yala Dev`, `YalaTests` entero (16.321 pruebas en
  1.965 suites, verde), ninguna clase de interfaz pasa por lo tocado, revisor de checklist no aplica, 29/29 pasos del job
  `coverage-index`.

## Cierre (25-nov)

Arreglo commiteado en la rama del PR de la build 9 (https://github.com/jur211296/Yala/pull/1171), que queda en
auto-merge. No hace falta retirar la build 9 ni subir otra: la migración desde 2.2 conserva los borradores.
