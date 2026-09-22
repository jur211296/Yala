---
name: el-scan-de-un-modifier-no-ancla-a-que-vista-cuelga
description: Un `body(of: ".onDisappear {")` encuentra el PRIMERO del fichero — moverlo a una vista de dentro del switch reabre el ticket y deja los tres source-scans en verde
metadata:
  type: feedback
---

Un source-scan de un modifier de SwiftUI comprueba **su forma**, no **de qué vista cuelga**. Y en este
repo la diferencia suele ser el ticket entero, porque una vista dentro de un `switch` de estados se
desmonta en cada cambio de estado y la de fuera no.

**Why:** 2026-09-21, `restore-timeout-closes-the-session-window-with-the-import-still-running`. Mudé el
`noteRestoreAbandoned` al `.onDisappear` de `WelcomeRestoreView` y lo fijé con tres scans: el conteo de
call-sites por FICHERO, el cuerpo del `onDisappear`, y que la pantalla de progreso ya no lo llamara.
Una lente de la review encontró el mutante que sobrevivía a los tres: colgar ese mismo bloque del
`RestoreProgressView(flowToken:)` del `case .searching`. El fichero no cambia, el conteo tampoco, el
cuerpo es idéntico — y el comportamiento vuelve a ser **el de antes del fix**.

Lo que lo caza es el ORDEN dentro del fichero: `RestoreProgressView(flowToken: flowToken)` <
`.task { startSearch() }` < `.onDisappear {`, más el conteo de ocurrencias del propio marcador (== 1).
Con eso, cualquier bajada al `switch` cae delante del `.task` y el test se pone rojo.

**How to apply:** cuando un source-scan fije un modifier, ánclalo por **posición relativa a algo que
solo exista en el nivel correcto** —aquí, el `.task` del `NavigationStack`— y comprueba que el marcador
es único en el fichero. El mutante que hay que escribir no es «quitarlo»: es **moverlo un nivel hacia
dentro**, que compila, no deja warning y suele ser exactamente el bug.

Hermano de [[feedback_el_source_scan_de_dos_literales_no_es_una_red]] (fijar el cuerpo entero) por el
eje del SITIO en vez del contenido. Y del mismo día: un `body(of:)` cuyo marcador no incluya la llave de
apertura empieza a contar desde el paréntesis de la condición y **se traga la closure entera** — el
cuerpo extraído pasa a ser todo lo que sigue y las aserciones sobre él dejan de significar nada.
