---
id: reverse-upload-failed-rows-need-a-device-measurement
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-26
updated: 2026-09-26
source: "`reverse-upload-sample-reads-unreadable-rows-as-drained` (2026-09-26), su criterio de medición"
---

# La vuelta a iCloud no cuenta las filas que no pudo comprobar una a una, y falta medir cuáles son

## El problema, en lenguaje de usuario

Pulso «Volver a iCloud» y la vuelta termina en modo privado. Si alguno de mis datos no se pudo comprobar —Yala no
supo decir si había llegado a iCloud—, la vuelta lo da por subido igual. Si de verdad no llegó, ese dato se queda en la
nube de Yala, que queda congelada, y no aparece en iCloud.

## Por qué pasa

`MigrationWorkExecutor.reverseUploadStatus()` decide `pending = exportPending + noMetadata`. Las filas que
`CKIdentityCapture` no pudo resolver una a una salen `failed` y **no cuentan**. Los motivos por fila son:

| Motivo | Qué significa |
|---|---|
| `no-zent` | la entidad de la fila no está en `Z_PRIMARYKEY` (el mapa sí se leyó) |
| `meta-query` | la consulta de metadata falló para esa fila, pero no para todas |
| `zone-fk-missing` | la fila tiene nombre de registro en CloudKit, pero su zona no tiene FK |
| `zone-query` / `zone-unresolved` | la zona no se deja leer o no casa |
| `uri-unparseable` | el identificador de esa fila no se resolvió, pero el de otras sí |

Cuando NO se miró ninguna fila (el SQLite no abre, faltan las tablas del espejo…), la muestra ya es ilegible y la vuelta
no se cierra: lo arregló `reverse-upload-sample-reads-unreadable-rows-as-drained` el 2026-09-26. Esto es lo que queda:
los fallos sueltos.

**Dos motivos que la review del 2026-09-26 señaló como NO benignos** (inferido, sin medir):

- `uri-unparseable` de una fila suelta: una fila insertada y aún sin guardar tiene un identificador temporal
  (`x-coredata:///Entidad/t<UUID>`) que `parseCoreDataURI` no resuelve. Esa fila no ha subido, y si era la única pendiente
  la vuelta se cierra sin ella. Pasaba igual antes del arreglo.
- `meta-query` de una fila suelta: un fallo puntual de SQLite (base ocupada, cambio de esquema) esconde esa fila.

Y uno que se dejó por fila a propósito: **todas `no-zent` con el mapa leído** da `.drained`. Casi inalcanzable (el mapa
sale del mismo modelo), pero si aparece en la medición es estructural de hecho.

## Por qué no se cuentan ya

Contarlos es una línea, pero si hay filas `failed` por un motivo benigno y permanente, la vuelta no drenaría nunca y
cada intento acabaría en el techo. `zone-fk-missing`, por ejemplo, es una fila que YA tiene nombre de registro: lo más
probable es que sí esté en iCloud. Hay que ver antes qué aparece en un iPhone real.

## Qué ya está cableado para medirlo

- Breadcrumb local `CloudSyncReverse uploadFailedRows <motivo>=<cuántas>,…` en cada muestra con algún `failed` por fila.
- Canario `cloudReverseUploadFailedRows`, una vez por proceso y conjunto de motivos, con el detalle
  `<motivo>|<motivo>…` (sin cifras). Se lee en el dataset `yala_metrics` (producción) o `yala_metrics_staging` (lo que manda `Yala Dev`, el de este
  guion); las consultas están en `qa/cloud/README`, § `/metrics`.

## Guion de medición en iPhone

**Montaje**: un iPhone con `Yala Dev` desde Xcode (staging), **con iCloud activo**, una cuenta en la nube con datos
variados (movimientos, categorías, presupuestos, etiquetas, un pago programado), y el iPhone conectado al Mac con
**Console.app** abierta: elige el iPhone a la izquierda, pulsa «Iniciar transmisión» y escribe `CloudSyncReverse` en el
buscador.

1. En Yala: **Perfil → «Dónde viven tus datos» → «Volver a iCloud»**, pasa las dos confirmaciones y, cuando lo pida,
   cierra Yala del todo y vuelve a abrirla.
2. Vuelve a «Dónde viven tus datos» y deja la pantalla abierta hasta que la vuelta termine (modo privado).
3. En Console.app, copia **todas** las líneas `uploadFailedRows` y `uploadPending` y pégalas en este ticket, con la hora.
4. Si no sale ninguna `uploadFailedRows`, apúntalo también: es la respuesta «en este iPhone no aparece ningún fallo por
   fila».
5. (Opcional) Repite con un segundo iPhone o con una cuenta que venga de migrar desde iCloud, no nacida en la nube.

## Qué hay que decidir con la medición (es de producto)

1. ¿Qué motivos cuentan como pendientes? Candidatos: `meta-query` y `uri-unparseable` (no se miró la fila) sí;
   `zone-fk-missing` (ya tiene nombre de registro) probablemente no.
2. Si alguno cuenta, ¿con qué texto espera la pantalla? Hoy dice «Subiendo tus datos a iCloud».

## Criterios de aceptación

- [ ] Medido en al menos un iPhone qué motivos aparecen durante una vuelta real.
- [ ] Decisión de Jürgen sobre cuáles cuentan.
- [ ] Los que cuenten entran en la suma, con test y mutante.

## Relacionado

- `reverse-upload-sample-reads-unreadable-rows-as-drained` — el caso estructural, cerrado.
- `reverse-upload-unreadable-sample-waits-the-long-ceiling` — cuánto espera una muestra ilegible.
