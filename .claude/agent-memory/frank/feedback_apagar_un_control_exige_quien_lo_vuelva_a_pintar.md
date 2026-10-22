---
name: apagar-un-control-exige-quien-lo-vuelva-a-pintar
description: Al apagar un botón por un estado nuevo, pregunta quién REPINTA cuando ese estado se va; un singleton no observable no lo hace
metadata:
  type: feedback
---

Cuando mi arreglo APAGA un control (o cambia su texto) según un estado, la pregunta no es solo «¿se apaga cuando
toca?» sino «¿quién lo vuelve a encender cuando el estado se va?». El 2026-10-06 (tarjeta «Migrar a la nube») apagué
«Activar la nube» con un predicado que leía `CloudAuthService` —no observable— y la salida que el propio copy
proponía, «Desasociar», cerraba la sesión sin repintar la tarjeta: el botón se quedaba apagado hasta salir y volver.
Antes del arreglo era un texto viejo con el botón activo; después, una persona atascada.

**Why:** lo cazó la review adversarial, no yo; el XCUITest solo miraba el apagado, nunca la vuelta.

**How to apply:** con un control que se apaga, recorre la SALIDA en el simulador (el gesto que el copy promete) y mira
que vuelve sin salir de la pantalla. Si depende de estado no observable, cópialo a una propiedad `Equatable` del
`@Observable` donde ya corre un refresco. Y un detalle del banco de mutantes: un `mutate.py` que pasa las anclas por
`unicode_escape` destroza las tildes y el mutante «NO APLICA»; usa anclas sin acentos.
Relacionado: [[mi-arreglo-quita-la-salida-que-habia]], [[el-copy-que-promete-se-recorre]].
