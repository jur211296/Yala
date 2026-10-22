---
name: mi-arreglo-deja-el-mecanismo-sin-productor
description: Quitar el último productor de un mecanismo lo deja vivo pero inalcanzable — y el docblock que escribo sobre el cambio miente si no mido a dónde llega de verdad el outcome nuevo. Y una salida que vuelve al origen tiene que devolver lo que la arista de entrada tiró (2026-09-16: el único productor de `complete`).
metadata:
  type: feedback
---

Cuando un arreglo **reclasifica un outcome**, hay que medir dos cosas que no son obvias y que no salen
del diff: **qué se queda sin productor** aguas arriba, y **a dónde llega de verdad** el outcome nuevo
aguas abajo. Las dos veces que no las medí, escribí un comentario falso.

**Why:** el 2026-09-14, al mover el 403 de infraestructura de `.accountUnavailable` a `.transient`:

- **Aguas arriba:** `stoppedUntilRelaunch` se quedó **sin ningún productor alcanzable**. El único que
  quedaba en el código era un 409 que el gateway **no emite en esa ruta** (`gateway/src/groups/
  routes.ts:12` lo dice de su puño). El mecanismo sigue ahí, con su gate y sus tests, pareciendo que
  cubre un caso que ya nadie puede alcanzar.
- **Aguas abajo, y esto es lo que me pilló:** escribí «el canal ya no llega a `.permanent`». **Falso.**
  `CloudSessionSignOut` colapsa con un ternario todo veredicto que no sea `.channelPaused` en
  `.permanent`, así que en esa celda el bug del ticket **seguía vivo** y mi comentario afirmaba lo
  contrario. Lo cazó una lente adversarial, no yo.

**How to apply:**

- **Aguas arriba:** tras reclasificar, `grep` de **todos los escritores** del estado que dejas de
  alimentar, y por cada uno pregunta si su condición es alcanzable **en el servidor**, no solo en el
  cliente. Un `case` que el backend nunca emite es código muerto aunque compile. Si queda sin
  productor: no lo retires de paso (eso toca otras firmas y sus tests) — **documéntalo con la medición
  y abre ticket**.
- **Aguas abajo:** sigue el outcome nuevo hasta la pantalla, **leyendo cada ternario y cada `switch`
  del camino**. Un colapso de un solo carácter (`x == .a ? .a : .b`) borra tu distinción entera, y es
  invisible desde el fichero que editas.
- **Regla para mí:** un docblock que dice «desde hoy X ya no pasa» es una afirmación medible sobre
  TODO el camino, no sobre la línea que acabo de tocar. O la mido hasta el final, o la escribo
  acotada («`classify` ya no lo produce» ≠ «ya no se ve»).
- Y si el colapso de aguas abajo afecta a más cosas que a tu objeto (ahí: también la red caída y los
  5xx), **no lo cambies**: es otro objeto y una decisión de producto. Ticket.

## La otra mitad, cuando SÍ toca retirarlo (2026-09-15, decisión 4A)

Jürgen decidió retirar el sello. Dos cosas de método que no salían del diff, y las dos las cazó la lente
de tests, no yo:

- **Las aserciones de AUSENCIA del mecanismo cubrían de rebote a sus lectores.** `_testStoppedUntilRelaunch
  == false` en el test del kill no solo decía «no se sella»: como el flag lo leían cuatro guards, protegía
  también `syncNowFromPush` y `syncNowAfterLocalSave`. Al borrar el seam, esos dos guards se quedaron sin
  red y el test seguía verde con un latch nuevo leído solo ahí.
- **Contesté mal «¿test para el camino que cambia?».** Dije que no, porque fijar la ausencia del sello sería
  «documentarlo como muerto». Pero mi docblock nuevo prometía «ninguna parada se queda puesta», y el 409
  —la tercera forma de parar— no tenía test: re-introducir el sello salía verde en toda la suite. Fijar la
  promesa nueva no es documentar el mecanismo viejo.

**How to apply:** al retirar un mecanismo, antes de borrar cada aserción sobre él, lista sus LECTORES (no
solo su escritor) y deja una aserción de conducta por cada uno. Y cuando escribas el invariante que queda,
cuenta sus casos y exige un test por caso: el que no lo tenga suele ser justo el que el PR cambia.

## La salida que «deshace» un gesto tiene que devolver lo que el gesto tiró al ENTRAR (2026-09-16)

`reverse-claim-rejection-has-no-way-out-in-the-client`. Diseñé la salida de un claim rechazado como «volver al origen sin
efectos», calcada de `reverseOtherLeader`, con 13 mutantes cazados. **Dos lentes independientes** encontraron lo mismo:
la ENTRADA de la vuelta (`reverseActivated`) reemplaza los pendientes del origen, y mi salida no los devolvía. Uno de
ellos, el reconcile del líder, era **el único productor de `complete`**: sin él `migration_in_progress` se quedaba puesto
en el backend para toda la cuenta. Antes de mi arreglo lo curaba, de rebote, el takeover de la reversa a los 60 min — o sea
que el bug viejo (15 % eterno) tapaba un mecanismo de curación que mi salida limpia se llevó.

**How to apply:**
- Al escribir una salida que devuelve a un estado anterior, lista lo que la arista de ENTRADA cambió además de la fase
  (pendientes reemplazados, campos limpiados) y decide uno por uno si vuelve. «Volver a la fase» no es «volver a como estaba».
- Busca qué **curaba de rebote** el comportamiento viejo, aunque fuera malo: una espera eterna que acaba en takeover cura
  cosas que una salida rápida no.
- Y la segunda pasada, sobre el arreglo del arreglo, volvió a encontrar el coste: reponer lo que falla siempre deja el motor
  parado esa sesión. Se aceptó con ticket porque lo repuesto era lo que ya estaba — la diferencia con añadir un efecto nuevo
  es exactamente la que separa «devolver» de «inventar».
