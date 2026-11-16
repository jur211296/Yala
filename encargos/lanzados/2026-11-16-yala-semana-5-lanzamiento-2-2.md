marketing
# Material de redes de la semana de lanzamiento de Yala 2.2 (16 al 22 de noviembre)
---
toca: ~/Claude/marketing/biblioteca/estaticos/, ~/Claude/marketing/biblioteca/reels/, ~/Claude/marketing/biblioteca/carruseles/, ~/Claude/marketing/biblioteca/serie/yala-en-20-segundos/es/, ~/Claude/marketing/semana-5/
esfuerzo: high
cierre: cierra-sola
---

Encargo de Lola, aprobado por Jürgen el 16-nov a las 07:17, hora de Lima: «Sí, envíale y dile que lo ponga primero en la cola, solo en la Max». Corre SOLO en la Max.

## Objetivo
Hacer todas las piezas NUEVAS de la semana de lanzamiento de Yala 2.2, que está en el App Store desde el 11-nov. Nada reciclado. Todo en español neutro latinoamericano: nada de español de España ni de inglés. Solo novedades de 2.2 que vendan; NO se muestran como novedad los widgets, Excel, el ícono, el Panel ni Estadísticas.

Novedades de 2.2 (la fuente es `~/Claude/lola-borradores/2.2/novedades-2.2-final.md` en la Mini; si no está en la Max, cópiala por ssh desde la Mini):
- Siri: «¿cuánto gasté?» y «¿cuánto tengo?» (anotar con Siri es gratis con Apple Intelligence).
- Tarjeta en dos monedas como una sola.
- Anotar en menos toques: cuenta ya puesta, favoritos a un toque y deshacer al guardar.
- Grupos: quién anotó cada gasto, lo que te deben, tu parte aparece sola y el modo Solo grupos.
- Cuánto te falta pagar este período, y marcar cada pago con un toque.

## Formatos por pieza
- Estática: IG 4:5 (1080×1350) y X 16:9 (1600×900).
- Reel: IG 9:16 con voz en español (escúchala y confirma que suena bien), portadas 9:16 y 3:4, y versión para X 16:9 1600×900 con voz.
- Carrusel: 6 láminas IG 4:5 y 4 láminas X 16:9.
- Las portadas tienen que ser distintas entre sí, para que el grid no se vea repetido. Nada puede quedar cortado en el recorte 4:5.
- Cada pieza lleva su caption de IG/Threads y el texto del post de X: un solo post, con el link de App Store https://apps.apple.com/app/id6758253109 en la respuesta.

## Piezas (día · hora · pieza)
- LOTE LUN 16 (entregar antes de las 12:00 de HOY): 12:30 Reel «Llegó Yala 2.2» con las 5 novedades · 19:30 Estática «Pregúntale a Siri: ¿cuánto gasté?»
- LOTE MAR 17 (antes de las 11:00 de ese día): 12:30 Carrusel «Lo nuevo de Yala 2.2» (una novedad por lámina más CTA) · 19:30 Estática «Tu tarjeta en dos monedas, como una sola»
- LOTE MIÉ 18: 12:30 Reel Siri «¿Cuánto tengo?» sin abrir la app · 19:30 Estática «Tu parte aparece sola» (Grupos)
- LOTE JUE 19: 12:30 Reel Grupos «El regalo de Navidad entre todos» · 19:30 Estática «¿Solo divides cuentas? Elige Solo grupos»
- LOTE VIE 20: 12:30 Carrusel «Black Friday en soles y dólares sin enredos» (dos monedas, presupuestos y cuánto falta pagar) · 19:30 Estática «¿Cuánto te falta pagar este mes?»
- LOTE SÁB 21: 12:30 Reel «Anota en menos toques» (cuenta ya puesta, favoritos, deshacer) · 19:30 Estática «Una semana para Black Friday» (presupuestos)
- LOTE DOM 22: 12:30 Serie «Yala en 20 segundos», cap. 5 Grupos ACTUALIZADO a 2.2 (mismo estilo de la serie: mp4 IG con audio, X 16:9 y portadas 9:16 y 3:4) · 19:30 Estática «¿Te equivocaste? Deshacer»

## Orden y destino
- Empieza por el lote del lunes y sigue por fecha. Si no cabe en una sesión, cierra con checkpoint claro de lo que falta para que se encole la continuación: nunca en paralelo y siempre en la Max.
- Destino: `/Users/max-jur/Claude/marketing/biblioteca/` (estaticos/, reels/, carruseles/, serie/yala-en-20-segundos/es/), con los nombres `-ig-es` / `-x-es` / `-es-x-16x9` como hasta ahora.
- Al cerrar cada lote, deja la lista de rutas y captions en `~/Claude/marketing/semana-5/` y avísale a Lola. El plan aprobado está en `~/Claude/marketing/PLAN-PUBLICACIONES.md`, sección Semana 5.
- Capturas reales de la app: usa el simulador (en la Max puedes abrir un segundo simulador si otro proyecto ocupa el primero) o el iPhone 14 por DeviceMCP.

## Entrega y cierre
- La revisión final va como artifact visual de Claude con todas las piezas y sus textos (nunca Markdown ni PDF).
- Cierre según el modo fijado al arrancar: si está completo y el modo lo permite, `/cerrar-total`. En nocturno, checkpoint sin declarar completo lo que falte.
- En el cierre van «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 (resuelto por la sesión, modo semi, sin preguntas pendientes)

- **De dónde salen las pantallas.** Copia limpia del tag `v2.2` (`git archive`, sin tocar una línea de código),
  compilada en Debug para un simulador propio («Lola S5 iPhone 17 Pro», iOS 27.2), con la semilla de marketing
  (`-uitest-seed ficha -uitest-seed-marketing`) y el reloj del molde en el 16-nov 9:41. Así lo que se ve es la 2.2
  publicada y las fechas son de esta semana. Device MCP estaba tomado por el iPhone de Jürgen: se condujo con `axe`.
- **Lo que la semilla no trae se creó en la app**, como haría una persona: la línea en USD de la «Tarjeta de crédito»,
  el favorito «Almuerzo · S/ 25», un pago marcado con «Ya lo pagué» y el modo «Solo grupos» (y vuelta).
- **Siri no tiene vista propia** (solo diálogo). La respuesta se enseña en una burbuja de la marca con la frase EXACTA
  que devolvió el atajo en el simulador; la tarjeta del sistema salía con «Done» en inglés y no se usa.
- **El regalo de Navidad**: crear un grupo nuevo pide el servidor y en el simulador no se puede. El reel plantea el
  regalo como idea y enseña los grupos de ejemplo, sin decir que la pantalla sea la del regalo.
- **X con voz y a 1600×900**, como pide este encargo (hasta ahora X iba a 1920×1080 solo con música).
- **Captions**: como mucho dos emojis de la lista de BRAND-VOICE §3; X ≤ 280 caracteres.
- **Fuera de este repo**: todas las piezas viven en la biblioteca de la Max (`~/Claude/marketing/`), fuera de git.
  Aquí solo entra este Paso 0 y la decisión de Jürgen del 15-nov sobre reintentos (marketing/README.md).
