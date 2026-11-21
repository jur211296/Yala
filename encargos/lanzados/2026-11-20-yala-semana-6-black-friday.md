marketing
# Material de redes de Yala para la semana 6, Black Friday (23 al 29 de noviembre)
---
toca: ~/Claude/marketing/biblioteca/estaticos/, ~/Claude/marketing/biblioteca/reels/, ~/Claude/marketing/biblioteca/carruseles/, ~/Claude/marketing/biblioteca/serie/yala-en-20-segundos/es/, ~/Claude/marketing/semana-6/
esfuerzo: high
cierre: cierra-sola
---

Encargo de Lola, aprobado por Jürgen el 20-nov a las 09:16, hora de Lima: «Sí, mándale el pedido a Frank» (decisión capturada por Lola en decisiones.py, proyecto marketing). Nunca dos sesiones de Yala/marketing en la misma máquina. La biblioteca de destino está en la Max: si corres en la Mini, copia a la Max por ssh.

## Objetivo
Hacer las 6 piezas NUEVAS de la semana 6 y el adelanto del cap. 7 de la serie. Nada reciclado. Todo en español neutro latinoamericano: nada de español de España ni de inglés. Solo funciones de 2.2 que vendan. NO mostrar como novedad widgets, Excel, ícono, Panel ni Estadísticas. NO vender multimoneda como novedad. Nada de Yape ni Plin. Sin sorteos.

Fuente de las novedades de 2.2: `~/Claude/lola-borradores/2.2/novedades-2.2-final.md` en la Mini (cópiala por ssh si no está en la Max). Plan aprobado: `~/Claude/marketing/PLAN-PUBLICACIONES.md`, sección Semana 6. Guía: `~/Claude/marketing/GUIA-PUBLICACIONES.md`.

## Estilo (set B)
- Fondo navy con estrellitas, palabras clave en índigo sólido, sin degradados en el texto, halo detrás del teléfono.
- Cierre «Tus finanzas, sin esfuerzo.» con la insignia del App Store.
- Voz ElevenLabs `gePzt50ZNIzsH3pmvJB6` (eleven_v4, stability 0.5, similarity 0.8, style 0, speaker boost, speed 0.95). Escúchala y confirma que suena bien.
- Música Pop Track 03 (Mixkit 729).
- Reels de 15 a 25 s, con gancho en el primer segundo.

## Formatos por pieza
- Reel: IG 1080×1920 con voz y música, portadas 9:16 y 3:4, y versión X 16:9 1600×900 con voz y música.
- Carrusel: 6 láminas IG 1080×1350 y 4 láminas X 1600×900.
- Estática: IG 1080×1350 y X 1600×900.
- Portadas distintas entre sí; nada cortado en el recorte 4:5.
- Cada pieza lleva caption de IG/Threads (máximo 2 emojis) y el texto del post de X: un solo post, con https://apps.apple.com/app/id6758253109 en la respuesta.

## Piezas (día · hora · pieza)
1. Mar 24 · 12:30 · Reel «Black Friday con tope»: ponle un presupuesto a tus compras y Yala te avisa antes de pasarte.
2. Mié 25 · 12:30 · Carrusel «Pregúntale a Siri»: consultas de 2.2 («¿cuánto gasté?», «¿cuánto tengo?») y anotar con Siri gratis con Apple Intelligence.
3. Jue 26 · 12:30 · Reel «Fin de mes: marca cada pago con un toque»: cuánto te falta pagar este período y marcar cada pago.
4. Jue 26 · 19:30 · Estática «Mañana es Black Friday: revisa tu tope».
5. Sáb 28 · 12:30 · Reel «Después del Black Friday: tu tarjeta en dos monedas» (soles y dólares como una sola tarjeta; sin venderlo como novedad multimoneda).
6. Dom 29 · 12:30 · Serie «Yala en 20 segundos», cap. 6 Pagos y recordatorios ACTUALIZADO a 2.2 (mismo estilo de la serie: mp4 IG con audio, X 16:9 y portadas 9:16 y 3:4).
7. Adelanto · Serie cap. 7 «Dos monedas», para el dom 6-dic (mismo estilo de la serie).

