---
name: mi-arreglo-abre-un-camino-inalcanzable
description: Quitar un efecto que hacía INALCANZABLE una rama la vuelve alcanzable con todos sus bugs intactos — el 11-sep, dejar de limpiar la asociación abrió una re-entrada que destruía datos
metadata:
  type: feedback
---

**Cuando tu arreglo consiste en QUITAR un efecto, pregunta qué estaba haciendo inalcanzable ese efecto.**
Lo que se vuelve alcanzable llega con sus bugs intactos, y no son tuyos de origen pero sí de entrega.

**Why:** el 2026-09-11, `detach-failure-looks-like-success`. El bug era que el desasociar limpiaba la
asociación aunque el borrado local hubiera fallado. El arreglo obvio —no limpiarla— abre una puerta que
el `clear()` mantenía cerrada: con la asociación en pie, la sección **vuelve a ofrecer el gesto**. Y esa
segunda pasada estaba llena de cosas que nunca se habían ejecutado:

- `detachBridge` borraba el libro de conservados en su `guard` de «sin puente que soltar» — al re-asociar
  la misma cuenta, el bridge duplicaba en el Panel cada gasto que la persona eligió conservar.
- La salida elegida en la segunda hoja **no se podía aplicar** (el puente ya estaba soltado): pedir
  «quitar» no quitaba nada y el gesto terminaba diciendo que sí.
- El push-all volvía a correr **después** del teardown, que dos docblocks del mismo fichero prohíben.

Ninguno era un bug «mío». Los tres eran mi problema, porque mi cambio los hizo ocurrir.

**How to apply:**

1. Antes de quitar un efecto, escribe qué estado produce quitarlo y **qué gestos quedan disponibles en
   ese estado**. Aquí: «asociación viva + sesión cerrada» = la celda del segundo móvil, que ofrece
   desasociar.
2. Recorre ese gesto entero **como segunda pasada**, paso por paso, preguntando en cada uno «¿esto es
   idempotente?». No lo deduzcas del nombre: `clear()`, `teardown` y `purge` suenan idempotentes y uno de
   los tres destruía el libro.
3. Si un paso no lo es, la salida no suele ser hacerlo idempotente: es **acotar el reintento** al tramo
   que de verdad quedó pendiente, y marcar durablemente que quedó pendiente — la fase del coordinador
   muere con el proceso y el estado a medias no.

**Hermano de [[mi-arreglo-rompe-la-premisa-de-otro-guard]]**: allí ensanchar un predicado dejaba
mentirosos a guards lejanos; aquí quitar un efecto vuelve alcanzable código que nunca corrió. La pregunta
es la misma —«¿de qué era premisa lo que estoy tocando?»— y la respuesta no está en el fichero que editas.


## La forma gemela: el guard que cerraba DE REBOTE (2026-09-12)

No siempre quitas un efecto: a veces **abres una puerta cuyo cierre estaba protegiendo otra cosa**, sin
que nadie lo escribiera. En `cloud-killswitch-hides-the-only-door-to-detach-groups`, la fila de Ajustes
estaba oculta bajo el kill-switch, y esa ocultación era **el único candado** de «Migrar a la nube»:
`CloudRemoteFlags` no se consulta ni en esa vista ni en el controller — cero ocurrencias, medido. Abrir
la fila por el eje de Grupos habría reabierto la migración en pleno incidente.

⇒ al abrir una puerta, **inventaría todo lo que hay detrás y pregunta por cada cosa «¿esto se cerraba
porque alguien lo decidió, o porque la puerta estaba cerrada?»**. Lo segundo no aparece en ningún grep de
gates: aparece leyendo la pantalla entera. Y cuando lo encuentres, el término se escribe explícito — si
no, tu arreglo convierte una política («el kill corta la entrada») en una excepción silenciosa.

**Y gatear el RENDER no es gatear la ACCIÓN.** El `if` que deja de dibujar la card no para el flujo ya
empezado: consent → confirmación → chooser → `startMigration` no volvía a preguntar por el flag, así que
quien tapeaba justo antes de que aterrizara el snapshot nuevo migraba con el kill puesto. El mismo
término va también en el último punto antes del efecto.

## La tercera forma: la SALIDA nueva lleva al residual que el bloqueo tapaba (2026-10-05)

En `personal-drain-that-always-aborts-…` di salida de pérdida a un teléfono que antes bloqueaba siempre. El
residual viejo «el recuento final solo mira el outbox» era inofensivo para esa población porque **nunca
llegaba al borrado**; con mi salida llegaba, y con el drain atascado lo apuntado entre el aviso y el arm se
perdía sin contarse. Lo cazó la lente de pérdida de datos, no yo. ⇒ al abrir una salida, lista los
residuales ya escritos del camino que hay DETRÁS y pregunta si tu población los alcanzaba antes.
