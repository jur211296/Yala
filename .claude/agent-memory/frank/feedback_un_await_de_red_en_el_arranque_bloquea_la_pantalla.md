---
name: un-await-de-red-en-el-arranque-bloquea-la-pantalla
description: Un `await` que habla con la red dentro de `AppBootstrapper.bootstrap` deja sin ejecutar su `defer`, y ese `defer` libera el blocker `bootstrapPending` — con un servidor que no contesta, el arranque se queda sin montar nada.
metadata:
  type: feedback
---

`bootstrap()` abre con `defer { SessionState.shared.isBootstrapSettled = true }`, y ese flag es el
blocker `bootstrapPending` de la matriz de readiness: **mientras no se libere, el shell no monta covers ni
drena un solo intent**. Un `await` lento ahí dentro no retrasa «un servicio»: retrasa la primera pantalla.

**Why:** el 2026-09-17 puse el consumo del retiro de sesión como paso 0.0-quater de `bootstrap`, con un
`await`. Ese retiro llama a `CloudAuthService.signOut()`, que termina en `client.signOut(scope: .local)`
del SDK de Supabase — un POST al servidor sobre el `URLSession` **por defecto**, sin tope propio: 60 s de
`timeoutIntervalForRequest`. Con un portal cautivo o un servidor que no responde (no «sin red», que falla
rápido), el primerísimo arranque se quedaba **sin Welcome y sin drenar nada**, mirando el splash. Lo cazó
una lente adversarial; el diseño era correcto y el sitio no.

La cura no fue un timeout: fue **mover el trabajo a donde no hay red ni nada que bloquear**. El pre-mount
de `PersonalContainerHost.makeContainer()` es síncrono, corre antes que cualquier pantalla, y ahí
`CloudAuthService.shared` —un `static let` perezoso— **todavía no se ha construido**, así que el barrido
del llavero es completo por sí solo y nada puede reponerlo.

**How to apply:**

- Antes de meter un `await` en `bootstrap()`, pregunta **qué hay al otro lado**. Si la cadena llega a
  `URLSession` —directa o dentro de un SDK— no va ahí.
- **El molde de la casa para el trabajo de arranque que no puede esperar es el PRE-MOUNT**, al lado de
  `SecondarySessionRetirement.purgeIfNeeded()` y `performSignOutWipeIfArmed()`: síncrono, local, y con la
  propiedad que lo hace correcto — ahí todavía no existe ningún singleton que pueda competir.
- Y se pinnea al revés, con un test que exija la AUSENCIA: `theBootstrapDoesNotAwaitTheRetirement`. Un
  scan que solo compruebe que la llamada está en el pre-mount no impide que alguien la duplique arriba.
- Corolario: **el sitio de un trabajo de arranque lo decide su física, no su orden lógico.** Yo lo puse en
  `bootstrap` para poder escribir «corre antes que todos los consumidores de la sesión»; pre-mount lo
  cumple mejor y además no bloquea.

Relacionado: [[un-timeout-no-distingue-lento-de-colgado]] y
[[lo-que-saco-a-una-tarea-aparte-pierde-garantias]].
