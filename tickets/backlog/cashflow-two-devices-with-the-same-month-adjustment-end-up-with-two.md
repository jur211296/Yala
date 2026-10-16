---
id: cashflow-two-devices-with-the-same-month-adjustment-end-up-with-two
status: backlog
priority: low
area: "cloudkit, sync, cashflow"
created: 2026-10-16
updated: 2026-10-16
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
