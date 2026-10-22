---
name: un-gate-falla-abierto-por-su-entrada
description: Un guard que decide sobre una LISTA se abre solo cuando el fetch de esa lista falla — vacío y «no pude saberlo» se leen igual. Y el snapshot que lee se congela mientras haces `await`.
metadata:
  type: feedback
---

**Cuando escribas un guard que decide mirando una colección, pregúntate qué hace si esa colección
llega vacía POR ERROR. Casi siempre: se abre.**

**Why:** el 2026-09-09 mi gate del cambio de divisa clasificaba las filas de una cuenta. El `catch`
de `loadTransactions` dejaba `allTransactions = []`, y una lista vacía se lee igual que «esta cuenta
no tiene movimientos» → veredicto «libre» → la divisa cambiaba sin convertir nada, que era el bug
entero entrando por la puerta de atrás. El fallo del fetch **desarmaba el guard que existía para
ese fallo**.

**How to apply:**

- **Registra el fallo, no solo el resultado.** Un `didFailToLoad` junto a la lista, y el guard lo
  trata como bloqueo. «No hay» y «no lo sé» llevan a decisiones opuestas.
- **Y el snapshot se congela.** El mismo día, la otra mitad: `allTransactions` se cargaba al abrir
  el formulario, y entre medias había un `await` que hacía red. En esa ventana el sync puede
  escribir una fila nueva — que se quedaba sin convertir **y el re-gate no la veía**, porque releía
  el mismo array. ⇒ **refetch DESPUÉS del `await`**, justo antes de actuar. `CurrencyChangeService`
  ya lo hacía así y fue el precedente que lo delató.
- **Para fijarlo con un test hace falta un seam**, porque un `ModelContext` in-memory sano no lanza:
  un `_testSimulate…Failure()` bajo `#if DEBUG`. Sin él, el guard que impide el peor caso es
  precisamente el que ninguna aserción puede tocar — la familia de
  [[la-asercion-que-no-puede-fallar]].

Las dos mitades las cazó la **tercera** lente adversarial, no las dos primeras: es
[[lentes-adversariales-se-contradicen]] por el lado bueno — cada lente ve su eje y ninguna ve el de
al lado.

## La otra puerta de atrás: el estado «saltado / no aplica»

**2026-09-09.** Mi banco de pruebas tenía tres desenlaces: verde, rojo, y **«no ejecutada»** —
legítimo, porque una de sus mitades solo puede correr en el Mac y no en el CI. Un `mapfile` (que
no existe en el bash 3.2 de macOS) reventó dentro del bloque, dejó el contador a `0`, y `0 < 50`
cayó en la rama de «corpus demasiado corto» → **saltado** → **VERDE**. El banco informó de que
todo estaba bien justo cuando no había mirado nada.

**Why:** un estado neutro es un sumidero. Cualquier error que deje una variable vacía o a cero
aterriza en él, y como no suma fallos, el veredicto final sale limpio. Es el mismo agujero que
la lista vacía por error, pero por la puerta del RESULTADO en vez de la de la ENTRADA.

**How to apply:**

- **El veredicto de cada bloque es una variable explícita**, inicializada a `"no-ejecutado"`. Si
  al final sigue así, es ROJO: nadie decidió. Un `if/elif/else` sin esa red te deja creer que
  pasó por donde no pasó.
- **Valida el tipo de lo que vas a comparar**, no solo el valor: `case "$N" in ''|*[!0-9]*)` antes
  de un `[ "$N" -lt 50 ]`. Un número vacío o basura no puede caer en una rama de negocio.
- **Y quita el estado ambiguo si puedes.** Aquí «corpus corto» solo era legítimo en un clon
  superficial, que es justo donde tampoco existe el hook global — o sea que la rama ya se
  saltaba antes por otro motivo. Convertirlo en rojo no perdió ningún caso real y dejó dos
  desenlaces en vez de tres. Nombra siempre qué se pierde al limpiar: aquí, la tolerancia a un
  `--depth 1` en una máquina con el hook global puesto.
- Corolario de método: **el mutante que prueba esto tiene que reventar el bloque por dentro**
  (meter el `mapfile` de vuelta), no romperle la entrada. Y correrlo desde donde vive el
  original — ver [[la-asercion-que-no-puede-fallar]].
