---
name: campo-codable-nuevo-apaga-el-widget
description: Un campo Codable NO opcional en un DTO que viaja por el App Group apaga TODOS los widgets sobre el payload viejo; y el DTO está duplicado en dos targets, así que hay que tocar los dos.
metadata:
  type: feedback
---

Al añadir un campo a un DTO que viaja de la app al widget por el App Group, **decláralo opcional en
LOS DOS targets** y léelo con `?? false`.

**Why:** el snapshot se decodifica con `JSONDecoder().decode(WidgetDataSnapshot.self, …)` — struct
entera, sin versionado. Una clave nueva NO opcional que falte en el payload escrito por la versión
anterior lanza `keyNotFound`, `loadSnapshot()` devuelve nil y **todos** los widgets de la pantalla de
inicio se quedan en cero hasta que el usuario abra la app. No es un fallo del campo: la clave cuelga
de `thisMonthSummary`, que tampoco es opcional, así que **revienta el snapshot entero**. En un
widget eso pueden ser horas. Me pasó el 9-sep con las señales de aproximado.

Dos cosas que no son obvias y que costaron el rojo:

- **El DTO está DUPLICADO** (`Yala/Services/WidgetDataCache.swift` escribe,
  `YalaWidgets/Services/WidgetDataService.swift` lee). Puse los campos opcionales solo en el lector
  pensando que el otro «solo escribe». También decodifica: los dos tienen que aceptar el mismo
  payload.
- **La red ya existía y no era del área**: lo cazó
  `WidgetSessionSealTests.snapshotLegacySinElCampo_decodificaComoDelDueno`, escrito para el sello de
  sesión, que decodifica un JSON con «la forma exacta que hay hoy en los discos». Otro caso de que el
  gate acotado por suites no alcanza lo que rompes — ver [[mis-mediciones-fallan-por-el-filtro]].

**How to apply:** el precedente del propio fichero es la guía (`periodBalance: Double?`,
`sessionSeal: String?`, `WidgetScheduledPayment.isVariableAmount: Bool?`, todos con «Optional for
backwards compatibility with old cache format»). Y al terminar, **añade el caso legacy que falte**:
el test original llevaba `"transactions":[]`, así que no ejercitaba `WidgetTransaction`.

Corolario del mismo día: **`ApproximateMarkThreshold` y compañía no se pueden importar en el target
del widget.** `YalaWidgetsExtension` solo compila tres ficheros de `Yala/` por membership exception
(`project.pbxproj`). Si el widget necesita esa lógica, o se añade el fichero al target o se replica —
y **una réplica sin test de paridad es una copia que se queda atrás en silencio**: el mismo mes
saldría marcado en la app y exacto en la pantalla de inicio.
