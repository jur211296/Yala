---
id: markerless-adopt-stays-blocked-while-another-device-writes-to-the-account
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-25
source: "review adversarial de `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` (2026-09-24), segunda pasada"
---

# El adopt sin marcador no entra mientras otro teléfono siga escribiendo en la cuenta

## El problema, en lenguaje de usuario

Mi iPhone ya usa la nube a diario. Mi iPad, con el mismo iCloud y sin la marca del iPhone, intenta entrar en la cuenta
con algo propio que subir. Nunca termina: cada intento acaba en «espera a iCloud».

## Lo medido y lo inferido (2026-09-24)

- **Medido en código**: sin marcador, el adopt pide la cobertura de `adoptSharedRowsProof`. Lo que el iPhone crea en la
  nube después del cutover no viaja por iCloud (su espejo está apagado), así que falta en el iPad siempre. Ya pasaba
  antes del ticket de origen, que exigía todas las filas.
- **Medido en código**: desde `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` una fila que falta
  deja de bloquear si lo que sube se creó en el iPad después de la última escritura del backend. Con un teléfono que
  escribe a diario (hasta los tipos de cambio suben cada día UTC y cuentan para esa última escritura) eso no llega nunca.
- **Inferido**: el corte global es a propósito (protege de un tercer teléfono que adoptó antes y subió filas del iPad).
  Arreglarlo pide otra señal, no mover el corte.

## Criterios de aceptación

- [x] Medido cuántos adopts sin marcador llegan con otro teléfono activo (¿existe el marcador en la práctica?).
- [x] Una salida que no duplique, o la decisión escrita de que la espera es el comportamiento correcto.

## Resolución (2026-09-25)

**Qué cambia para quien usa la app.** Si el primer teléfono que activó la nube no llegó a dejar su marca en iCloud, el
siguiente que entra en la cuenta con todos los datos de la cuenta ya en él deja la suya. Los teléfonos que lleguen después
entran en la cuenta aunque otro esté escribiendo a diario, en vez de esperar a iCloud para siempre.

**Medido.**
- Flota: producción tenía **0 perfiles** (contado como `postgres`, sin rastro). Staging: 6 perfiles, 4 migrados, todos de
  dogfooding. En Analytics Engine (90 días) no había ningún evento de este camino, porque el bloqueo solo dejaba `os_log`.
  Desde este ticket lo cuenta el canario `cloudAdoptLineageBlocked` (`rowsMissing|active` es este caso).
- Camino real: el líder no apaga su espejo sin exportar su marcador (paso 4, con techo y aborto), así que «otro teléfono
  escribe a diario y yo no tengo marcador» no sale de un líder que terminó. Sale de dos sitios. Uno es transitorio: el
  marcador aún no ha llegado a este teléfono (import atrasado, iCloud apagado aquí), y esperar es lo correcto. El otro es
  el caso del ticket: el líder nunca lo exportó (murió o abortó tras el cutover del servidor) y quien escribe es un
  ADOPTADOR. Los adoptadores no escribían marcador, así que esperar no terminaba nunca.

**La salida: el relevo del marcador.** Un adopt sin marcador de la cuenta y con **cobertura total** (toda fila viva del
backend está aquí con su identidad) deja su propio `CloudMigrationMarker`, marcado `relay:` en `writerDeviceID`. No arma
el apagado del espejo hasta verlo exportado, con un tope de 10 min. Vale lo mismo que el marcador del líder: quien lo
importa trae antes todo lo que el backend tenía, y lo que se escribe en la nube después no pasa por iCloud. El corte
global de la prueba sin marcador no se tocó. El aborto del líder y `isMarkerExported` ignoran los relevados. La reversa
los borra todos. El corte del barrido de zombies los salta. Regla «Y el adopt que entra sin marcador deja el suyo» en
`.claude/rules/swiftdata-cloudkit.md`.

**Descartado.** Mover el corte global (reabre el tercer teléfono). El HLC del backend como fecha de creación (es de la
última escritura). Un registro de «espejo apagado» en el servidor (falla abierto con un adoptador a medias). «Subir
igualmente» (decisión de producto que duplica).

**Review adversarial, tres lentes.** Ninguna encontró un duplicado propio del relevo que no exista ya con el marcador
del líder. Cazaron tres cosas, ya corregidas:
- «El propio» por `deviceID` era frágil, porque `identifierForVendor` puede ser nil. Ahora va por el prefijo.
- El relevo no esperaba a exportarse, y un relanzamiento rápido lo dejaba solo en local. Ahora el adopt espera.
- El corte de la reversa podía tomar el 0 del relevo.

**Residuales.**
- `markerless-adopt-without-full-coverage-never-relays-the-marker`: el primer adoptador sin cobertura total no releva.
- `adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate`: el camino del marcador ya tenía este residual, y
  ahora alcanza también a estas cuentas.
