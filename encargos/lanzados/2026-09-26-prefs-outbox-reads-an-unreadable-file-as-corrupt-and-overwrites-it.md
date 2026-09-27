# Si el teléfono no consigue leer tus preferencias pendientes de subir, las borra

## Contexto
Cola A autónoma (riesgo real): los cambios de preferencias que aún no subieron esperan en un fichero (`PrefsOutbox`). Si la app no consigue leerlo —fallo de lectura, no corrupción— `loadOrCreateState` lo mete en el mismo `catch` que un decode roto, empieza un estado vacío encima y esos cambios no llegan nunca a los otros dispositivos (también resetea `nodeID` y el reloj del LWW).

Ticket: `tickets/backlog/prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it.md`.
Nació de la review adversarial de `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (2026-09-23).

**MODO NOCTURNO (21:00–06:00 Lima):** no abras AskUserQuestion de producto. Elige la opción robusta / Recommended. Solo para si hace falta un secreto/dispositivo de Jürgen o una decisión demasiado grave para asumir (esta no lo es: fallos de lectura se reintentan; corrupción de decode conserva el trato actual).

**MODO AUTÓNOMO (override Jürgen 2026-09-22):** la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan **queda suspendida**. Implementa hasta gate → PR → merge a `2.1` → `/cerrar-total` sin pedir continuar.

## Que se pide
- Separar fallo de LECTURA (`Data(contentsOf:)`) de corrupción de decode en `PrefsOutbox.loadOrCreateState` (y caminos equivalentes).
- Un fallo de lectura **no** sobrescribe el fichero: se reintenta más tarde sin encolar ni escribir un estado nuevo encima.
- La corrupción (decode) conserva el trato actual (estado nuevo), con test de las dos ramas y control positivo.
- Tests de comportamiento que fallen si alguien vuelve a mezclar lectura y decode en el mismo `catch` que borra pendientes.
- Actualiza reglas/docs si aplica (`swiftdata-cloudkit.md` u otra regla de sync de prefs).
- Al terminar: board al día (`tickets/` + `docs/TICKETS.md`), PR a `2.1`, merge, `/cerrar-total`.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi
- No inventar PASS de device-QA
- No ampliar a rediseño UI (Cola B) ni a mediums sin riesgo real (Cola C)
- No revocar ni rotar secretos de staging/prod por tu cuenta

## Como se sabe que esta bien
- Gate verde en las áreas tocadas; mutantes del contrato de lectura vs corrupción muertos.
- Un test demuestra: fichero ilegible por fallo de lectura → no se escribe estado vacío encima; pendientes se conservan para reintento.
- Un test demuestra: JSON corrupto → sigue el trato de «estado nuevo» (control positivo).
- Review adversarial sin hallazgos altos abiertos.
- Ticket movido (done o qa según guion) e índice `docs/TICKETS.md` al día.
- Cierre con `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, noche): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo se separan lectura y decode?** → `loadState` distingue tres desenlaces: sin fichero, leído y
decodificado, y leído pero no decodifica. El fallo de `Data(contentsOf:)` sale como `PrefsOutboxError.readFailed`
y NADIE lo convierte en estado nuevo. Por qué: el `catch` único es el bug. Alternativa descartada: mirar el tipo
del error dentro del mismo `catch` (un `DecodingError` vs el resto): frágil, el siguiente que toque el `do` lo funde.

**D2 · ¿Qué hace `enqueue`/`setPullCursor` ante `readFailed`?** → Lanza sin escribir. El cambio nuevo de ese
instante no se encola (lo pide el encargo: «sin encolar ni escribir»); lo pendiente del fichero se conserva y sube
en el primer ciclo en que el fichero se deje leer. Por qué: perder un cambio es mejor que perder todos y el
`nodeID`. Alternativa descartada: una cola en memoria que reintente el cambio: estado nuevo que cruza fronteras de
cuenta (teardown, owner) y el encargo no lo pide. Queda como residual con ticket.

**D3 · ¿El ciclo de prefs del runtime es «camino equivalente»?** → Sí. Con el fichero ilegible `entries` daba `[]`
y `pullCursor` daba `0`: se saltaba el push y bajaba TODO desde el cursor 0, y el merge (el remoto gana) revertía
en pantalla los cambios locales pendientes; luego `setPullCursor` escribía el estado vacío encima. Ahora el ciclo
lee una sola vez con la lectura tipada y, si no se deja leer, no hace push ni pull (reintenta el ciclo siguiente).
Por qué: «no pude leer» no es «no hay nada». Alternativa descartada: solo arreglar `loadOrCreateState`: el pull
desde 0 seguía revirtiendo cambios pendientes.

**D4 · ¿Y el cinturón del drenaje iKV→outbox (`drainiKVToOutboxOnceIfNeeded`)?** → No se toca. Con el fichero
ilegible su lectura de pendientes da `[]`, pero cada `enqueue` posterior lanza `readFailed` sin escribir, así que
el centinela no se estampa y reintenta al arrancar. Por qué: cambiarlo no tendría mutante que lo mate (el
`enqueue` ya lo para). Residual aceptado: la ventana de microsegundos entre las dos lecturas.

**D5 · ¿Corrupción?** → Trato de siempre: estado nuevo (nodeID y reloj nuevos), con log. Con test de control.

**D6 · ¿Cómo se prueba el fallo de lectura?** → Con el sistema de ficheros real: permisos `000` sobre el fichero.
La lectura falla y la escritura atómica (renombrar en el directorio) sí puede, así que el bug viejo SÍ
sobrescribía en ese montaje: el test lo reproduce sin seam en producción.
