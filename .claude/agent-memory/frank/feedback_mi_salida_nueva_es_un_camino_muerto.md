---
name: mi-salida-nueva-es-un-camino-muerto
description: Cambiar «seguir» por «volver» crea un bucle si la pantalla destino solo ofrece volver aquí; antes de mover una salida, recorre el destino y cuenta sus acciones hacia delante
metadata:
  type: feedback
---

Antes de cambiar el desenlace de una pantalla de «sigue» a «vuelve», **abre la pantalla destino y cuenta
qué ofrece hacia DELANTE**. Si su única acción es la que trae de vuelta aquí, el arreglo es un bucle de
dos pantallas.

**Why:** el 14-sep extendí la decisión «vuelve sin declarar borrado» a la fase `.noICloud` de la puerta
de iCloud, por simetría con `.unreachable`. Medido por la review: no son simétricas. `.unreachable` tiene
«Reintentar» DENTRO de la pantalla —el remedio existe—; `.noICloud` no tenía ninguno, y su destino
(`WelcomeRestoreView` con iCloud apagado) ofrece «Abrir Ajustes» y «Empezar desde cero», que es
justamente el botón que trae aquí. Las dos pantallas se devolvían la pelota y la activación no podía
terminarse desde dentro. **El bug que arreglaba era «te miento y sigo»; el mío era «no puedes seguir».**
Y es la repetición exacta de un hallazgo que ya estaba escrito tres líneas más arriba en el mismo
fichero: la review de septiembre le había cazado a `.unreachable` ser un CAMINO MUERTO.

**How to apply:** dos preguntas antes de mover una salida. **(1) ¿La fase tiene remedio propio?** Si a
iCloud no se le puede preguntar porque no hay cuenta, «reintentar» sí sirve —la persona la activa en
Ajustes—; si el ADR dice que esa fase es terminal, lo dice para una superficie concreta (el Welcome, sin
app detrás), no para todas. **(2) ¿El destino tiene salida hacia delante?** Cuéntalas: primario,
secundario, toolbar, chevron. Y si el copy del destino no dice qué cambiar, el botón de reintentar parece
roto — el cuerpo tiene que llevar la CAUSA, no solo el hecho.

Hermana de [[feedback_mi_arreglo_abre_un_camino_inalcanzable]] y de
[[feedback_mi_fix_hereda_la_forma_del_bug]]: aquí el arreglo no hereda la forma del bug, hereda la forma
de un bug VECINO que ya estaba documentado en el mismo fichero.

## Y el 2026-09-22: la fase la comparten DOS flujos, y la salida solo es buena para uno

Le di techo y «Cancelar» a `claimingMigration` pensando en «Migrar a la nube». Esa misma fase la conducen el adopt
(«Ya tengo una cuenta», «Activar la nube en este dispositivo») y el seguidor. Para ellos la salida era un callejón: tras
`failedRollback` → «Reintentar» → `notStarted`, la pantalla solo ofrece «Migrar», la puerta de identidad lo para con esa
cuenta, y el texto «tus datos siguen en este dispositivo» era falso en un teléfono recién instalado. Además su espera se
curaba sola al volver la red: la salida era peor que el bug. Lo cazó la lente de consumidores.

**How to apply:** antes de añadir una salida a una fase, **lista quién la conduce** (`grep` de las entradas que llevan
ahí y de la intención que journalean) y recorre el destino con cada uno. Si la fase lleva una intención journaleada, el
alcance de la salida probablemente dependa de ella: aquí `ForwardCancelScope.offersCancel(_:claimIntent:)`.