## Plazo y orden
- Todo en la biblioteca antes del dom 22 a las 20:00 (Lima).
- Si no cabe, por fecha: la pieza 1 antes del lun 23 a las 20:00 y cada una antes de las 11:00 del día anterior a su turno. Si no cabe en una sesión, cierra con checkpoint claro de lo que falta para encolar la continuación; nunca en paralelo.

## Destino
- `/Users/max-jur/Claude/marketing/biblioteca/` (reels/, carruseles/, estaticos/, serie/yala-en-20-segundos/es/), con los nombres `-ig-es` / `-x-es` / `-es-x-16x9` como hasta ahora.
- Rutas y captions en `~/Claude/marketing/semana-6/lote-<día>.md` y aviso a Lola al cerrar cada lote.
- Capturas reales de la app: simulador (en la Max puedes abrir un segundo simulador si otro proyecto ocupa el primero; tope 2) o el iPhone 14 por DeviceMCP.

## Entrega y cierre
- La revisión final va como artifact visual de Claude con todas las piezas y sus textos (nunca Markdown ni PDF).
- Cierre según el modo fijado al arrancar: si está completo y el modo lo permite, `/cerrar-total`. En nocturno, checkpoint sin declarar completo lo que falte.
- En el cierre van «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 (resuelto por la sesión, 20-nov-2026, modo semi, en la Max)

1. **Herramientas: las de la semana 5.** Tomas montadas con pantallas reales de 2.2, plantillas set B, voz con
   `semana4/voz.py`, mezcla con `semana3/mezcla.py`. Las fuentes nuevas van a `biblioteca/_fuente/semana6/`.
2. **Pantallas: app 2.2 publicada (tag `v2.2`), compilada aparte en `~/Claude/marketing/_build-s6/`**, en un simulador
   propio («Lola-S6», iPhone 17 Pro), con la semilla de marketing y el reloj en el jue 26-nov 9:41. No se tocó el repo.
   Lo que la semilla no traía se creó a mano en la app: presupuesto «Black Friday» (S/ 1,000, Compras, aviso al 75 y
   90 %), pagos Internet y Gimnasio, línea en USD de la tarjeta y dos compras de ejemplo. Ningún dato real.
3. **El aviso del reel «Black Friday con tope» es la notificación real de la app** («Presupuestos · Queda poco en
   "Black Friday" — S/908 de S/1,000 usados»), disparada en el simulador, no dibujada. El texto se leyó antes del
   código del tag (`BudgetAlertService`, `es.lproj`).
4. **Siri sin inglés:** las respuestas de Siri van como recortes reales de la pantalla, sin el botón «Done» del
   sistema, que sale en inglés.
5. **Sin repetirse:** el reel «Fin de mes» cuenta «te falta pagar → márcalo»; el cap. 6, «crea el pago → activa el
   aviso → márcalo pagado». El reel «Después del Black Friday» cuenta «tu tarjeta una sola vez, con el total»; el
   cap. 7, el paso a paso de la línea en dólares. Ninguno dice «nuevo» ni «multimoneda».

## Cierre (20-nov-2026)

Las 7 piezas están en la biblioteca de la Max, con rutas, captions y posts de X por día en
`~/Claude/marketing/semana-6/lote-<día>.md` (índice en `textos.md`, decisiones en `paso-0.md`) y la sección «Semana 6»
del `INDICE.md`. Revisión visual: https://claude.ai/artifact/9xy6Ujm99e19HEEw4w69ay (pública).

- **Saltado o asumido sin preguntar:**
  - El aviso de presupuesto en el simulador necesitó el permiso de notificaciones, que la semilla salta: se concedió
    activando un recordatorio en Ajustes › Notificaciones de la app (solo en el simulador propio).
  - El cierre de voz del reel «Fin de mes» es la misma toma de «Tus finanzas, sin esfuerzo.» del reel del martes (mismos
    ajustes): la suya duraba 2,32 s y pisaba el final del vídeo. La toma original queda como `fin-de-mes_5.toma1.mp3`.
  - Device MCP estaba ocupado con el iPhone de Jürgen por otra sesión: el simulador se manejó con `axe`.
- **Decidido sin consultar:** la maqueta «calendario» de la estática del jueves y las tres maquetas nuevas de portada
  («aviso», «lista», «base»), para que la cuadrícula no repita las de la semana 5.
