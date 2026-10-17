---
id: cashflow-two-devices-with-the-same-month-adjustment-end-up-with-two
status: done
priority: low
area: "cloudkit, sync, cashflow"
created: 2026-10-16
updated: 2026-10-17
source: residual de personal-cloudkit-cashflow-override-line-declared-as-reference (2026-10-16)
---

# Dos teléfonos con el mismo ajuste de un mes acaban con dos

## Qué le puede pasar al usuario

Hasta 2.1 los ajustes de un mes no sincronizaban en Production, así que alguien con dos iPhone pudo apuntar el
mismo mes de la misma línea en los dos. Al actualizar, cada teléfono migra el suyo y lo sube; cada uno recibe el
del otro, y la línea queda con **dos ajustes del mismo mes**. La pantalla enseña uno de los dos, sin orden fijo
(`line.monthOverrides?.first { $0.monthKey == … }`), y puede cambiar entre aperturas. Editar ese mes los sustituye a
los dos por uno (`CashFlowPlanViewModel.setOverride` borra todos los de ese mes), así que tiene salida.

## Lo que ya cubre la migración y lo que no

`CashFlowOverrideLineMigration` no crea duplicados: si la línea ya tiene ese mes en la relación nueva, el ajuste
viejo se borra (en Production nunca llegó al servidor). Lo que no cubre es el duplicado que llega **por iCloud**,
después de migrar: no se quiso borrar automáticamente un ajuste ajeno sin saber cuál es el bueno (no tienen fecha).

## Opciones

1. Lectura determinista: con dos del mismo mes, enseñar siempre el mismo (por `id`) en los cuatro lectores.
2. Fundir al arrancar: quedarse con uno por `id`, el mismo en los dos teléfonos, y borrar el otro. Pierde el importe
   del otro teléfono: decide Jürgen.

## Y su gemelo en `.dev` (review adversarial del 2026-10-16)

En el contenedor `.dev` (`CD_line` es STRING y sí sincroniza), si una build vieja de Yala Dev vuelve a apuntar un mes
que otro teléfono ya migró, su ajuste llega con `line` puesto y la migración del otro lo borra como «duplicado
superado»: gana el que llegó antes a la relación nueva, no el más reciente (no hay fecha). En Production no pasa: el
ajuste de la build vieja lo rechaza iCloud y no llega. Mismas opciones de arriba.

## Cerrado (2026-10-17)

Decidido en el encargo (Jürgen): fundir por la clave natural, línea + mes.

**Qué cambia para el usuario.** Si dos teléfonos apuntaron el mismo mes de la misma línea, los dos acaban
enseñando el mismo ajuste y, en el siguiente arranque, solo queda ese. El otro importe se pierde: los ajustes no
tienen fecha y saber cuál es el más reciente pediría un campo nuevo de iCloud.

**Cuál se queda: el de menor `id`, esté en la relación que esté** (`CashFlowOverrideLineMigration.survivor`). Es
la misma regla en los dos teléfonos y en todos los caminos, así que el orden de llegada no cambia el resultado. Cada
pasada borra solo lo que no es el mínimo de lo que ve, y por eso nunca borra el que acabará quedándose. La regla
anterior de la migración («gana el que ya estaba en la relación nueva») dependía del orden de llegada, y en `.dev`
un teléfono podía conservar justo el que el otro borraba. El gemelo de `.dev` de arriba queda cerrado con ella.

**Dónde.** Dos pasadas por arranque. La del paso 0.0, que ya existía, solo toca los meses que traen un ajuste de
legado: son locales y guardar ahí no compite con iCloud. La completa, que funde lo que llegó por iCloud, va detrás de
la puerta de quiescencia del import (paso 16.4.9): guardar con el import en curso es el crash de `BootSaveGateLogic`.
Lo cazó la review adversarial; la primera versión fundía todo en el 0.0. Los lectores (el calculador, en sus dos
sitios, y la lista de ajustes de la línea) eligen ya el superviviente con `CashFlowLine.monthOverride(for:)` y
`shownMonthOverrides`, mirando las dos relaciones, así que la pantalla no cambia de un arranque a otro aunque la
limpieza aún no haya corrido.

**Tests.** `CashFlowOverrideLineMigrationTests` (sección «Dos teléfonos con el mismo mes») y
`CashFlowProjectionCalculatorTests.twoOverridesOfTheSameMonth_alwaysShowTheLowestID`. Mutantes muertos: lector con
`.first`, «gana la relación nueva», pasada sin fundir la relación nueva, pasada que borra huérfanos.
La review adversarial (una lente, cuatro ejes) no encontró ningún orden de llegada que deje los dos teléfonos
distintos o sin ajuste.
