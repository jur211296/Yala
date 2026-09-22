---
name: dos-derivados-del-mismo-enum-no-son-independientes
description: Defenderse diciendo «no ato mi derivado al suyo porque responden preguntas distintas» y colgarlo igual del mismo enum es atarlos por la puerta de atrás — comparten su forma de AGRUPAR
metadata:
  type: feedback
---

Un derivado de un enum hereda **cómo ese enum agrupa**, no solo su valor. Si dos derivados cuelgan del
mismo caso, no son independientes por mucho que se definan por separado.

**Why:** 2026-09-21, `restore-timeout-closes-the-session-window-with-the-import-still-running`. Colgué
`closesTheSessionWindow` de `RestoreImportSettlement` —el enum que elige el COPY de la pantalla— y me
defendí en el Paso 0, en el docblock y en un test de mutación explicando que **no** lo definía leyendo a
su hermano `consultsRemoteConfig` «porque uno decide un fetch y el otro un guard de frontera de cuenta».
Escribí incluso un escáner que impedía que uno leyera al otro. Y estaba atándolos igual: los dos
derivaban del mismo **caso**, y el caso agrupa.

`.inconclusive` junta dos poblaciones que a mi pregunta contestan al revés: la que no vio un import y la
que vio uno con un error VIGENTE. Para el copy da igual —a las dos hay que decirles lo mismo— y para un
guard de frontera de cuenta no: `isRetriable` da `true` a `networkUnavailable`, `requestRateLimited`,
`zoneBusy` y hasta en su `default`, y el testigo se enciende antes del `if let error`. O sea que a un
restore grande con la red floja, **el caso normal del ticket**, le apagaba la ventana con CloudKit
todavía trayendo filas: el bug que el ticket venía a cerrar, sin arreglar, entrando por el copy. Lo cazó
una lente de la review, no yo.

El arreglo fue sacar la decisión del enum y escribirla con los **términos crudos** que ya gobiernan el
mecanismo (`settled || !hasObservedImportActivity`), en el fichero de la lógica que decide la ventana.
Quedó además libre de la puntualidad de las fechas de CloudKit, que era otro residual.

**How to apply:** antes de añadir un `var` derivado a un enum ajeno, pregunta **por qué ese enum agrupa
como agrupa** y si tu pregunta necesita la misma partición. Si algún `case` junta poblaciones que tú
separarías, tu criterio no vive ahí: vive con sus términos. El test que lo caza no es «¿coinciden?» —van
a coincidir— sino recorrer las poblaciones de cada `case` y contestar tu pregunta en cada una.

Y la señal de alarma: si te descubres **argumentando** que dos cosas son independientes, mira dónde las
has puesto. Ver [[feedback_dos_getters_que_parecen_sinonimos]] y
[[feedback_el_predicado_del_ticket_no_es_el_criterio]].
